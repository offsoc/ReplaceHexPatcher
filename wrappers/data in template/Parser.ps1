param (
    [Parameter(Mandatory)]
    [string]$template,
    [string]$patcherPath
)


# =====
# GLOBAL VARIABLES
# =====

$comments = @(';;', '#')

# Here will stored parsed template variables
[System.Collections.Hashtable]$variables = @{}

$PSHost = If ($PSVersionTable.PSVersion.Major -le 5) {'PowerShell'} Else {'PwSh'}
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$templateDir = ''

# Other flags for code
[string]$fileIsTempFlag = 'fileIsTemp'


# Names loaded .ps1 files
[string]$getPatcherScriptName = 'GetPatcher'
[string]$detectFilesAndPatternsAndPatchScriptName = 'DetectFilesAndPatternsAndPatch'
[string]$removeFromHostsScriptName = 'RemoveFromHosts'
[string]$addToHostsScriptName = 'AddToHosts'
[string]$deleteFilesOrFoldersScriptName = 'DeleteFilesOrFolders'
[string]$createAllFilesFromTextOrBase64ScriptName = 'CreateAllFilesFromTextOrBase64'
[string]$blockOrRemoveFilesFromFirewallScriptName = 'BlockOrRemoveFilesFromFirewall'
[string]$registryFileApplyScriptName = 'RegistryFileApply'
[string]$powershellCodeExecuteScriptName = 'PowershellCodeExecute'
[string]$cmdCodeExecuteScriptName = 'CmdCodeExecute'

# Backup direct links for loaded .ps1 files if they not placed in folder
[string]$getPatcherScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/GetPatcher.ps1'
[string]$detectFilesAndPatternsAndPatchScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/DetectFilesAndPatternsAndPatch.ps1'
[string]$removeFromHostsScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/RemoveFromHosts.ps1'
[string]$addToHostsScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/AddToHosts.ps1'
[string]$deleteFilesOrFoldersScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/DeleteFilesOrFolders.ps1'
[string]$createAllFilesFromTextOrBase64ScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/CreateAllFilesFromTextOrBase64.ps1'
[string]$blockOrRemoveFilesFromFirewallScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/BlockOrRemoveFilesFromFirewall.ps1'
[string]$registryFileApplyScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/RegistryFileApply.ps1'
[string]$powershellCodeExecuteScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/PowershellCodeExecute.ps1'
[string]$cmdCodeExecuteScriptURL = 'https://github.com/Drovosek01/ReplaceHexPatcher/raw/main/wrappers/data%20in%20template/libraries/CmdCodeExecute.ps1'

# =====
# FUNCTIONS
# =====


<#
.DESCRIPTION
Function detect if current script run as administrator
and return bool info about it
#>
function DoWeHaveAdministratorPrivileges {
    [OutputType([bool])]
    param ()

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        return $false
    } else {
        return $true
    }
}


<#
.DESCRIPTION
Remove comments from text template
and replace template variables with text
and return cleaned template content
#>
function CleanTemplate {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$filePath
    )

    [string[]]$content = [System.IO.File]::ReadAllLines($filePath, [System.Text.Encoding]::UTF8)

    # Remove lines with current template-comments tag
    foreach ($comment in $comments) {
        $content = $content | select-string -pattern $comment -notmatch
    }

    # Replace $USER to current username
    $content = $content -ireplace '\$USER', $env:USERNAME
    # Replace USERNAME_FIELD to current username
    $content = $content -ireplace 'USERNAME_FIELD', $env:USERNAME
    # Replace USERPROFILE_FIELD to current username
    $content = $content -ireplace 'USERPROFILE_FIELD', $env:USERPROFILE
    # Replace USERHOME_FIELD to current username
    $content = $content -ireplace 'USERHOME_FIELD', $env:USERPROFILE

    return ($content -join "`n")
}


<#
.SYNOPSIS
Detect type end lines from given text
#>
function GetTypeEndLines {
    param (
        [Parameter(Mandatory)]
        [string]$content
    )
    
    if ($content.IndexOf("`r`n") -gt 0) {
        return "`r`n"
    } else {
        return "`n"
    }
}


