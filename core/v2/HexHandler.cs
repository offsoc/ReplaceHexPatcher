using System;
using System.IO;
using System.Globalization;
using System.Collections.Generic;

namespace HexHandler
{
    /// <summary>
    /// Find/replace binary data in a seekable stream
    /// </summary>
    public sealed class BytesHandler : IDisposable
    {
        private readonly Stream stream;
        private readonly int bufferSize;
        private static readonly string wildcard = "??";

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="stream">Stream</param>
        /// <param name="bufferSize">Buffer size</param>
        public BytesHandler(Stream stream, int bufferSize = ushort.MaxValue)
        {
            if (bufferSize < 2)
                throw new ArgumentOutOfRangeException("bufferSize less than 2 bytes");

            this.stream = stream;
            this.bufferSize = bufferSize;
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

        private static Tuple<byte[], bool[]> ConvertHexStringWithWildcardsToByteArrayAndMask(string hexString)
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
            bool[] mask = new bool[data.Length];

            for (int index = 0; index < data.Length; index++)
            {
                string byteValue = hexStringCleaned.Substring(index * 2, 2);
                if (byteValue == wildcard)
                {
                    data[index] = byte.Parse("00", NumberStyles.HexNumber, CultureInfo.InvariantCulture);
                    mask[index] = true;
                }
                else
                {
                    data[index] = byte.Parse(byteValue, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
                    mask[index] = false;
                }
            }

            return Tuple.Create(data, mask);
        }

        /// <summary>
        /// Find and replace all occurrences binary data in a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <param name="replacePattern">Replace</param>
        /// <returns>All indexes of replaced data</returns>
        public long[] Replace(byte[] searchPattern, byte[] replacePattern, int amount)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (replacePattern == null)
                throw new ArgumentNullException("replacePattern argument not given");
            if (amount > stream.Length)
                throw new ArgumentOutOfRangeException("amount replace occurrences should be less than count bytes in stream");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentOutOfRangeException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long[] foundPositions = Find(searchPattern, amount);

            if (foundPositions.Length > 1 && foundPositions[0] != -1)
            {
                for (int i = 0; i < foundPositions.Length; i++)
                {
                    stream.Seek(foundPositions[i], SeekOrigin.Begin);
                    stream.Write(replacePattern, 0, replacePattern.Length);
                }
            }

            stream.Seek(0, SeekOrigin.Begin);
            return foundPositions;
        }

        /// <summary>
        /// Find and replace all occurrences binary data in a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <param name="replacePattern">Replace</param>
        /// <returns>All indexes of replaced data</returns>
        public long[] ReplaceAll(byte[] searchPattern, byte[] replacePattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (replacePattern == null)
                throw new ArgumentNullException("replacePattern argument not given");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentOutOfRangeException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long[] foundPositions = FindAll(searchPattern);

            if (foundPositions.Length > 1 && foundPositions[0] != -1)
            {
                for (int i = 0; i < foundPositions.Length; i++)
                {
                    stream.Seek(foundPositions[i], SeekOrigin.Begin);
                    stream.Write(replacePattern, 0, replacePattern.Length);
                }
            }

            stream.Seek(0, SeekOrigin.Begin);
            return foundPositions;
        }

        /// <summary>
        /// Find and replace once binary data in a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <param name="replacePattern">Replace</param>
        /// <returns>First index of replaced data, or -1 if find is not found</returns>
        public long ReplaceOnce(byte[] searchPattern, byte[] replacePattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (replacePattern == null)
                throw new ArgumentNullException("replacePattern argument not given");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentOutOfRangeException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long foundPosition = Find(searchPattern);

            if (foundPosition != -1)
            {
                stream.Seek(foundPosition, SeekOrigin.Begin);
                stream.Write(replacePattern, 0, replacePattern.Length);
            }

            stream.Seek(0, SeekOrigin.Begin);
            return foundPosition;
        }

