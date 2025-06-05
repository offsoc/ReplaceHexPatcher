
[string[]]$patternSplitters = @('/', '\', '|')

# paths/files/targets for patches
[System.Collections.Generic.List[string]]$paths = New-Object System.Collections.Generic.List[string]
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
        [string]$content
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
        $line = $line.Trim()

        if ((Test-Path $line 2>$null) -or (Test-Path -LiteralPath $line 2>$null)) {
            $paths.Add($line)
            
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
            
            $possiblePairPatterns = TryExtractPatterns $line

            if ($possiblePairPatterns) {
                if ($possiblePairPatterns.Length -eq 2) {
                    $searchPatternsLocal.Add($possiblePairPatterns[0])
                    $replacePatternsLocal.Add($possiblePairPatterns[1])
                    continue
                }

                if (($possiblePairPatterns.Length -gt 2) -or ($possiblePairPatterns.Length -eq 1)) {
                    throw "Wrong patterns format in line $line`nOr file no exist on given path"
                }

                if ($possiblePairPatterns.Length -eq 0) {
                    continue
                }
            }

            if ($searchPatternFound) {
                $replacePatternsLocal.Add($line)
                $searchPatternFound = $false
            }
            else {
                $searchPatternsLocal.Add($line)
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


function DetectFilesAndPatternsAndPatchBinary {
    param (
        [Parameter(Mandatory)]
        [string]$patcherFilePath,
        [Parameter(Mandatory)]
        [string]$content,
        [System.Collections.Generic.HashSet[string]]$flags
    )

    [bool]$needMakeBackup = $false
    [bool]$onlyCheckOccurrences = $false

    if ($flags.Contains($MAKE_BACKUPS_flag_text)) {
        $needMakeBackup = $true
    }

    ExtractPathsAndHexPatterns -content $content

    if ($paths.Count -eq 0) {
        Write-ProblemMsg "None of the file paths specified for the hex patches were found"
        return
    }

    . $patcherFilePath

    for ($i = 0; $i -lt $paths.Count; $i++) {
        [System.Collections.Generic.List[string[]]]$patternsPairs = New-Object System.Collections.Generic.List[string[]]

        for ($x = 0; $x -lt $searchPatterns[$i].Count; $x++) {
            $patternsPairs.Add("$($searchPatterns[$i][$x])/$($replacePatterns[$i][$x])")
        }

        [long[][]]$foundPositions = Apply-HexPatternInBinaryFile -targetPath $paths[$i] -patternsPairs $patternsPairs.ToArray() -needMakeBackup $needMakeBackup -isSearchOnly $onlyCheckOccurrences
        $foundPositions_allPaths.Add($foundPositions)
    }

    Show-HexPatchInfo $searchPatterns.ToArray() $foundPositions_allPaths.ToArray()

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
        [int[][]]$array
    )

    for ($i = 0; $i -lt $array.Count; $i++) {
        for ($x = 0; $x -lt $array[$i].Count; $x++) {
            if ($array[$i][$x] -eq 0) { return $false }
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

    return $numbersFoundOccurrences.ToArray()
}


function Show-HexPatchInfo {
    param (
        [Parameter(Mandatory)]
        [string[][]]$searchPatternsLocal,
        [Parameter(Mandatory)]
        [long[][][]]$foundPositions
    )

    [int[][]]$numbersFoundOccurrences = CalculateNumbersFoundOccurrences_allPaths $foundPositions
    
    [bool]$isAllPatternsNotFound = Test-AllZero_allPaths $numbersFoundOccurrences
    [bool]$isAllPatternsFound = Test-AllNonZero_allPaths $numbersFoundOccurrences

    if ($isAllPatternsNotFound) {
        Write-ProblemMsg "No hex-patterns was found!"
        Write-Msg
        Write-Msg "In files:"
        
        for ($i = 0; $i -lt $paths.Count; $i++) {
            Write-Msg $paths[$i]
        }
    }
    else {
        if ($isAllPatternsFound) {
            Write-Msg "All hex-patterns found!"
        }
        else {
            Write-WarnMsg "Not all hex-patterns was found!"
        }
        Write-Msg

        for ($i = 0; $i -lt $paths.Count; $i++) {
            Write-Msg $paths[$i]

            for ($x = 0; $x -lt $searchPatternsLocal[$i].Count; $x++) {
                Write-Msg $searchPatternsLocal[$i][$x].Trim() "|" $numbersFoundOccurrences[$i][$x]
            }

            Write-Msg
        }
    }
}