<#
.DESCRIPTION
Remove empty lines from given string
and convert end lines if need
and trim all lines if need
#>
function RemoveEmptyLines {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$content,
        [string]$endLinesForResult,
        [switch]$noTrimLines = $false
    )

    # if content have no text or have 1 symbol - no data for handle
    # then return given content
    if ($content.Length -le 1) {
        return $content
    }

    [string]$endLinesCurrent = ''
    [string[]]$contentLines = $content -split "`r`n|`n"
    [string]$endLinesResult = ''
    
    $endLinesCurrent = GetTypeEndLines -content $content
    
    # set type of end lines for result text
    if ($endLinesForResult -eq 'CRLF') {
        $endLinesResult = "`r`n"
    } elseif ($endLinesForResult -eq 'LF') {
        $endLinesResult = "`n"
    } else {
        $endLinesResult = $endLinesCurrent
    }

    $contentLines = $contentLines | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }

    if (-Not $noTrimLines) {
        $contentLines = $contentLines | ForEach-Object { $_.Trim() }
    }

    return ($contentLines -join $endLinesResult)
}


<#
.SYNOPSIS
Function for extract text between start and end named section edges

.DESCRIPTION
Get templateContent and sectionName and return text
between [start-sectionName] and [end-sectionName]
#>
function ExtractContent {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$content,
        [Parameter(Mandatory)]
        [string]$sectionName,
        [switch]$saveEmptyLines = $false
    )

    [string]$cleanedTemplateContent = $content.Clone()
    [string]$startSectionName = "[start-$sectionName]"
    [string]$endSectionName = "[end-$sectionName]"
    
    if (-not $saveEmptyLines) {
        $cleanedTemplateContent = RemoveEmptyLines $cleanedTemplateContent
    }
    
    # start position content between content tags (+1 mean not include in content \n after start tag)
    [int]$startSectionIndex = $cleanedTemplateContent.IndexOf($startSectionName)
    [int]$startContentIndex = $startSectionIndex+$startSectionName.Length
    if ($cleanedTemplateContent[$startContentIndex] -eq "`n") {
        $startContentIndex +=1
    }
    if (($cleanedTemplateContent[$startContentIndex] -eq "`r") -and ($cleanedTemplateContent[$startContentIndex + 1] -eq "`n")) {
        $startContentIndex +=2
    }

    # end position content between content tags
    [int]$endContentIndex = $cleanedTemplateContent.IndexOf($endSectionName)

    if (($startSectionIndex -eq -1) -or ($startSectionIndex -eq -1)) {
        return ''
    }
    if ($startContentIndex -gt $endContentIndex) {
        Write-Error "Wrong template. Error on parse section $sectionName"
        exit 1
    }

    return $cleanedTemplateContent.Substring($startContentIndex, $endContentIndex-$startContentIndex)
}


<#
.SYNOPSIS
Extract variables and values from give content and return hashtable with it
#>
function GetVariables {
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory)]
        [string]$content
    )

    $variables = @{}

    foreach ($line in $content -split "\n") {
        # Trim line is important because end line include \n
        $line = $line.Trim()
        if (-not ($line.Contains('='))) {
            continue
        } else {
            $tempSplitLine = $line.Split("=")
            [void]$variables.Add($tempSplitLine[0].Trim(),$tempSplitLine[1].Trim())
        }
    }

    $cleanedVariables = $variables.Clone()

    # Variable values can also contain variables
    # loop all variable values and replace variables keys to values if it contain it
    foreach ($key in $variables.Keys) {
        $variables.Keys | foreach {
            if ($_ -eq $key) {
                return
            }

            $cleanedVariables[$key] = $cleanedVariables[$key].Replace($_, $variables[$_])
        }
    }

    return $cleanedVariables
}


<#
.DESCRIPTION
Function try decode given text from base64 to default text
Return decoded text if decoded without problems
Otherwise return $null
#>
function ConvertFrom-Base64 {
    param (
        [Parameter(Mandatory)]
        [string]$base64String
    )

    try {
        [byte[]]$decodedData = [System.Convert]::FromBase64String($base64String)
        return [System.Text.Encoding]::UTF8.GetString($decodedData)
    }
    catch {
        return $null
    }
}


