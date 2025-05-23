
<#
.DESCRIPTION
Create temp .ps1 file with code from template
and execute it with admin rights if need
Then remove temp file
#>
function PowershellCodeExecute {
    param (
        [Parameter(Mandatory)]
        [string]$content,
        [switch]$needRunAS = $false
    )

    [string]$cleanedContent = $content.Clone().Trim()
    
    # replace variables with variables values in all current content
    foreach ($key in $variables.Keys) {
        $cleanedContent = $cleanedContent.Replace($key, $variables[$key])
    }
    
    try {
        [string]$tempFile = [System.IO.Path]::GetTempFileName()
        Rename-Item -Path $tempFile -NewName "$tempFile.ps1"
        $tempFile = "$tempFile.ps1"

        # write code from template to temp .ps1 file
        $cleanedContent | Out-File -FilePath $tempFile -Encoding utf8 -Force
    
        # execute file .ps1 with admin rights if exist else request admins rights
        if ((DoWeHaveAdministratorPrivileges) -or (-not $needRunAS)) {
            Invoke-Expression $cleanedContent
        } else {
            write-host "pro"
            $processId = Start-Process -FilePath $PSHost `
                -Verb RunAs `
                -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$tempFile`"" `
                -PassThru `
                -Wait

        
            if ($processId.ExitCode -gt 0) {
                Remove-Item -Path $tempFile -Force -ErrorAction Stop
                throw "Something happened wrong when execute Powershell code in file $tempFile"
            }
        }
    
        Remove-Item -Path $tempFile -Force -ErrorAction Stop
    }
    catch {
        Write-Error "We have problems with executing Powershell script from template"
        throw $_.Exception.Message
    }
}
