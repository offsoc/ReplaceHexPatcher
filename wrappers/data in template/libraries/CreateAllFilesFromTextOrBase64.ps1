
# Names loaded .ps1 files
[string]$deleteFilesOrFoldersScriptName = 'DeleteFilesOrFolders'

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirPath = Split-Path -Path $scriptPath

<#
.SYNOPSIS
Get array with text and iterate it and function CreateFilesFromData
#>
function CreateAllFilesFromText {
    param (
        [Parameter(Mandatory)]
        [string[]]$sectionContents
    )
    
    foreach ($content in $sectionContents) {
        CreateFilesFromData -sectionContent $content
    }
}


<#
.SYNOPSIS
Get array with text and iterate it and function CreateFilesFromData
#>
function CreateAllFilesFromBase64 {
    param (
        [Parameter(Mandatory)]
        [string[]]$sectionContents
    )
    
    foreach ($content in $sectionContents) {
        CreateFilesFromData -sectionContent $content -isBase64
    }
}


<#
.SYNOPSIS
Analyze given text and create new text file with content from text
#>
function CreateFilesFromData {
    param (
        [Parameter(Mandatory)]
        [string]$sectionContent,
        [switch]$isBase64 = $false
    )

    # Trim only start because end file can have empty lines if new file need empty lines
    [string]$cleanedContent = $sectionContent.Clone().TrimStart()
    [string]$targetPath = ''
    [string]$endLinesNeed = ''
    [string]$targetContent = ''
    
    # replace variables with variables values in all current content
    foreach ($key in $variables.Keys) {
        $cleanedContent = $cleanedContent.Replace($key, $variables[$key])
    }
    
    [string[]]$cleanedContentLines = $cleanedContent -split "\n"
    $targetPath = $cleanedContentLines[0].Trim()

    # if target file exist - delete it
    if (Test-Path $targetPath) {
        . (Resolve-Path "$scriptDirPath\$deleteFilesOrFoldersScriptName.ps1")
        DeleteFilesOrFolders $targetPath
    }

    # check second line in content and detect if it flag for end lines type
    if ($cleanedContentLines.Count -gt 1) {
        if ($cleanedContentLines[1].Trim() -eq 'CRLF') {
            $endLinesNeed = "`r`n"
        } elseif ($cleanedContentLines[1].Trim() -eq 'LF') {
            $endLinesNeed = "`n"
        }
    }
    
    # if endLinesNeed settled - mean second line in content is tag for endLinesNeed and tag is not part future file content
    # else endLinesNeed var is empty - mean second line in content is start for future file content
    if ($isBase64) {
        [string[]]$tempContentLines = $cleanedContentLines[1..($cleanedContentLines.Length-1)]
        [byte[]]$targetContent = [Convert]::FromBase64String($tempContentLines)
    } elseif ($endLinesNeed -eq '') {
        [string[]]$tempContentLines = $cleanedContentLines[1..($cleanedContentLines.Length-1)]
        
        $endLinesNeed = [System.Environment]::NewLine
        $targetContent = ($tempContentLines) -join $endLinesNeed
    } else {
        [string[]]$tempContentLines = $cleanedContentLines[2..($cleanedContentLines.Length-1)]
        
        $targetContent = ($tempContentLines) -join $endLinesNeed
    }
    
    # create file with content inside and all folders for file path
    try {
        [void](New-Item -Path $targetPath -ItemType File -Force -ErrorAction Stop)

        if ($isBase64) {
            [System.IO.File]::WriteAllBytes($targetPath, $targetContent)
        } else {
            Set-Content -Value $targetContent -Path $targetPath -NoNewline -ErrorAction Stop
        }
    }
    catch {
        # create same files with same content but with admin privileges
        if ($isBase64) {
            # we can't execute WriteAllBytes in Start-Process because we can't set bytes to command string
            # so WriteAllBytes to temp file then move temp file with admin privileges
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllBytes($tempFile, $targetContent)
            $processId = Start-Process $PSHost -Verb RunAs -PassThru -Wait -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -Command `"Copy-Item -Path '$tempFile' -Destination '$targetPath' -Force;Remove-Item '$tempFile'`""
        }
        else {
            $processId = Start-Process $PSHost -Verb RunAs -PassThru -Wait -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -Command `"New-Item -Path `"$targetPath`" -ItemType File -Force;Set-Content -Value `"$targetContent`" -Path `"$targetPath`" -NoNewline`""
        }
    
        if ($processId.ExitCode -gt 0) {
            throw "Something happened wrong when create files with data with administrator privileges"
        }
    }
}
