
[string[]]$patternSplitters = @('/', '\', '|')

# paths/files/targets for patches
[System.Collections.Generic.List[string]]$paths = New-Object System.Collections.Generic.List[string]
# list flags mean file from list $paths exist on disk
[System.Collections.Generic.List[bool]]$paths_exist_mask = New-Object System.Collections.Generic.List[bool]
# arrays search patterns for each path/file
[System.Collections.Generic.List[string[]]]$searchPatterns = New-Object System.Collections.Generic.List[string[]]
# arrays replace patterns for each path/file
[System.Collections.Generic.List[string[]]]$replacePatterns = New-Object System.Collections.Generic.List[string[]]
# arrays found positions for each search pattern for each path/file
# each path can have multiple search patterns + each search pattern can be found multiple times
[System.Collections.Generic.List[long[][]]]$foundPositions_allPaths = New-Object System.Collections.Generic.List[long[][]]


function ClearStorageArrays {
    $paths.Clear()
    $searchPatterns.Clear()
    $replacePatterns.Clear()
    $foundPositions_allPaths.Clear()
}


<#
.DESCRIPTION
Check if string contain any element from array and return $true if contain
#>
function DoesStringContainsOneItemArray {
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string]$text,
        [Parameter(Mandatory)]
        [array]$items
    )
    
    $containsElement = $false

    foreach ($element in $items) {
        if ($text -match [regex]::Escape($element)) {
            $containsElement = $true
            break
        }
    }

    return $containsElement
}


<#
.DESCRIPTION
Function try extract search pattern and replace pattern from 1 line string
It simple check if string have one of patterns separator symbol and
split string by separator symbol and return resulting array
otherwise return $null 
#>
function TryExtractHexPatterns {
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [string]$text
    )
    
    foreach ($splitter in $patternSplitters) {
        if ($text -match [regex]::Escape($splitter)) {
            return $text.Split($splitter)
        }
    }
    
    return $null
}


<#
.DESCRIPTION
Function analyze given text and extract from the text paths
and pairs search + replace hex-patterns for each path
and add paths, search patterns and replace patterns in separated lists
#>
function ExtractPathsAndHexPatterns {
    param (
        [Parameter(Mandatory)]
        [string]$content,
        [bool]$isWildcard1QS = $false
    )

    [string]$cleanedContent = $content.Clone().Trim()
    
    # replace variables with variables values in all current content
    foreach ($key in $variables.Keys) {
        $cleanedContent = $cleanedContent.Replace($key, $variables[$key])
    }
    
    [System.Collections.Generic.List[string]]$searchPatternsLocal = New-Object System.Collections.Generic.List[string]
    [System.Collections.Generic.List[string]]$replacePatternsLocal = New-Object System.Collections.Generic.List[string]
    [bool]$searchPatternFound = $false

    
    foreach ($line in $cleanedContent -split "\n") {
        # Trim line is important because end line include \n
        $line = [Environment]::ExpandEnvironmentVariables($line.Trim())

        if ((Test-Path $line 2>$null) -or (Test-Path -LiteralPath $line 2>$null)) {
            $paths.Add($line)
            $paths_exist_mask.Add($true)
            
            if ($searchPatternsLocal.Count -gt 0) {
                $searchPatterns.Add($searchPatternsLocal.ToArray())
                $searchPatternsLocal.Clear()
                $replacePatterns.Add($replacePatternsLocal.ToArray())
                $replacePatternsLocal.Clear()
            }
        }
        elseif (DoesItLooksLikeFSPath $line) {
            $paths.Add($line)
            $paths_exist_mask.Add($false)
            
            if ($searchPatternsLocal.Count -gt 0) {
                $searchPatterns.Add($searchPatternsLocal.ToArray())
                $searchPatternsLocal.Clear()
                $replacePatterns.Add($replacePatternsLocal.ToArray())
                $replacePatternsLocal.Clear()
            }
        }
        else {
            # if line is search+replace pattern - need extract search and extract replace patterns
            # and continue lines loop

            [string]$cleanedLine = $line

            if ($isWildcard1QS) {
                [string]$cleanedLine = $cleanedLine.Replace('?', '??')
            }
            
            $possiblePairPatterns = TryExtractHexPatterns $cleanedLine

            if ($possiblePairPatterns) {
                if ($possiblePairPatterns.Length -eq 2) {
                    $searchPatternsLocal.Add($possiblePairPatterns[0])
                    $replacePatternsLocal.Add($possiblePairPatterns[1])
                    continue
                }

                if (($possiblePairPatterns.Length -gt 2) -or ($possiblePairPatterns.Length -eq 1)) {
                    throw "Wrong patterns format in line $cleanedLine`nOr file no exist on given path"
                }

                if ($possiblePairPatterns.Length -eq 0) {
                    continue
                }
            }

            if ($searchPatternFound) {
                $replacePatternsLocal.Add($cleanedLine)
                $searchPatternFound = $false
            }
            else {
                $searchPatternsLocal.Add($cleanedLine)
                $searchPatternFound = $true
            }
        }
    }

    if ($searchPatternsLocal.Count -gt 0) {
        $searchPatterns.Add($searchPatternsLocal.ToArray())
        $searchPatternsLocal.Clear()
        $replacePatterns.Add($replacePatternsLocal.ToArray())
        $replacePatternsLocal.Clear()
    }
}