        /// <summary>
        /// Find byte array in a stream start from given decimal position
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <param name="position">Initial position in stream</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long FindFromPosition(byte[] searchPattern, long position = 0)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (position < 0)
                throw new ArgumentOutOfRangeException("position should more than zero");
            if (position > stream.Length)
                throw new ArgumentOutOfRangeException("position must be within the stream body");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long foundPosition = -1;
            byte[] buffer = new byte[bufferSize + searchPattern.Length - 1];
            int bytesRead;
            stream.Position = position;

            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) > 0)
            {
                int index = 0;

                while (index <= (bytesRead - searchPattern.Length))
                {
                    int foundIndex = Array.IndexOf(buffer, searchPattern[0], index);

                    if (foundIndex == -1 || foundIndex + searchPattern.Length > buffer.Length)
                        break;

                    bool match = true;
                    for (int j = 1; j < searchPattern.Length; j++)
                    {
                        if (buffer[foundIndex + j] != searchPattern[j])
                        {
                            match = false;
                            break;
                        }
                    }

                    if (match)
                    {
                        foundPosition = position + foundIndex;
                        return foundPosition;
                    }
                    else
                    {
                        index = foundIndex + 1;
                    }
                }

                position += bytesRead - searchPattern.Length + 1;
                if (position > stream.Length - searchPattern.Length)
                {
                    break;
                }
                stream.Seek(position, SeekOrigin.Begin);
            }

            return foundPosition;
        }


        /// <summary>
        /// Find byte array in a stream start from given decimal position
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <param name="wildcardsMask">Mask if symbol is wildcards</param>
        /// <param name="position">Initial position in stream</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long FindFromPosition_WithWildcards(byte[] searchPattern, bool[] wildcardsMask, long position = 0)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (wildcardsMask == null)
                throw new ArgumentNullException("wildcardsMask argument not given");
            if (searchPattern.Length != wildcardsMask.Length)
                throw new ArgumentException("wildcardsMask and search pattern must be same length");
            if (position < 0)
                throw new ArgumentOutOfRangeException("position should more than zero");
            if (position > stream.Length)
                throw new ArgumentOutOfRangeException("position must be within the stream body");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentOutOfRangeException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            bool isMaskFilledWildcards = Array.TrueForAll(wildcardsMask, x => x);
            if (isMaskFilledWildcards)
            {
                return position;
            }

            bool isMaskHasNoWildcards = Array.TrueForAll(wildcardsMask, x => !x);
            if (isMaskHasNoWildcards)
            {
                return FindFromPosition(searchPattern, position);
            }

            long foundPosition = -1;
            byte[] buffer = new byte[bufferSize + searchPattern.Length - 1];
            int bytesRead;
            stream.Position = position;

            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) > 0)
            {
                int index = 0;

                while (index <= (bytesRead - searchPattern.Length))
                {
                    int foundIndex = Array.IndexOf(buffer, searchPattern[0], index);

                    if (foundIndex == -1 || foundIndex + searchPattern.Length > buffer.Length)
                        break;

                    bool match = true;
                    for (int j = 1; j < searchPattern.Length; j++)
                    {
                        if (!wildcardsMask[j] && buffer[foundIndex + j] != searchPattern[j])
                        {
                            match = false;
                            break;
                        }
                    }

                    if (match)
                    {
                        foundPosition = position + foundIndex;
                        return foundPosition;
                    }
                    else
                    {
                        index = foundIndex + 1;
                    }
                }

                position += bytesRead - searchPattern.Length + 1;
                if (position > stream.Length - searchPattern.Length)
                {
                    break;
                }
                stream.Seek(position, SeekOrigin.Begin);
            }

            return foundPosition;
        }

        /// <summary>
        /// Find byte array in a stream start from given decimal position
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <param name="position">Initial position in stream</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long FindFromPosition(string searchPattern, long position = 0)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (position < 0)
                throw new ArgumentOutOfRangeException("position should more than zero");
            if (position > stream.Length)
                throw new ArgumentOutOfRangeException("position must be within the stream body");

            byte[] searchPatternBytes = ConvertHexStringToByteArray(searchPattern);
            return FindFromPosition(searchPatternBytes, position);
        }

        /// <summary>
        /// Find byte array from start a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long Find_WithWildcards(string searchPattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");

            Tuple<byte[], bool[]> dataPair = ConvertHexStringWithWildcardsToByteArrayAndMask(searchPattern);
            byte[] searchPatternBytes = dataPair.Item1;
            bool[] wildcardsMask = dataPair.Item2;
            return FindFromPosition_WithWildcards(searchPatternBytes, wildcardsMask, 0);
        }

        /// <summary>
        /// Find byte array from start a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long Find(string searchPattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");

            byte[] searchPatternBytes = ConvertHexStringToByteArray(searchPattern);
            return FindFromPosition(searchPatternBytes, 0);
        }

        /// <summary>
        /// Find byte array from start a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long Find(byte[] searchPattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentOutOfRangeException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            return FindFromPosition(searchPattern, 0);
        }

        /// <summary>
        /// Find byte array from start a stream for a set number of times
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>Indexes of found set occurrences or array with -1 or array with less amount indexes if occurrences less than given amount number</returns>
        public long[] Find(string searchPattern, int amount)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (amount > stream.Length)
                throw new ArgumentOutOfRangeException("amount replace occurrences should be less than count bytes in stream");

            byte[] searchPatternBytes = ConvertHexStringToByteArray(searchPattern);

            List<long> foundPositions = new List<long>();

            return Find(searchPatternBytes, amount);
        }

        /// <summary>
        /// Find byte array from start a stream for a set number of times
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>Indexes of found set occurrences or array with -1 or array with less amount indexes if occurrences less than given amount number</returns>
        public long[] Find(byte[] searchPattern, int amount)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (amount > stream.Length)
                throw new ArgumentOutOfRangeException("amount replace occurrences should be less than count bytes in stream");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentOutOfRangeException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            List<long> foundPositions = new List<long>();
            long firstFoundPosition = Find(searchPattern);
            foundPositions.Add(firstFoundPosition);

            if (firstFoundPosition > 0 || amount > 1)
            {
                for (int i = 1; i < amount; i++)
                {
                    long nextFoundPosition = FindFromPosition(searchPattern, foundPositions[foundPositions.Count - 1] + 1);

                    if (nextFoundPosition > 0)
                    {
                        foundPositions.Add(nextFoundPosition);
                    }
                    else
                    {
                        break;
                    }
                }
            }

            return foundPositions.ToArray();
        }

        /// <summary>
        /// Find all occurrences of byte array from start a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>Indexes of found all occurrences or array with -1</returns>
        public long[] FindAll(byte[] searchPattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            List<long> foundPositionsList = new List<long>();
            long foundPosition = Find(searchPattern);
            foundPositionsList.Add(foundPosition);

            if (foundPosition > 0)
            {
                while (foundPosition < stream.Length - searchPattern.Length)
                {
                    foundPosition = FindFromPosition(searchPattern, foundPositionsList[foundPositionsList.Count - 1] + 1);

                    if (foundPosition > 0)
                    {
                        foundPositionsList.Add(foundPosition);
                    }
                    else
                    {
                        break;
                    }
                }
            }

            return foundPositionsList.ToArray();
        }

        /// <summary>
        /// Find all occurrences of byte array from start a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>Indexes of found all occurrences or array with -1</returns>
        public long[] FindAll_WithWildcards(string searchPattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentOutOfRangeException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            List<long> foundPositionsList = new List<long>();
            long foundPosition = Find_WithWildcards(searchPattern);
            foundPositionsList.Add(foundPosition);
            
            Tuple<byte[], bool[]> dataPair = ConvertHexStringWithWildcardsToByteArrayAndMask(searchPattern);
            byte[] searchPatternBytes = dataPair.Item1;
            bool[] wildcardsMask = dataPair.Item2;

            if (foundPosition > 0)
            {
                while (foundPosition < stream.Length - searchPatternBytes.Length)
                {
                    foundPosition = FindFromPosition_WithWildcards(searchPatternBytes, wildcardsMask, foundPositionsList[foundPositionsList.Count - 1] + 1);

                    if (foundPosition > 0)
                    {
                        foundPositionsList.Add(foundPosition);
                    }
                    else
                    {
                        break;
                    }
                }
            }

            return foundPositionsList.ToArray();
        }

        /// <summary>
        /// Paste bytes sequence start from given offset (replace bytes sequence start from offset)
        /// </summary>
        /// <param name="sequence">Bytes sequence</param>
        /// <param name="offset">Position in decimal</param>
        public void PasteBytesSequenceAtOffset(byte[] sequence, long offset)
        {
            if (sequence == null)
                throw new ArgumentNullException("sequence argument not given");
            if (offset < 0)
                throw new ArgumentOutOfRangeException("offset should more than zero");
            if (offset > stream.Length)
                throw new ArgumentOutOfRangeException("offset must be within the stream");
            if (offset + sequence.Length > stream.Length)
                throw new ArgumentOutOfRangeException("sequence must not extend beyond the file");

            stream.Seek(offset, SeekOrigin.Begin);
            stream.Write(sequence, 0, sequence.Length);
            stream.Seek(0, SeekOrigin.Begin);
        }

        /// <summary>
        /// Paste bytes sequence start from given offset (replace bytes sequence start from offset) with wildcards
        /// </summary>
        /// <param name="sequence">Bytes sequence</param>
        /// <param name="wildcardsMask">wildcardsMask</param>
        /// <param name="offset">Position in decimal</param>
        private void PasteBytesSequenceAtOffset_WithWildcardsMask(byte[] sequence, bool[] wildcardsMask, long offset)
        {
            if (sequence == null)
                throw new ArgumentNullException("sequence argument not given");
            if (wildcardsMask == null)
                throw new ArgumentNullException("wildcardsMask argument not given");
            if (sequence.Length != wildcardsMask.Length)
                throw new ArgumentException("wildcardsMask and sequence bytes must be same length");
            if (offset < 0)
                throw new ArgumentOutOfRangeException("offset should more than zero");
            if (offset > stream.Length)
                throw new ArgumentOutOfRangeException("offset must be within the stream");
            if (offset + sequence.Length > stream.Length)
                throw new ArgumentOutOfRangeException("sequence must not extend beyond the file");

            stream.Seek(offset, SeekOrigin.Begin);

            for (int i = 0; i < sequence.Length; i++)
            {
                if (wildcardsMask[i])
                {
                    stream.Position += 1;
                    continue;
                }

                stream.WriteByte(sequence[i]);
            }

            stream.Seek(0, SeekOrigin.Begin);
        }

        /// <summary>
        /// Paste bytes sequence start from given offset (replace bytes sequence start from offset)
        /// </summary>
        /// <param name="sequence">Bytes sequence</param>
        /// <param name="offset">Position in decimal</param>
        public void PasteBytesSequenceAtOffset(string sequence, long offset)
        {
            if (string.IsNullOrEmpty(sequence))
                throw new ArgumentNullException("sequence argument not given");
            if (offset < 0)
                throw new ArgumentOutOfRangeException("offset should more than zero");
            if (offset > stream.Length)
                throw new ArgumentOutOfRangeException("offset must be within the stream");

            bool isSequenceHaveWildcards = sequence.IndexOf(wildcard) != -1;
            
            if (isSequenceHaveWildcards)
            {
                Tuple<byte[], bool[]> dataPair = ConvertHexStringWithWildcardsToByteArrayAndMask(sequence);
                byte[] searchPatternBytes = dataPair.Item1;
                bool[] wildcardsMask = dataPair.Item2;

                PasteBytesSequenceAtOffset_WithWildcardsMask(searchPatternBytes, wildcardsMask, offset);
            }
            else
            {
                byte[] sequenceArr = ConvertHexStringToByteArray(sequence);
                PasteBytesSequenceAtOffset(sequenceArr, offset);
            }
        }

        /// <summary>
        /// Dispose the stream
        /// </summary>
        public void Dispose()
        {
            stream.Dispose();
        }




        // 
        // 
        // LEGACY FUNCTIONS
        // 
        // I left these functions in a separate block of code because they seem to me to be faster due to the fact that when they work, an array with all the positions of the bytes found is not created, but simply 1 pass through the bytes of the stream is performed.
        // I haven't done any speed tests or comparisons, but it seems to me that these functions will be faster compared to functions based first on searching for positions, and then switching to each position found.
        // 
        // 





        /// <summary>
        /// Find byte array in a stream start from given decimal position
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <param name="position">Initial position in stream</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long FindFromPosition_legacy(byte[] searchPattern, long position = 0)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (position < 0)
                throw new ArgumentNullException("position should more than zero");
            if (position > stream.Length)
                throw new ArgumentNullException("position must be within the stream body");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long foundPosition = -1;
            byte[] buffer = new byte[bufferSize + searchPattern.Length - 1];
            int bytesRead;
            stream.Position = position;

            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) > 0)
            {
                for (int i = 0; i <= bytesRead - searchPattern.Length; i++)
                {
                    bool match = true;
                    for (int j = 0; j < searchPattern.Length; j++)
                    {
                        if (buffer[i + j] != searchPattern[j])
                        {
                            match = false;
                            break;
                        }
                    }

                    if (match)
                    {
                        foundPosition = position + i;
                        return foundPosition;
                    }
                }

                position += bytesRead - searchPattern.Length + 1;
                if (position > stream.Length - searchPattern.Length)
                {
                    break;
                }
                stream.Seek(position, SeekOrigin.Begin);
            }

            return foundPosition;
        }

        /// <summary>
        /// Find and replace all occurrences binary data in a stream
        /// </summary>
        /// <param name="find">Find</param>
        /// <param name="replace">Replace</param>
        /// <returns>All indexes of replaced data</returns>
        public long[] Replace_legacy(byte[] find, byte[] replace, int amount)
        {
            if (amount < 1)
                throw new ArgumentNullException("amount argument must be more than 0");
            if (find == null)
                throw new ArgumentNullException("find argument not given");
            if (replace == null)
                throw new ArgumentNullException("replace argument not given");
            if (find.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", find.Length, bufferSize));

            long position = 0;
            List<long> foundPositions = new List<long>();
            byte[] buffer = new byte[bufferSize + find.Length - 1];
            int bytesRead;
            stream.Position = 0;

            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) > 0)
            {
                for (int i = 0; i <= bytesRead - find.Length; i++)
                {
                    bool match = true;
                    for (int j = 0; j < find.Length; j++)
                    {
                        if (buffer[i + j] != find[j])
                        {
                            match = false;
                            break;
                        }
                    }

                    if (match)
                    {
                        stream.Seek(position + i, SeekOrigin.Begin);
                        stream.Write(replace, 0, replace.Length);

                        if (foundPositions.Count < amount)
                        {
                            foundPositions.Add(position + i);
                        }
                        else
                        {
                            return foundPositions.ToArray();
                        }
                    }
                }

                position += bytesRead - find.Length + 1;
                if (position > stream.Length - find.Length)
                {
                    break;
                }
                stream.Seek(position, SeekOrigin.Begin);
            }

            return foundPositions.ToArray();
        }

        /// <summary>
        /// Find and replace all occurrences binary data in a stream
        /// </summary>
        /// <param name="find">Find</param>
        /// <param name="replace">Replace</param>
        /// <returns>All indexes of replaced data</returns>
        public long[] ReplaceAll_legacy(byte[] find, byte[] replace)
        {
            if (find == null)
                throw new ArgumentNullException("find argument not given");
            if (replace == null)
                throw new ArgumentNullException("replace argument not given");
            if (find.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", find.Length, bufferSize));

            long position = 0;
            List<long> foundPositions = new List<long>();
            byte[] buffer = new byte[bufferSize + find.Length - 1];
            int bytesRead;
            stream.Position = 0;

            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) > 0)
            {
                for (int i = 0; i <= bytesRead - find.Length; i++)
                {
                    bool match = true;
                    for (int j = 0; j < find.Length; j++)
                    {
                        if (buffer[i + j] != find[j])
                        {
                            match = false;
                            break;
                        }
                    }

                    if (match)
                    {
                        stream.Seek(position + i, SeekOrigin.Begin);
                        stream.Write(replace, 0, replace.Length);
                        foundPositions.Add(position + i);
                    }
                }

                position += bytesRead - find.Length + 1;
                if (position > stream.Length - find.Length)
                {
                    break;
                }
                stream.Seek(position, SeekOrigin.Begin);
            }

            return foundPositions.ToArray();
        }

        /// <summary>
        /// Find and replace once binary data in a stream
        /// </summary>
        /// <param name="find">Find</param>
        /// <param name="replace">Replace</param>
        /// <returns>First index of replaced data, or -1 if find is not found</returns>
        public long ReplaceOnce_legacy(byte[] find, byte[] replace)
        {
            if (find == null)
                throw new ArgumentNullException("find argument not given");
            if (replace == null)
                throw new ArgumentNullException("replace argument not given");
            if (find.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", find.Length, bufferSize));

            long position = 0;
            long foundPosition = -1;
            byte[] buffer = new byte[bufferSize + find.Length - 1];
            int bytesRead;
            stream.Position = 0;

            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) > 0)
            {
                for (int i = 0; i <= bytesRead - find.Length; i++)
                {
                    bool match = true;
                    for (int j = 0; j < find.Length; j++)
                    {
                        if (buffer[i + j] != find[j])
                        {
                            match = false;
                            break;
                        }
                    }

                    if (match)
                    {
                        stream.Seek(position + i, SeekOrigin.Begin);
                        stream.Write(replace, 0, replace.Length);
                        if (foundPosition == -1)
                        {
                            foundPosition = position + i;
                            return foundPosition;
                        }
                    }
                }

                position += bytesRead - find.Length + 1;
                if (position > stream.Length - find.Length)
                {
                    break;
                }
                stream.Seek(position, SeekOrigin.Begin);
            }

            return foundPosition;
        }
    }
}
