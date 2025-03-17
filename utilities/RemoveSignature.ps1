# TODO

Add-Type @"
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

# Usage example
$filePath = "C:\path\to\your\file.exe"
$result = [SignatureRemover]::RemoveSignature($filePath)

if ($result) {
    Write-Host "Digital signature has been successfully deleted."
} else {
    Write-Host "The digital signature could not be deleted. Error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
}