<#
.SYNOPSIS
Remove digital signatures from patched PE-files

.DESCRIPTION
Passing to the function array with paths and array with found patched positions
and some other arguments.
A check is underway to see if the file has been patched. If the file is patched, then the number of occurrences is greater than zero.
Files that are not patched will not be affected - their signature will not be deleted.

$skipPECheck - if this argument is enabled, it will not be checked whether the processed file is a PE file.
This means that an attempt to delete the signature will be applied to all files, even archives, text files, etc.
This shouldn't cause any errors, it's just that such files obviously don't have a signature and it won't be deleted.
#>
function Remove-SignatureInPatchedPE {
    param (
        [Parameter(Mandatory)]
        [string[]]$filesPaths,
        [Parameter(Mandatory)]
        [long[][][]]$foundPositions,
        [bool]$skipPECheck = $false,
        [bool]$isVerbose = $false
    )
    
    if (-not $flagsAll.Contains($REMOVE_SIGN_PATCHED_PE_flag_text)) {
        return
    }
    
    [int[][]]$numbersFoundOccurrences = CalculateNumbersFoundOccurrences_allPaths $foundPositions
    
    [bool]$isAllPatternsNotFound = Test-AllZero_allPaths $numbersFoundOccurrences
    
    if ($isAllPatternsNotFound) {
        return
    }
    
    $signatureHandler = @"
using System;
using System.IO;
using System.Runtime.InteropServices;

public class SignatureRemover
{
    [DllImport("Imagehlp.dll", SetLastError = true)]
    private static extern bool ImageRemoveCertificate(IntPtr FileHandle, uint Index);

    public static bool RemoveSignature(string filePath)
    {
        using (FileStream fs = new FileStream(filePath, FileMode.Open, FileAccess.ReadWrite))
        {
            IntPtr fileHandle = fs.SafeFileHandle.DangerousGetHandle();
            return ImageRemoveCertificate(fileHandle, 0);
        }
    }
}
"@

    # if any class from C# code exist - C# already imported in the script and not need compile and import it again
    if (-not ("SignatureRemover" -as [Type])) {
        Add-Type -TypeDefinition $signatureHandler -Language CSharp
    }

    for ($i = 0; $i -lt $filesPaths.Count; $i++) {
        # if the file is not exist on the disk, then we do not remove signature from it
        if (-not $paths_exist_mask[$i]) {
            continue
        }

        # check if file is PE-file
        if (-not $skipPECheck) {
            try {
                $stream = [System.IO.File]::Open(($filesPaths[$i] -ireplace "``", ""), [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
            }
            catch {
                [void]($stream.Close())
                throw "Cannot open file: $($filesPaths[$i])"
            }

            $BytesHandler = [HexHandler.BytesHandler]::new($stream)

            if (-not $BytesHandler.IsFilePEFile()) {
                if ($isVerbose) {
                    Write-Host "File is not PE-file: $($filesPaths[$i])"
                }

                [void]($stream.Close())
                continue
            }

            [void]($stream.Close())
        }

        [bool]$isAllPatternsNotFoundForFile = Test-AllZero $numbersFoundOccurrences[$i]
    
        if ($isAllPatternsNotFoundForFile) {
            if ($isVerbose) {
                Write-Host "File is not patched and signature will not remove: $($filesPaths[$i])"
            }

            continue
        }

        [string]$filePathFull_Unescaped = [System.IO.Path]::GetFullPath(($filesPaths[$i] -ireplace "``", ""))
        [string]$filePathFull = [System.Management.Automation.WildcardPattern]::Escape($filePathFull_Unescaped)

        [bool]$result = [SignatureRemover]::RemoveSignature($filePathFull_Unescaped)
        
        if ($result) {
            if ($isVerbose) {
                Write-Host "Digital signature has been successfully deleted in file: $($filesPaths[$i])"
            }
            
            [int]$sizeKBWithoutSignature = (Get-ChildItem $filePathFull).Length / 1024
            
            if ($isVerbose) {
                Write-Host "The file began to size less by $($sizeKBOriginal - $sizeKBWithoutSignature) KB"
                Write-Host
            }
        } else {
            [System.Management.Automation.Signature]$signature = Get-AuthenticodeSignature -FilePath $filePathFull

            if (($signature.Status -eq "Valid") -or ($signature.Status -eq "HashMismatch") -or ($signature.Status -eq "NotTrusted")) {
                if ($isVerbose) {
                    Write-Host "File still have signature but something went wrong: $($filesPaths[$i])"
                }
            }
            
            if (($signature.Status -eq "UnknownError") -or ($signature.Status -eq "NotSigned") -or ($signature.Status -eq "NotSupportedFileFormat") -or ($signature.Status -eq "Incompatible")) {
                if ($isVerbose) {
                    Write-Host "File don't have signature: $($filesPaths[$i])"
                }
            }
        }
    }
}

<#
.SYNOPSIS
Supplement the replacement pattern to the length of the search pattern, if it is shorter

.DESCRIPTION
Character-by-character comparison of the received replacement pattern and the search pattern.
In the wildcard replacement pattern, the symbols, as well as the void, are replaced by symbols from the search pattern.

.NOTES
search pattern
replace pattern
completed replace pattern

example 1
00 A4 32 02 00 00 00 00 E0 5E B4 00 00 10 00 00
90 90 C3
90 90 C3 02 00 00 00 00 E0 5E B4 00 00 10 00 00

example 2
00 A4 32 02 00 00 00 00 E0 5E B4 00 00 10 00 00
?? 90 C3 ?? AA FF ??

example 3
00 A4 32 02 00 00 00 00 E0 ?? B4 ?? 00 10 00 00
?? 90 C3 ?? AA FF ??
00 90 C3 02 AA FF 00 00 E0 ?? B4 ?? 00 10 00 00

.OUTPUTS
Augmented/completed replacement pattern
#>
function Complete-ReplacePattern {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$searchPattern,
        [Parameter(Mandatory)]
        [string]$replacePattern
    )
    
    [string]$searchPatternFixed = $searchPattern
    [string]$replacePatternFixed = $replacePattern

    [int]$length = 0

    if ($searchPatternFixed.Length -gt $replacePatternFixed.Length) {
        $length = $searchPatternFixed.Length
    }
    else {
        $length = $replacePatternFixed.Length
    }

    [System.Collections.Generic.List[string]]$newPattern = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $length; $i++) {
        if ($searchPatternFixed[$i] -eq $replacePatternFixed[$i]) {
            $newPattern.Add($searchPatternFixed[$i])
        }
        elseif ([string]::IsNullOrEmpty($searchPatternFixed[$i])) {
            $newPattern.Add($replacePatternFixed[$i])
        }
        elseif ([string]::IsNullOrEmpty($replacePatternFixed[$i])) {
            $newPattern.Add($searchPatternFixed[$i])
        }
        elseif ($replacePatternFixed[$i] -eq '?') {
            $newPattern.Add($searchPatternFixed[$i])
            $newPattern.Add($searchPatternFixed[$i+1])
            $i=$i+1
        }
        else {
            $newPattern.Add($replacePatternFixed[$i])
        }
    }

    [string]$result = $($newPattern.ToArray() -join "")

    return $result
}


