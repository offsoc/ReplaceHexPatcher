
# Text - flags in parse sections
[string]$moveToBinFlag = 'MOVE TO BIN'

<#
.SYNOPSIS
Function for check if for re-write transferred file need admins privileges

.DESCRIPTION
First, we check the presence of the "read-only" attribute and try to remove this attribute.
If it is cleaned without errors, then admin rights are not needed (or they have already been issued to this script).
If there is no "read-only" attribute, then we check the possibility to change the file.
#>
function Test-ReadOnlyAndWriteAccess {
    [OutputType([bool[]])]
    param (
        [Parameter(Mandatory)]
        [string]$targetPath,
        [Parameter(Mandatory)]
        [bool]$targetIsFile
    )
    
    $fileAttributes = Get-Item -Path $targetPath | Select-Object -ExpandProperty Attributes
    [bool]$isReadOnly = $false
    [bool]$needRunAs = $false

    if ($targetIsFile -and ($fileAttributes -band [System.IO.FileAttributes]::ReadOnly)) {
        # if it file check "readonly" attribute
        # folders in Windows have no "readonly" attribute and if target is folder - skip this check
        try {
            Set-ItemProperty -Path $targetPath -Name Attributes -Value ($fileAttributes -bxor [System.IO.FileAttributes]::ReadOnly)
            $isReadOnly = $true
            Set-ItemProperty -Path $targetPath -Name Attributes -Value ($fileAttributes -bor [System.IO.FileAttributes]::ReadOnly)
            $needRunAs = $false
        }
        catch {
            $isReadOnly = $true
            $needRunAs = $true
        }
    }
    else {
        $isReadOnly = $false

        if ($targetIsFile) {
            # if it file
            # we check permissions for write and open - it mean we can modify file
            try {
                $stream = [System.IO.File]::Open($targetPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)
                $stream.Close()
                $needRunAs = $false
            }
            catch {
                $needRunAs = $true
            }
        }
        else {
            # if it folder
            # we check permissions for delete folder
            try {
                # Here we need to check if we need administrator rights to manipulate the folder
                # The only manipulation of the folder from the text in the template is to delete the folder
                # I have not found a normal way to check if administrator rights are needed to delete a folder
                # I found only an alternative way - to create a file in a folder and delete it.
                #   If this happens without errors, then we do not need administrator rights to create and delete a file inside the folder.
                #   Which means most likely to delete the folder too
                # 
                # But this is a bad way because creating and deleting a file is probably a more time-consuming procedure than checking the rights or attributes of a folder.
                # Also, it does not check the actual right to delete the folder. Folders probably have many different rights and "access levels"
                #   and if we have the ability/right to create + delete a file inside a folder,
                #   then it's not a fact that we have the right to delete a folder (this is just my hypothesis)
                # 
                # TODO: Find a normal way to check if you need administrator rights to delete a folder
                $tempFile = [System.IO.Path]::Combine($targetPath, [System.IO.Path]::GetRandomFileName())
                [void](New-Item -Path $tempFile -ItemType File -Force -ErrorAction Stop)
                Remove-Item -Path $tempFile -Force -ErrorAction Stop

                $needRunAs = $false
            }
            catch {
                $needRunAs = $true
            }
        }
    }

    return $isReadOnly, $needRunAs
}


<#
.SYNOPSIS
Move item (file or folder) to bin
#>
function Move-ToRecycleBin {
    param (
        [Parameter(Mandatory)]
        [string]$targetPath
    )
    
    if (-Not (Test-Path $targetPath)) {
        Write-Error "Not found file for move to bin - $targetPath"
        return
    }
    
    [bool]$isFolder = (Get-Item $line).PSIsContainer
    $shell = New-Object -ComObject Shell.Application

    $parentFolder = $shell.Namespace((Get-Item $targetPath).DirectoryName)
    if ($isFolder) {
        $parentFolder = $shell.Namespace((Get-Item $targetPath).Parent.FullName)
    }

    $item = $parentFolder.ParseName((Get-Item $targetPath).Name)

    $item.InvokeVerb("delete")
}


<#
.SYNOPSIS
Delete items (files and folder) from given lines of string
#>
function DeleteFilesOrFolders {
    param (
        [Parameter(Mandatory)]
        [string]$content
    )

    [string]$cleanedContent = $content.Clone().Trim()
    
    # replace variables with variables values in all current content
    foreach ($key in $variables.Keys) {
        $cleanedContent = $cleanedContent.Replace($key, $variables[$key])
    }
    
    [string[]]$cleanedContentLines = $cleanedContent -split "\n"
    
    [bool]$needMoveToBin = $false

    if ($cleanedContentLines[0].Trim() -eq $moveToBinFlag) {
        $needMoveToBin = $true
    }
    
    foreach ($line in $cleanedContentLines) {
        # Trim line is important because end line include \n
        $line = $line.Trim()

        if (-not (Test-Path $line)) {
            continue
        }

        [bool]$isFile = -not ((Get-Item $line).PSIsContainer)
        $isReadOnly, $needRunAS = Test-ReadOnlyAndWriteAccess -targetPath $line -targetIsFile $isFile
        $fileAttributes = Get-Item -Path $line | Select-Object -ExpandProperty Attributes

        if ($isFile) {
            if (DoWeHaveAdministratorPrivileges -or (-not $needRunAS)) {
                if (-not $isReadOnly) {
                    if ($needMoveToBin) {
                        Move-ToRecycleBin -targetPath $line
                    }
                    else {
                        Remove-Item -Path $line -Recurse
                    }
                }
                if ($isReadOnly) {
                    if ($needMoveToBin) {
                        # files with "readonly" attribute can be moved in Bin without problems without remove this attribute
                        Move-ToRecycleBin -targetPath $line
                    }
                    else {
                        Set-ItemProperty -Path $line -Name Attributes -Value ($fileAttributes -bxor [System.IO.FileAttributes]::ReadOnly)
                        Remove-Item -Path $line -Recurse
                    }
                }
            }
            else {
                if ($needRunAS -and (-not $isReadOnly)) {
                    Write-ProblemMsg "Need admins rights for delete: $line"
                    continue
                }
                if ($needRunAS -and $isReadOnly) {
                    Write-ProblemMsg "Need admins rights for delete: $line"
                    continue
                }
                if (-not $isReadOnly) {
                    if ($needMoveToBin) {
                        Move-ToRecycleBin -targetPath $line
                    }
                    else {
                        Remove-Item -Path $line -Recurse
                    }
                }
                if ($isReadOnly) {
                    if ($needMoveToBin) {
                        # files with "readonly" attribute can be moved in Bin without problems without remove this attribute
                        Move-ToRecycleBin -targetPath $line
                    }
                    else {
                        Set-ItemProperty -Path $line -Name Attributes -Value ($fileAttributes -bxor [System.IO.FileAttributes]::ReadOnly)
                        Remove-Item -Path $line -Recurse
                    }
                }
            }
        }
        else {
            # If it is a folder, it is very difficult to determine in advance whether administrator rights are needed to delete it,
            #   because files and folders with different rights may be attached to it and deleting a folder
            #   with such files will require administrator rights.
            # So the surest way to determine if you need administrator rights to delete a folder is to try deleting the folder
            try {
                if ($needMoveToBin) {
                    Move-ToRecycleBin -targetPath $line
                }
                else {
                    Remove-Item -Path $line -Recurse -Force -ErrorAction Stop
                }
            }
            catch {
                Write-ProblemMsg "Need admins rights for delete: $line"
                continue
            }
        }
    }
}
