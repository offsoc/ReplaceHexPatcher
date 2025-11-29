param (
    [Parameter(Mandatory, ValueFromRemainingArguments=$true)]
    [string[]]$filePaths  # Принимаем все оставшиеся аргументы
)

# =====
# GLOBAL VARIABLES
# =====

[string]$signatureHandler = @"
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

# Функция для обработки одного файла
function Remove-SignatureFromFile {
    param (
        [string]$filePath
    )

    if (-not (Test-Path $filePath)) {
        if (-not (Test-Path -LiteralPath $filePath)) {
            Write-Error "File not found: $filePath"
            return $false
        }
    }

    try {
        [string]$filePathFull_Unescaped = [System.IO.Path]::GetFullPath(($filePath -ireplace "``", ""))
        [string]$filePathFull = [System.Management.Automation.WildcardPattern]::Escape($filePathFull_Unescaped)

        Write-Host "Processing file: $filePathFull" -ForegroundColor Cyan

        # if any class from C# code exist - C# already imported in the script and not need compile and import it again
        if (-not ("SignatureRemover" -as [Type])) {
            Add-Type -TypeDefinition $signatureHandler -Language CSharp
        }

        [int]$sizeKBOriginal = (Get-ChildItem $filePathFull).Length / 1024
        
        [bool]$result = [SignatureRemover]::RemoveSignature($filePathFull_Unescaped)
        
        if ($result) {
            Write-Host "Digital signature has been successfully deleted!" -ForegroundColor Green

            [int]$sizeKBWithoutSignature = (Get-ChildItem $filePathFull).Length / 1024
            [int]$sizeReduction = $sizeKBOriginal - $sizeKBWithoutSignature
            
            Write-Host "  The file size reduced by $sizeReduction KB" -ForegroundColor Yellow
            Write-Host ""
            return $true
        } else {
            [System.Management.Automation.Signature]$signature = Get-AuthenticodeSignature -FilePath $filePathFull

            if (($signature.Status -eq "Valid") -or ($signature.Status -eq "HashMismatch") -or ($signature.Status -eq "NotTrusted")) {
                Write-Warning "File still has signature but something went wrong: $($signature.Status)"
                return $false
            }
            
            if (($signature.Status -eq "UnknownError") -or ($signature.Status -eq "NotSigned") -or ($signature.Status -eq "NotSupportedFileFormat") -or ($signature.Status -eq "Incompatible")) {
                Write-Host "File doesn't have a signature: $($signature.Status)" -ForegroundColor Blue
                Write-Host ""
                return $true
            }
        }
    } catch {
        Write-Error "Error processing file '$filePath': $($_.Exception.Message)"
        return $false
    }
    
    return $true
}

# Основная логика обработки файлов
try {
    Write-Host "Starting digital signature removal for $($filePaths.Count) file(s)" -ForegroundColor Green
    Write-Host ""

    # Статистика обработки
    $successCount = 0
    $failCount = 0
    $processedCount = 0

    foreach ($filePath in $filePaths) {
        $processedCount++
        Write-Host "[$processedCount/$($filePaths.Count)] " -ForegroundColor White -NoNewline
        
        if (Remove-SignatureFromFile -filePath $filePath) {
            $successCount++
        } else {
            $failCount++
        }
    }

    # Итоговая статистика
    Write-Host "Processing completed!" -ForegroundColor Green
    Write-Host "Successfully processed: $successCount file(s)" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "Failed: $failCount file(s)" -ForegroundColor Red
    }
    Write-Host "Total processed: $processedCount file(s)" -ForegroundColor Cyan

    # Возвращаем код ошибки, если были неудачи
    if ($failCount -gt 0) {
        exit 1
    }

} catch {
    Write-Error "Critical error: $($_.Exception.Message)"
    exit 1
}