<#
.SYNOPSIS
Complements all replacement patterns to the length of the search patterns, if they are shorter.

.DESCRIPTION
Compares all received search patterns and replacement patterns and completes the search patterns with symbols from the search patterns, where possible.
Thus, we get a kind of "new search pattern" in which only the hex characters from the replacement pattern are changed.

.NOTES
search pattern
replace pattern
completed replace pattern

example 1
00 A4 32 02 00 00 00 00 E0 5E B4 00 00 10 00 00
90 90 C3
90 90 C3 02 00 00 00 00 E0 5E B4 00 00 10 00 00

example 2
00 A4 32 02 00 00 00 00 E0 5E B4 00 00 10 00 00
?? 90 C3 ?? AA FF ??

example 3
00 A4 32 02 00 00 00 00 E0 ?? B4 ?? 00 10 00 00
?? 90 C3 ?? AA FF ??
00 90 C3 02 AA FF 00 00 E0 ?? B4 ?? 00 10 00 00

.OUTPUTS
List of array augmented/completed replacement patterns
#>
function Complete-AllReplacePatterns {
    [OutputType([System.Collections.Generic.List[string[]]])]
    param (
        [Parameter(Mandatory)]
        [string[][]]$searchPatternsArg,
        [Parameter(Mandatory)]
        [string[][]]$replacePatternsArg
    )
    
    [System.Collections.Generic.List[string[]]]$result = New-Object System.Collections.Generic.List[string[]]

    for ($i = 0; $i -lt $searchPatternsArg.Count; $i++) {
        [System.Collections.Generic.List[string]]$temp = New-Object System.Collections.Generic.List[string]

        for ($x = 0; $x -lt $searchPatternsArg[$i].Count; $x++) {
            [string]$searchPatternCleaned = CleanHexString $searchPatternsArg[$i][$x]
            [string]$replacePatternCleaned = CleanHexString $replacePatternsArg[$i][$x]

            if (($searchPatternCleaned.Length -eq $replacePatternCleaned.Length) -and (-not $searchPatternCleaned.Contains('?')) -and (-not $replacePatternCleaned.Contains('?'))) {
                # if search and replace pattern same length and both without wildcards
                $temp.Add($replacePatternCleaned)
            }
            elseif (($replacePatternCleaned.Length -gt $searchPatternCleaned.Length) -and (-not $replacePatternCleaned.Contains('?'))) {
                # if length replace pattern greater length search pattern and replace pattern without wildcards
                $temp.Add($replacePatternCleaned)
            }
            else {
                # if length replace pattern less length search pattern
                [string]$newPattern = Complete-ReplacePattern -searchPattern $searchPatternCleaned -replacePattern $replacePatternCleaned
                $temp.Add($newPattern)
            }
        }

        [void]($result.Add($temp.ToArray()))
        $temp.Clear()
    }

    return $result
}


