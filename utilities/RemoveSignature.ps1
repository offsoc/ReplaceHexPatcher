param (
    [Parameter(Mandatory)]
    [string]$filePath
)

if (-not (Test-Path $filePath)) {
    if (-not (Test-Path -LiteralPath $filePath)) {
        Write-Error "File not found: $filePath"
        exit 1
    }
}

# =====
# GLOBAL VARIABLES
# =====

[string]$filePathFull_Unescaped = [System.IO.Path]::GetFullPath(($filePath -ireplace "``", ""))
[string]$filePathFull = [System.Management.Automation.WildcardPattern]::Escape($filePathFull_Unescaped)



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


try {
    Write-Host "Start trying remove digital signature for file:"
    Write-Host $filePathFull
    Write-Host

    # if any class from C# code exist - C# already imported in the script and not need compile and import it again
    if (-not ("SignatureRemover" -as [Type])) {
        Add-Type -TypeDefinition $signatureHandler -Language CSharp
    }

    [int]$sizeKBOriginal = (Get-ChildItem $filePathFull).Length / 1024
    
    [bool]$result = [SignatureRemover]::RemoveSignature($filePathFull_Unescaped)
    
    if ($result) {
        Write-Host "Digital signature has been successfully deleted!"

        [int]$sizeKBWithoutSignature = (Get-ChildItem $filePathFull).Length / 1024
        
        Write-Host "The file began to size less by $($sizeKBOriginal - $sizeKBWithoutSignature) KB"
    } else {
        [System.Management.Automation.Signature]$signature = Get-AuthenticodeSignature -FilePath $filePathFull

        if (($signature.Status -eq "Valid") -or ($signature.Status -eq "HashMismatch") -or ($signature.Status -eq "NotTrusted")) {
            Write-Error "File still have signature but something went wrong"
            exit 1
        }
        
        if (($signature.Status -eq "UnknownError") -or ($signature.Status -eq "NotSigned") -or ($signature.Status -eq "NotSupportedFileFormat") -or ($signature.Status -eq "Incompatible")) {
            Write-Host "File don't have signature"
        }
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
