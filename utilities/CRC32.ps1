
param (
    [Parameter(Mandatory)]
    [string]$filePath
)

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
#>
function Get-Crc32 {
    param(
        [Parameter(ValueFromPipeline=$true, ParameterSetName="Text")]
        [string]$InputObject,
        
        [Parameter(Mandatory=$true)]
        [string]$File
    )

    if ($InputObject) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputObject)
    } elseif (Test-Path "$File") {
        $bytes = [System.IO.File]::ReadAllBytes($File)
    } else {
        Write-Error "File not found: $File"
        return
    }

    # compute crc32
    $crc32 = New-Object Crc32
    $hashBytes = $crc32.ComputeHash($bytes)
    $hash = [BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    
    # return result
    [PSCustomObject]@{
        Algorithm = "CRC32"
        Hash = $hash
        Path = if ($PSCmdlet.ParameterSetName -eq "File") { $File } else { $null }
        Content = if ($PSCmdlet.ParameterSetName -eq "Text") { $InputObject } else { $null }
    }
}

# if any method from C# code exist - C# already imported in the script and not need compile and import it again
if (-not ("Crc32" -as [Type])) {
    Add-Type -TypeDefinition $crc32Code -Language CSharp
}

Get-Crc32 -File $filePath