function DetectFilesAndPatternsAndPatchBinary {
    param (
        [Parameter(Mandatory)]
        [string]$patcherFilePath,
        [Parameter(Mandatory)]
        [string]$content,
        [System.Collections.Generic.HashSet[string]]$flags
    )

    [bool]$needMakeBackup = $false
    [bool]$checkOccurrencesOnly = $false
    [bool]$isWildcard1QS = $false

    if ($flags.Contains($MAKE_BACKUPS_flag_text)) {
        $needMakeBackup = $true
    }

    if ($flags.Contains($WILDCARD_IS_1_Q_SYMBOL_flag_text)) {
        $isWildcard1QS = $true
    }

    if ($flags.Contains($CHECK_OCCURRENCES_ONLY_flag_text)) {
        $checkOccurrencesOnly = $true
    }

    ExtractPathsAndHexPatterns -content $content -isWildcard1QS $isWildcard1QS

    if ($paths.Count -eq 0) {
        Write-ProblemMsg "None of the file paths specified for the hex patches were found"
        return
    }

    if ($flags.Contains($EXIT_IF_ANY_PATCH_BIN_FILE_NOT_EXIST_flag_text) -or $flags.Contains($PATCH_ONLY_ALL_PATTERNS_EXIST_flag_text)) {
        if ($paths_exist_mask.ToArray() -contains $false) {
            Write-ProblemMsg "Not all files from section patch_bin exists!"
            Write-ProblemMsg "With current template need that all target files exist"
            Write-ProblemMsg "Check files paths and run the template again"
            exit 1
        }
    }
    
    . $patcherFilePath

    if ($flags.Contains($CHECK_ALREADY_PATCHED_ONLY_flag_text)) {
        $checkOccurrencesOnly = $true
        $searchPatterns = [System.Collections.Generic.List[string[]]](Complete-AllReplacePatterns -searchPatternsArg $searchPatterns -replacePatternsArg $replacePatterns)
    }

    # check all files for require admin rights
    for ($i = 0; $i -lt $paths.Count; $i++) {
        if (Test-FileAdminRequired $paths[$i]) {
            Write-ProblemMsg "Need admin rights for modify file: $($paths[$i])"
            Write-ProblemMsg "Restart Powershell with admins rights and execute script again"
            exit 1
        }
    }

    if ($flags.Contains($PATCH_ONLY_ALL_PATTERNS_EXIST_flag_text)) {
        # only search all patterns for all files
        for ($i = 0; $i -lt $paths.Count; $i++) {
            [System.Collections.Generic.List[string[]]]$patternsPairs = New-Object System.Collections.Generic.List[string[]]

            for ($x = 0; $x -lt $searchPatterns[$i].Count; $x++) {
                [void]($patternsPairs.Add("$($searchPatterns[$i][$x])/$($replacePatterns[$i][$x])"))
            }

            [long[][]]$foundPositions = Apply-HexPatternInBinaryFile -targetPath $paths[$i] -patternsPairs $patternsPairs.ToArray() -needMakeBackup $false -isSearchOnly $true
            [void]($foundPositions_allPaths.Add($foundPositions))
        }
        
        [int[][]]$numbersFoundOccurrences = CalculateNumbersFoundOccurrences_allPaths $($foundPositions_allPaths.ToArray())
        [bool]$isAllPatternsFound = Test-AllNonZero_allPaths $numbersFoundOccurrences

        # if all patterns found/exist - apply all these patch-patterns
        if ($isAllPatternsFound) {
            for ($i = 0; $i -lt $paths.Count; $i++) {
                [void](Apply-HexPatternInBinaryFile -targetPath $paths[$i] -patternsPairs $patternsPairs.ToArray() -needMakeBackup $([bool]!$checkOccurrencesOnly -and $needMakeBackup) -isSearchOnly $false)
            }
        }
        else {
        # if NOT all patterns found/exist - show info about it and stop execute script
            Write-ProblemMsg "Not all patterns was found but for current template need all patterns exist for start patch"
            Show-HexPatchInfo -searchPatternsLocal $searchPatterns.ToArray() -foundPositions $foundPositions_allPaths.ToArray() -isSearchOnly $true
            ClearStorageArrays
            exit 1
        }
    }
    else {
        for ($i = 0; $i -lt $paths.Count; $i++) {
            # if the file is not exist on the disk, then we do not apply patterns to it
            if (-not $paths_exist_mask[$i]) {
                [void]($foundPositions_allPaths.Add(@(@(-1))))
                continue
            }

            [System.Collections.Generic.List[string[]]]$patternsPairs = New-Object System.Collections.Generic.List[string[]]

            for ($x = 0; $x -lt $searchPatterns[$i].Count; $x++) {
                [void]($patternsPairs.Add("$($searchPatterns[$i][$x])/$($replacePatterns[$i][$x])"))
            }

            [long[][]]$foundPositions = Apply-HexPatternInBinaryFile -targetPath $paths[$i] -patternsPairs $patternsPairs.ToArray() -needMakeBackup $([bool]!$checkOccurrencesOnly -and $needMakeBackup) -isSearchOnly $checkOccurrencesOnly
            [void]($foundPositions_allPaths.Add($foundPositions))
        }
    }

    if ($foundPositions_allPaths.ToArray().Count -ne 0) {
        Remove-SignatureInPatchedPE -filesPaths $paths -foundPositions $foundPositions_allPaths.ToArray()
        Show-HexPatchInfo -searchPatternsLocal $searchPatterns.ToArray() -foundPositions $foundPositions_allPaths.ToArray() -isSearchOnly $checkOccurrencesOnly
    }
    else {
        Write-ProblemMsg "No files were found on the disk:"
        
        for ($i = 0; $i -lt $paths.Count; $i++) {
            if (-not $paths_exist_mask[$i]) {
                Write-Host ($paths[$i])
            }
        }
    }

    ClearStorageArrays
}