<#
.DESCRIPTION
Function try decode given text from base64 to default text
If text decoded without problems - it save decoded text to temp file and return path to file
Otherwise return $null
#>
function TryDecodeIfBase64 {
    param (
        [Parameter(Mandatory)]
        [string]$base64String
    )
    
    try {
        [byte[]]$decodedData = [System.Convert]::FromBase64String($base64String)
        [string]$decodedText = [System.Text.Encoding]::UTF8.GetString($decodedData)

        [string]$tempFile = [System.IO.Path]::GetTempFileName()
        Get-Process | Where-Object {$_.CPU -ge 1} | Out-File $tempFile
        $decodedText | Out-File -FilePath $tempFile -Encoding utf8 -Force
        $renamedTempFile = ($tempFile.Substring(0, $tempFile.LastIndexOf("."))+".txt")
        Rename-Item $tempFile $renamedTempFile

        return (Get-ChildItem $renamedTempFile).FullName
    }
    catch {
        return $null
    }
}

<#
.DESCRIPTION
The path to the template is passed as an argument to this script.
This can be the path to a file on your computer or the URL to the template text.
This function checks for the presence of a file on the computer if it is the path to the file,
    or creates a temporary file and downloads a template from the specified URL into it
#>
function Get-TemplateFile {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$templateWay,
        [Parameter(Mandatory)]
        # [System.Collections.Generic.List[string]]
        [ref]$tempFilesList
    )

    $decodedTemplate = ''

    if ((Test-Path $templateWay 2>$null) -or (Test-Path -LiteralPath $templateWay 2>$null)) {
        # case when template is path to file
        [string]$filePathFull_Unescaped = [System.IO.Path]::GetFullPath(($templateWay -ireplace "``", ""))
        [string]$filePathFull = [System.Management.Automation.WildcardPattern]::Escape($filePathFull_Unescaped)

        $content = [System.IO.File]::ReadAllText($templateWay)

        if ($filePathFull.Contains($env:Temp)) {
            [void]($tempFilesList.Value.Add($filePathFull))
        }

        if (($decodedTemplatePath = TryDecodeIfBase64 $content) -and $decodedTemplatePath) {
            [void]($tempFilesList.Value.Add($decodedTemplatePath))
            return (Get-ChildItem $decodedTemplatePath).FullName
        }
        
        return (Get-ChildItem $filePathFull).FullName
    } elseif ($templateWay.StartsWith("http") -and ((Invoke-WebRequest -UseBasicParsing -Uri $templateWay).StatusCode -eq 200)) {
        # case when template is URL
        [string]$tempFile = [System.IO.Path]::GetTempFileName()
        Get-Process | Where-Object {$_.CPU -ge 1} | Out-File $tempFile
        (New-Object System.Net.WebClient).DownloadFile($templateWay,$tempFile)
        $renamedTempFile = ($tempFile.Substring(0, $tempFile.LastIndexOf("."))+".txt")
        Rename-Item $tempFile $renamedTempFile
        [void]($tempFilesList.Value.Add($renamedTempFile))

        $content = [System.IO.File]::ReadAllText($renamedTempFile)

        if (($decodedTemplatePath = TryDecodeIfBase64 $content) -and $decodedTemplatePath) {
            [void]($tempFilesList.Value.Add($decodedTemplatePath))
            return (Get-ChildItem $decodedTemplatePath).FullName
        }
        
        return (Get-ChildItem $renamedTempFile).FullName
    } else {
        # case when template is string
        [string]$tempFile = [System.IO.Path]::GetTempFileName()
        Get-Process | Where-Object {$_.CPU -ge 1} | Out-File $tempFile
        $templateWay | Out-File -FilePath $tempFile -Encoding utf8 -Force
        $renamedTempFile = ($tempFile.Substring(0, $tempFile.LastIndexOf("."))+".txt")
        Rename-Item $tempFile $renamedTempFile
        [void]($tempFilesList.Value.Add($renamedTempFile))

        $content = [System.IO.File]::ReadAllText($renamedTempFile)

        if (($decodedTemplatePath = TryDecodeIfBase64 $content) -and $decodedTemplatePath) {
            [void]($tempFilesList.Value.Add($decodedTemplatePath))
            return (Get-ChildItem $decodedTemplatePath).FullName
        }

        return (Get-ChildItem $renamedTempFile).FullName
    }
    
    Write-Error "No valid template"
    exit 1
}


