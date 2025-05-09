using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace HexHandler
{
    /// <summary>
    /// App
    /// </summary>
    public static class HexAndReplaceApp
    {
        /// <summary>
        /// Main
        /// </summary>
        /// <param name="args">Args</param>
        public static int Main(string[] args)
        {
            if (args.Length != 0 && args[0] == "test")
            {
                DoTests();
                return -2;
            }

            if (args.Length < 3)
            {
                Console.WriteLine("Replace first instance of one hex sequence with another. Usage: <File Name> <Find Hex> <Replacement Hex>.");
                return -1;
            }

            byte[] find = ConvertHexStringToByteArray(args[1]);
            byte[] replace = ConvertHexStringToByteArray(args[2]);
            
            using (BytesReplacer replacer = new BytesReplacer(File.Open(args[0], FileMode.Open)))
            {
                long pos = replacer.ReplaceOnce(find, replace);

                if (pos >= 0)
                {
                    Console.WriteLine(string.Format("Pattern found and replaced at position {0}", pos));
                }

                long[] positions = replacer.ReplaceAll(find, replace);

                if (positions.Length >= 0)
                {
                    Console.WriteLine(string.Format("Pattern found and replaced at positions {0}", String.Join(", ", positions)));
                    return 0;
                }
            }

            Console.WriteLine("Pattern not found");
            return -1;
        }

        private static byte[] ConvertHexStringToByteArray(string hexString)
        {
            string hexStringCleaned = hexString.Replace(" ", string.Empty)
                                                .Replace("\\x", string.Empty)
                                                .Replace("0x", string.Empty)
                                                .Replace(",", string.Empty)
                                                .Normalize()
                                                .Trim();

            if (hexStringCleaned.Length % 2 != 0)
            {
                throw new ArgumentException(string.Format(CultureInfo.InvariantCulture, 
                    "The binary key cannot have an odd number of digits: {0}", hexStringCleaned));
            }

            byte[] data = new byte[hexStringCleaned.Length / 2];
            for (int index = 0; index < data.Length; index++)
            {
                string byteValue = hexStringCleaned.Substring(index * 2, 2);
                data[index] = byte.Parse(byteValue, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            }

            return data;
        }

        private static void DoTests()
        {
            Console.WriteLine("Running tests...");

            for (var i = 2; i <= 16; i++)
            {
                DoTest(i);
            }

            Console.WriteLine("All passed");
        }

        private static void DoTest(int bufferSize)
        {
            using (MemoryStream ms = new MemoryStream())
            {
                ms.Write(new byte[] { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x03, 0x04, 0x07, 0x08 }, 0, 10);
                ms.Seek(0, SeekOrigin.Begin);
                
                using (BytesReplacer replacer = new BytesReplacer(ms, bufferSize))
                {
                    long pos = replacer.ReplaceOnce(new byte[] { 0x03, 0x04 }, new byte[] { 0x0A, 0x0B });
                    if (pos != 2)
                    {
                        throw new ApplicationException("Test failed");
                    }

                    pos = replacer.ReplaceOnce(new byte[] { 0x03, 0x04 }, new byte[] { 0x0A, 0x0B });
                    if (pos != -1)
                    {
                        throw new ApplicationException("Test failed");
                    }

                    pos = replacer.ReplaceOnce(new byte[] { 0x07, 0x08 }, new byte[] { 0x0C, 0x0D });
                    if (pos != 8)
                    {
                        throw new ApplicationException("Test failed");
                    }

                    pos = replacer.ReplaceOnce(new byte[] { 0x07, 0x08 }, new byte[] { 0x0C, 0x0D });
                    if (pos != -1)
                    {
                        throw new ApplicationException("Test failed");
                    }

                    var finalSequence = new byte[] { 0x01, 0x02, 0x0A, 0x0B, 0x05, 0x06, 0x0A, 0x0B, 0x0C, 0x0D };
                    if (!ms.ToArray().SequenceEqual(finalSequence))
                    {
                        throw new ApplicationException("Test failed");
                    }
                }
            }
        }
    }
}