<#
.SYNOPSIS
Function check if all array items is 0
#>
function Test-AllZero_allPaths {
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [int[][]]$array
    )

    for ($i = 0; $i -lt $array.Count; $i++) {
        for ($x = 0; $x -lt $array[$i].Count; $x++) {
            if ($array[$i][$x] -ne 0) { return $false }
        }
    }

    return $true
}


<#
.SYNOPSIS
Function check if all array items is non-0
#>
function Test-AllNonZero_allPaths {
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [int[][]]$arrayFoundOccurrences
    )

    for ($i = 0; $i -lt $arrayFoundOccurrences.Count; $i++) {
        for ($x = 0; $x -lt $arrayFoundOccurrences[$i].Count; $x++) {
            if ($arrayFoundOccurrences[$i][$x] -eq 0) { return $false }
        }
    }

    return $true
}


<#
.DESCRIPTION
Function calculate for each search pattern amount of found positions
#>
function CalculateNumbersFoundOccurrences_allPaths {
    [OutputType([int[][]])]
    param (
        [Parameter(Mandatory)]
        [long[][][]]$foundPositions
    )

    [System.Collections.Generic.List[int[]]]$numbersFoundOccurrences = New-Object System.Collections.Generic.List[int[]]

    for ($i = 0; $i -lt $foundPositions.Count; $i++) {
        [System.Collections.Generic.List[int]]$numbersLocal = New-Object System.Collections.Generic.List[int]

        for ($x = 0; $x -lt $foundPositions[$i].Count; $x++) {
            if (($foundPositions[$i][$x].Count -eq 1) -and ($foundPositions[$i][$x] -eq -1)) {
                [void]($numbersLocal.Add(0))
            }
            else {
                [void]($numbersLocal.Add($foundPositions[$i][$x].Count))
            }
        }

        $numbersFoundOccurrences.Add($numbersLocal.ToArray())
        $numbersLocal.Clear()
    }

    return , $numbersFoundOccurrences.ToArray()
}