<#
.SYNOPSIS
Download Powershell script in temp file and rename it to given name
#>
function DownloadPSScript {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$link,
        [Parameter(Mandatory)]
        [string]$fileNameFull
    )
    
    [string]$filePathFull = "${env:Temp}\$fileNameFull.ps1"

    try {
        if (Test-Path $filePathFull) {
            Remove-Item -Path $filePathFull -Force -ErrorAction Stop
            # TODO: Maybe need check if file is using and kill process for kill process using this file
        }
    
        (New-Object System.Net.WebClient).DownloadFile($link,$filePathFull)
    }
    catch {
        Write-Error "Something wrong when download external Powershell-script. Error message is: $_.Exception.Message"
        exit 1
    }

    return $filePathFull
}


<#
.SYNOPSIS
Write-Host given text with green prefix "[INFO]: "
#>
function Write-InfoMsg {
    param (
        [Parameter(Mandatory)]
        [string]$text
    )
    
    Write-Host "[INFO]: " -ForegroundColor Green -NoNewline
    Write-Host $text
}



# =====
# MAIN
# =====


$watch = [System.Diagnostics.Stopwatch]::StartNew()
$watch.Start() # launch timer

try {
    [System.Collections.Generic.List[string]]$tempFilesForRemove = New-Object System.Collections.Generic.List[string]
    [string]$fullTemplatePath = Get-TemplateFile -templateWay $template -tempFilesList ([ref]$tempFilesForRemove)
    [string]$cleanedTemplate = CleanTemplate $fullTemplatePath
    $templateDir = [System.IO.Path]::GetDirectoryName($fullTemplatePath)

    Set-Location $scriptDir


    # Get content from template file

    [string]$variablesContent = ExtractContent $cleanedTemplate "variables"
    
    [string]$patcherPathOrUrlContent = ExtractContent $cleanedTemplate "patcher_path_or_url"
    # If path or URL for patcher will passed like script argument
    # need check this argument first before check patchers lines from template  
    if ((Test-Path variable:patcherPath) -and ($patcherPath.Length -gt 1)) {
        $patcherPathOrUrlContent = $patcherPath + "`n" + $patcherPathOrUrlContent
    }

    [string]$targetsAndPatternsContent = ExtractContent $cleanedTemplate "targets_and_patterns"
    [string]$hostsRemoveContent = ExtractContent $cleanedTemplate "hosts_remove"
    [string]$hostsAddContent = ExtractContent $cleanedTemplate "hosts_add"
    [string]$deleteNeedContent = ExtractContent $cleanedTemplate "files_or_folders_delete"
    [string]$createFilesFromTextContent = ExtractContent $cleanedTemplate "file_create_from_text" -saveEmptyLines
    [string]$createFilesFromBase64Content = ExtractContent $cleanedTemplate "file_create_from_base64" -saveEmptyLines
    [string]$firewallBlockContent = ExtractContent $cleanedTemplate "firewall_block"
    [string]$firewallRemoveBlockContent = ExtractContent $cleanedTemplate "firewall_remove_block"
    [string]$registryModifyContent = ExtractContent $cleanedTemplate "registry_file"
    [string]$powershellCodeContent = ExtractContent $cleanedTemplate "powershell_code"
    [string]$cmdCodeContent = ExtractContent $cleanedTemplate "cmd_code"


    # Simple detection for needed admins rights:
    # If we have data for Windows Registry or for Firewall
    # - we 100% need Administrator privileges for apply instructions for it

    if ((($hostsRemoveContent.Length -gt 0) -or ($hostsAddContent.Length -gt 0) -or ($firewallBlockContent.Length -gt 0) -or ($firewallRemoveBlockContent.Length -gt 0) -or ($registryModifyContent.Length -gt 0)) -and (-not (DoWeHaveAdministratorPrivileges))) {
        $argumentsBound = ($PSBoundParameters.GetEnumerator() | ForEach-Object {
            $valuePath = $_.Value
            if ($_.Key -eq 'templatePath') {
                $valuePath = $fullTemplatePath
            }
            if ($valuePath.StartsWith('.')) {
                $valuePath = $valuePath | Resolve-Path
            }
            "-$($_.Key) `"$($valuePath)`""
        }) -join " "

        Start-Process -Verb RunAs $PSHost ("-ExecutionPolicy Bypass -File `"$PSCommandPath`" $argumentsBound")
        break
    }
    
    # Start use parsed data from template file

    if ($variablesContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing template variables..."
        $variables = GetVariables $variablesContent
        Write-InfoMsg "Parsing template variables complete"
    }
    
    if ($patcherPathOrUrlContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start patcher path..."
        
        # Import external Powershell-code
        $getPatcherScriptNameFull = "$getPatcherScriptName.ps1"
        if (Test-Path ".\$getPatcherScriptNameFull") {
            . (Resolve-Path ".\$getPatcherScriptNameFull")
        } elseif (Test-Path ".\libraries\$getPatcherScriptNameFull") {
            . (Resolve-Path ".\libraries\$getPatcherScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $getPatcherScriptURL -fileName $getPatcherScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }
        
        [string]$patcherFile, [string]$patcherFileTempFlag = GetPatcherFile $patcherPathOrUrlContent
        Write-InfoMsg "Patcher received"
    }
    
    if ($targetsAndPatternsContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing patch targets and apply patches..."
        
        # Import external Powershell-code
        $detectFilesAndPatternsAndPatchScriptNameFull = "$detectFilesAndPatternsAndPatchScriptName.ps1"
        if (Test-Path ".\$detectFilesAndPatternsAndPatchScriptNameFull") {
            . (Resolve-Path ".\$detectFilesAndPatternsAndPatchScriptNameFull")
        } elseif (Test-Path ".\libraries\$detectFilesAndPatternsAndPatchScriptNameFull") {
            . (Resolve-Path ".\libraries\$detectFilesAndPatternsAndPatchScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $detectFilesAndPatternsAndPatchScriptURL -fileName $detectFilesAndPatternsAndPatchScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }
        
        DetectFilesAndPatternsAndPatch -patcherFile $patcherFile -content $targetsAndPatternsContent

        Write-InfoMsg "Parsing patch targets and apply patches complete"    
    }
    
    if ($hostsRemoveContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing lines for remove from hosts..."

        # Import external Powershell-code
        $removeFromHostsScriptNameFull = "$removeFromHostsScriptName.ps1"
        if (Test-Path ".\$removeFromHostsScriptNameFull") {
            . (Resolve-Path ".\$removeFromHostsScriptNameFull")
        } elseif (Test-Path ".\libraries\$removeFromHostsScriptNameFull") {
            . (Resolve-Path ".\libraries\$removeFromHostsScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $removeFromHostsScriptURL -fileName $removeFromHostsScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }

        RemoveFromHosts $hostsRemoveContent
        
        Write-InfoMsg "Removing lines from hosts complete"
    }

    if ($hostsAddContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing lines for add to hosts..."

        # Import external Powershell-code
        $addToHostsScriptNameFull = "$addToHostsScriptName.ps1"
        if (Test-Path ".\$addToHostsScriptNameFull") {
            . (Resolve-Path ".\$addToHostsScriptNameFull")
        } elseif (Test-Path ".\libraries\$addToHostsScriptNameFull") {
            . (Resolve-Path ".\libraries\$addToHostsScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $addToHostsScriptURL -fileName $addToHostsScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }

        AddToHosts $hostsAddContent
        
        Write-InfoMsg "Adding lines to hosts complete"
    }

    if ($deleteNeedContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing lines with paths for files and folders delete..."

        # Import external Powershell-code
        $deleteFilesOrFoldersScriptNameFull = "$deleteFilesOrFoldersScriptName.ps1"
        if (Test-Path ".\$deleteFilesOrFoldersScriptNameFull") {
            . (Resolve-Path ".\$deleteFilesOrFoldersScriptNameFull")
        } elseif (Test-Path ".\libraries\$deleteFilesOrFoldersScriptNameFull") {
            . (Resolve-Path ".\libraries\$deleteFilesOrFoldersScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $deleteFilesOrFoldersScriptURL -fileName $deleteFilesOrFoldersScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }

        DeleteFilesOrFolders $deleteNeedContent
        
        Write-InfoMsg "Deleting files and folders complete"
    }

    if (($createFilesFromTextContent.Count -gt 0) -and ($createFilesFromTextContent[0].Length -gt 0)) {
        Write-Host
        Write-InfoMsg "Start parsing lines for create files..."

        if (Get-Command -Name CreateAllFilesFromText -ErrorAction SilentlyContinue) {
            CreateAllFilesFromText $createFilesFromTextContent
        } else {
            # Import external Powershell-code
            $createAllFilesFromTextOrBase64ScriptNameFull = "$createAllFilesFromTextOrBase64ScriptName.ps1"
            if (Test-Path ".\$createAllFilesFromTextOrBase64ScriptNameFull") {
                . (Resolve-Path ".\$createAllFilesFromTextOrBase64ScriptNameFull")
            } elseif (Test-Path ".\libraries\$createAllFilesFromTextOrBase64ScriptNameFull") {
                . (Resolve-Path ".\libraries\$createAllFilesFromTextOrBase64ScriptNameFull")
            } else {
                $tempPSFile = (DownloadPSScript -link $createAllFilesFromTextOrBase64ScriptURL -fileName $createAllFilesFromTextOrBase64ScriptNameFull)
                [void]($tempFilesForRemove.Add($tempPSFile))
                . $tempPSFile
            }

            CreateAllFilesFromText $createFilesFromTextContent
        }

        Write-InfoMsg "Creating text files complete"
    }

    if (($createFilesFromBase64Content.Count -gt 0) -and ($createFilesFromBase64Content[0].Length -gt 0)) {
        Write-Host
        Write-InfoMsg "Start parsing data for create files from base64..."

        if (Get-Command -Name CreateAllFilesFromBase64 -ErrorAction SilentlyContinue) {
            CreateAllFilesFromBase64 $createFilesFromBase64Content
        } else {
            # Import external Powershell-code
            $createAllFilesFromTextOrBase64ScriptNameFull = "$createAllFilesFromTextOrBase64ScriptName.ps1"
            if (Test-Path ".\$createAllFilesFromTextOrBase64ScriptNameFull") {
                . (Resolve-Path ".\$createAllFilesFromTextOrBase64ScriptNameFull")
            } elseif (Test-Path ".\libraries\$createAllFilesFromTextOrBase64ScriptNameFull") {
                . (Resolve-Path ".\libraries\$createAllFilesFromTextOrBase64ScriptNameFull")
            } else {
                $tempPSFile = (DownloadPSScript -link $createAllFilesFromTextOrBase64ScriptURL -fileName $createAllFilesFromTextOrBase64ScriptNameFull)
                [void]($tempFilesForRemove.Add($tempPSFile))
                . $tempPSFile
            }

            CreateAllFilesFromBase64 $createFilesFromBase64Content
        }

        Write-InfoMsg "Creating files from base64 complete"
    }

    if ($firewallRemoveBlockContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing lines paths for remove from firewall..."

        if (Get-Command -Name RemoveBlockFilesFromFirewall -ErrorAction SilentlyContinue) {
            RemoveBlockFilesFromFirewall $firewallRemoveBlockContent
        } else {
            # Import external Powershell-code
            $blockOrRemoveFilesFromFirewallScriptNameFull = "$blockOrRemoveFilesFromFirewallScriptName.ps1"
            if (Test-Path ".\$blockOrRemoveFilesFromFirewallScriptNameFull") {
                . (Resolve-Path ".\$blockOrRemoveFilesFromFirewallScriptNameFull")
            } elseif (Test-Path ".\libraries\$blockOrRemoveFilesFromFirewallScriptNameFull") {
                . (Resolve-Path ".\libraries\$blockOrRemoveFilesFromFirewallScriptNameFull")
            } else {
                $tempPSFile = (DownloadPSScript -link $blockOrRemoveFilesFromFirewallScriptURL -fileName $blockOrRemoveFilesFromFirewallScriptNameFull)
                [void]($tempFilesForRemove.Add($tempPSFile))
                . $tempPSFile
            }

            RemoveBlockFilesFromFirewall $firewallRemoveBlockContent
        }

        Write-InfoMsg "Remove rules from firewall complete"
    }

    if ($firewallBlockContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing lines paths for block in firewall..."

        if (Get-Command -Name BlockFilesWithFirewall -ErrorAction SilentlyContinue) {
            BlockFilesWithFirewall $firewallBlockContent
        } else {
            # Import external Powershell-code
            $blockOrRemoveFilesFromFirewallScriptNameFull = "$blockOrRemoveFilesFromFirewallScriptName.ps1"
            if (Test-Path ".\$blockOrRemoveFilesFromFirewallScriptNameFull") {
                . (Resolve-Path ".\$blockOrRemoveFilesFromFirewallScriptNameFull")
            } elseif (Test-Path ".\libraries\$blockOrRemoveFilesFromFirewallScriptNameFull") {
                . (Resolve-Path ".\libraries\$blockOrRemoveFilesFromFirewallScriptNameFull")
            } else {
                $tempPSFile = (DownloadPSScript -link $blockOrRemoveFilesFromFirewallScriptURL -fileName $blockOrRemoveFilesFromFirewallScriptNameFull)
                [void]($tempFilesForRemove.Add($tempPSFile))
                . $tempPSFile
            }

            BlockFilesWithFirewall $firewallBlockContent
        }

        Write-InfoMsg "Adding rules in firewall complete"
    }

    if ($registryModifyContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start parsing lines for modify registry..."

        # Import external Powershell-code
        $registryFileApplyScriptNameFull = "$registryFileApplyScriptName.ps1"
        if (Test-Path ".\$registryFileApplyScriptNameFull") {
            . (Resolve-Path ".\$registryFileApplyScriptNameFull")
        } elseif (Test-Path ".\libraries\$registryFileApplyScriptNameFull") {
            . (Resolve-Path ".\libraries\$registryFileApplyScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $registryFileApplyScriptURL -fileName $registryFileApplyScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }

        RegistryFileApply $registryModifyContent
        Write-Host "Modifying registry complete"
    }

    if ($powershellCodeContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start execute external Powershell code..."
        Write-Host

        # Import external Powershell-code
        $powershellCodeExecuteScriptNameFull = "$powershellCodeExecuteScriptName.ps1"
        if (Test-Path ".\$powershellCodeExecuteScriptNameFull") {
            . (Resolve-Path ".\$powershellCodeExecuteScriptNameFull")
        } elseif (Test-Path ".\libraries\$powershellCodeExecuteScriptNameFull") {
            . (Resolve-Path ".\libraries\$powershellCodeExecuteScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $powershellCodeExecuteScriptURL -fileName $powershellCodeExecuteScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }

        PowershellCodeExecute $powershellCodeContent -hideExternalOutput
        Write-InfoMsg "Executing external Powershell code complete"
    }

    if ($cmdCodeContent.Length -gt 0) {
        Write-Host
        Write-InfoMsg "Start execute external CMD code..."
        Write-Host

        # Import external Powershell-code
        $cmdCodeExecuteScriptNameFull = "$cmdCodeExecuteScriptName.ps1"
        if (Test-Path ".\$cmdCodeExecuteScriptNameFull") {
            . (Resolve-Path ".\$cmdCodeExecuteScriptNameFull")
        } elseif (Test-Path ".\libraries\$cmdCodeExecuteScriptNameFull") {
            . (Resolve-Path ".\libraries\$cmdCodeExecuteScriptNameFull")
        } else {
            $tempPSFile = (DownloadPSScript -link $cmdCodeExecuteScriptURL -fileName $cmdCodeExecuteScriptNameFull)
            [void]($tempFilesForRemove.Add($tempPSFile))
            . $tempPSFile
        }

        CmdCodeExecute $cmdCodeContent
        Write-InfoMsg "Executing external CMD code complete"
    }



    # Delete patcher or template files if it downloaded to temp file

    if ($patcherFileTempFlag -eq $fileIsTempFlag) {
        Remove-Item $patcherFile
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    # Delete all temp Powershell-script files
    $tempFilesForRemove | foreach { Remove-Item -Path $_ -Force }
}

$watch.Stop() # stop timer
Write-Host "Script execution time is" $watch.Elapsed # time of execution code

# Pause before exit like in CMD
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
