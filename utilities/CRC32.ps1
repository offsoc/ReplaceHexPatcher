param (
    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$filePaths = @(),
    
    [switch]$UpperCase,
    [switch]$HashOnly
)

# Если файлы не переданы как параметры, проверяем аргументы командной строки
if ($filePaths.Count -eq 0) {
    if ($args.Count -gt 0) {
        $filePaths = $args
    }
    else {
        Write-Host "Usage: .\CRC32.ps1 file1 [file2 file3 ...] [-UpperCase] [-HashOnly]" -ForegroundColor Yellow
        Write-Host "Or: .\CRC32.ps1 -filePaths file1, file2, file3 [-UpperCase] [-HashOnly]" -ForegroundColor Yellow
        Write-Host "If -UpperCase switch is provided, hash will be in uppercase, otherwise lowercase" -ForegroundColor Gray
        Write-Host "If -HashOnly switch is provided, only hashes will be printed (one per line)" -ForegroundColor Gray
        exit 1
    }
}

# code provided https://chat.deepseek.com/
$crc32Code = @"
using System;
using System.IO;
using System.Security.Cryptography;

public class Crc32 : HashAlgorithm {
    public const uint DefaultPolynomial = 0xedb88320;
    public const uint DefaultSeed = 0xffffffff;
    private uint hash;
    private uint seed;
    private uint[] table;
    private static uint[] defaultTable;

    public Crc32() {
        table = InitializeTable(DefaultPolynomial);
        seed = DefaultSeed;
        Initialize();
    }

    public Crc32(uint polynomial, uint seed) {
        table = InitializeTable(polynomial);
        this.seed = seed;
        Initialize();
    }

    public override void Initialize() {
        hash = seed;
    }

    protected override void HashCore(byte[] buffer, int start, int length) {
        hash = CalculateHash(table, hash, buffer, start, length);
    }

    protected override byte[] HashFinal() {
        byte[] hashBuffer = UInt32ToBigEndianBytes(~hash);
        this.HashValue = hashBuffer;
        return hashBuffer;
    }

    public override int HashSize { get { return 32; } }

    public static uint Compute(byte[] buffer) {
        return ~CalculateHash(InitializeTable(DefaultPolynomial), DefaultSeed, buffer, 0, buffer.Length);
    }

    private static uint[] InitializeTable(uint polynomial) {
        if (polynomial == DefaultPolynomial && defaultTable != null)
            return defaultTable;

        uint[] createTable = new uint[256];
        for (uint i = 0; i < 256; i++) {
            uint entry = i;
            for (int j = 0; j < 8; j++)
                if ((entry & 1) == 1)
                    entry = (entry >> 1) ^ polynomial;
                else
                    entry >>= 1;
            createTable[i] = entry;
        }

        if (polynomial == DefaultPolynomial)
            defaultTable = createTable;

        return createTable;
    }

    private static uint CalculateHash(uint[] table, uint seed, byte[] buffer, int start, int size) {
        uint crc = seed;
        for (int i = start; i < size; i++)
            crc = (crc >> 8) ^ table[buffer[i] ^ (crc & 0xff)];
        return crc;
    }

    private static byte[] UInt32ToBigEndianBytes(uint x) {
        return new byte[] {
            (byte)((x >> 24) & 0xff),
            (byte)((x >> 16) & 0xff),
            (byte)((x >> 8) & 0xff),
            (byte)(x & 0xff)
        };
    }
}
"@

<#
.SYNOPSIS
    Compute CRC32 for file or text
.DESCRIPTION
    Use implementation CRC32 on C# for compute
.EXAMPLE
    Get-Crc32 -File "C:\path\to\file.txt"
.EXAMPLE
    "Test string" | Get-Crc32
.EXAMPLE
    Get-Crc32 -File @("file1.txt", "file2.txt") -UpperCase
.EXAMPLE
    Get-Crc32 -File @("file1.txt", "file2.txt") -HashOnly
#>
function Get-Crc32 {
    param(
        [Parameter(ValueFromPipeline=$true, ParameterSetName="Text")]
        [string]$InputObject,
        
        [Parameter(Mandatory=$true, ParameterSetName="File")]
        [string[]]$File,
        
        [switch]$UpperCase,
        [switch]$HashOnly
    )

    begin {
        $results = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq "Text" -and $InputObject) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputObject)
            $crc32 = New-Object Crc32
            $hashBytes = $crc32.ComputeHash($bytes)
            $hash = [BitConverter]::ToString($hashBytes).Replace("-", "")
            $hash = if ($UpperCase) { $hash.ToUpper() } else { $hash.ToLower() }
            
            $results += [PSCustomObject]@{
                Algorithm = "CRC32"
                Hash = $hash
                Path = $null
                Content = $InputObject
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "File" -and $File) {
            foreach ($fileItem in $File) {
                if (Test-Path $fileItem -PathType Leaf) {
                    try {
                        $bytes = [System.IO.File]::ReadAllBytes($fileItem)
                        $crc32 = New-Object Crc32
                        $hashBytes = $crc32.ComputeHash($bytes)
                        $hash = [BitConverter]::ToString($hashBytes).Replace("-", "")
                        $hash = if ($UpperCase) { $hash.ToUpper() } else { $hash.ToLower() }
                        
                        $results += [PSCustomObject]@{
                            Algorithm = "CRC32"
                            Hash = $hash
                            Path = (Resolve-Path $fileItem).Path
                            Content = $null
                        }
                    }
                    catch {
                        Write-Warning "Error reading file '$fileItem': $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Warning "File not found or is not a file: $fileItem"
                }
            }
        }
    }

    end {
        return $results
    }
}

# Load C# code if not already loaded
if (-not ("Crc32" -as [Type])) {
    Add-Type -TypeDefinition $crc32Code -Language CSharp
}

# Process all files
$results = Get-Crc32 -File $filePaths -UpperCase:$UpperCase -HashOnly:$HashOnly

# Display results
if ($results) {
    if ($HashOnly) {
        # Output only hashes, one per line
        foreach ($result in $results) {
            $result.Hash
        }
    }
    else {
        # Output full table
        $results | Format-Table -AutoSize
    }
}
else {
    Write-Host "No files were processed successfully." -ForegroundColor Red
}