function Show-HexPatchInfo {
    param (
        [Parameter(Mandatory)]
        [string[][]]$searchPatternsLocal,
        [Parameter(Mandatory)]
        [long[][][]]$foundPositions,
        [bool]$isSearchOnly = $false
    )

    if (-not $flagsAll.Contains($VERBOSE_flag_text)) {
        return
    }

    [bool]$isAllPathsExist = ($paths_exist_mask.ToArray() -notcontains  $false)

    [int[][]]$numbersFoundOccurrences = CalculateNumbersFoundOccurrences_allPaths $foundPositions

    [bool]$isAllPatternsNotFound = Test-AllZero_allPaths $numbersFoundOccurrences
    [bool]$isAllPatternsFound = Test-AllNonZero_allPaths $numbersFoundOccurrences
        
    if (-not $isAllPathsExist) {
        Write-Msg
        Write-WarnMsg "These files not exist on disk (not found):"
        
        for ($i = 0; $i -lt $paths.Count; $i++) {
            if (-not $paths_exist_mask[$i]) {
                Write-Host ($paths[$i])
            }
        }
        Write-Msg
    }

    if ($isAllPatternsNotFound) {
        Write-ProblemMsg "No hex-patterns was found!"
        Write-Msg
        Write-Msg "In files:"
        
        for ($i = 0; $i -lt $paths.Count; $i++) {
            # if the file is not exist on the disk, then we do not applied patterns to it
            if (-not $paths_exist_mask[$i]) {
                continue
            }
            Write-Msg $paths[$i]
        }
    }
    else {
        if ($isAllPatternsFound -and $isAllPathsExist) {
            if ($isSearchOnly) {
                Write-Msg "All hex-patterns found!"
            }
            else {
                Write-Msg "All hex-patterns found and replaced!"
            }
        }
        else {
            if ($isSearchOnly) {
                Write-WarnMsg "Not all hex-patterns was found!"
            }
            else {
                Write-WarnMsg "Not all hex-patterns was found! Only the found patterns were replaced."
            }
        }
        Write-Msg
        
        if ($flags.Contains($SHOW_SPACES_IN_LOGGED_PATTERNS_flag_text)) {
            for ($i = 0; $i -lt $paths.Count; $i++) {
                # if the file is not exist on the disk, then we do not applied patterns to it
                if (-not $paths_exist_mask[$i]) {
                    continue
                }
                Write-Msg $paths[$i]

                for ($x = 0; $x -lt $searchPatternsLocal[$i].Count; $x++) {
                    $pattern = $($searchPatternsLocal[$i][$x].Trim() -replace '(.{2})', '$1 ')
    
                    Write-Msg "$pattern| $($numbersFoundOccurrences[$i][$x])"
                }

                Write-Msg
            }
        }
        elseif ($flags.Contains($REMOVE_SPACES_IN_LOGGED_PATTERNS_flag_text)) {
            for ($i = 0; $i -lt $paths.Count; $i++) {
                # if the file is not exist on the disk, then we do not applied patterns to it
                if (-not $paths_exist_mask[$i]) {
                    continue
                }
                Write-Msg $paths[$i]

                for ($x = 0; $x -lt $searchPatternsLocal[$i].Count; $x++) {
                    $pattern = $($searchPatternsLocal[$i][$x].Trim() -replace '\s', '')
    
                    Write-Msg "$pattern | $($numbersFoundOccurrences[$i][$x])"
                }

                Write-Msg
            }
        }
        else {
            for ($i = 0; $i -lt $paths.Count; $i++) {
                # if the file is not exist on the disk, then we do not applied patterns to it
                if (-not $paths_exist_mask[$i]) {
                    continue
                }
                Write-Msg $paths[$i]

                for ($x = 0; $x -lt $searchPatternsLocal[$i].Count; $x++) {
                    Write-Msg "$($searchPatternsLocal[$i][$x].Trim()) | $($numbersFoundOccurrences[$i][$x])"
                }

                Write-Msg
            }
        }
    }
}