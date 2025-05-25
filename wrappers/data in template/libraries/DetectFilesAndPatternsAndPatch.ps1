
[string[]]$patternSplitters = @('/', '\', '|')

# Text - flags in parse sections
[string]$makeBackupFlag = 'MAKE BACKUP'

[System.Collections.Generic.List[string]]$paths = New-Object System.Collections.Generic.List[string]
[System.Collections.Generic.List[string[]]]$searchPatterns = New-Object System.Collections.Generic.List[string[]]
[System.Collections.Generic.List[string[]]]$replacePatterns = New-Object System.Collections.Generic.List[string[]]
[System.Collections.Generic.List[long[][]]]$foundPositions_allPaths = New-Object System.Collections.Generic.List[long[][]]
    
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


function TryExtractPatterns {
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
function ExtractPathsAndPatterns {
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


function DetectFilesAndPatternsAndPatch {
    param (
        [Parameter(Mandatory)]
        [string]$patcherFilePath,
        [Parameter(Mandatory)]
        [string]$content
    )

    [bool]$makeBackup = $false
    [bool]$onlyCheckOccurrences = $false

    ExtractPathsAndPatterns -content $content

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

        [long[][]]$foundPositions = Apply-HexPatternInBinaryFile -targetPath $paths[$i] -patternsPairs $patternsPairs.ToArray() -needMakeBackup $makeBackup -isSearchOnly $onlyCheckOccurrences
        $foundPositions_allPaths.Add($foundPositions)
    }

    Show-PatchInfo $patternsPairs.ToArray() $foundPositions_allPaths.ToArray()
}

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


function Show-PatchInfo {
    param (
        [Parameter(Mandatory)]
        [string[][]]$patternsPairs,
        [Parameter(Mandatory)]
        [long[][][]]$foundPositions
    )

    [int[][]]$numbersFoundOccurrences = CalculateNumbersFoundOccurrences_allPaths $foundPositions
    
    [bool]$isAllPatternsNotFound = Test-AllZero_allPaths $numbersFoundOccurrences
    [bool]$isAllPatternsFound = Test-AllNonZero_allPaths $numbersFoundOccurrences

    if ($isAllPatternsNotFound) {
        Write-ProblemMsg "No hex-patterns was found!"
        Write-Host
        Write-Host "In files:"
        
        for ($i = 0; $i -lt $paths.Count; $i++) {
            Write-Host $paths[$i]
        }
    }
    else {
        if ($isAllPatternsFound) {
            Write-Host "All hex-patterns found!"
        }
        else {
            Write-WarnMsg "Not all hex-patterns was found!"
        }
        Write-Host

        for ($i = 0; $i -lt $paths.Count; $i++) {
            Write-Host $paths[$i]

            for ($x = 0; $x -lt $searchPatterns[$i].Count; $x++) {
                Write-Host $searchPatterns[$i][$x].Trim() "|" $numbersFoundOccurrences[$i][$x]
            }

            Write-Host
        }
    }
}