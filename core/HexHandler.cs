using System;
using System.IO;
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
                throw new ArgumentException("amount replace occurrences should be less than count bytes in stream");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long[] foundPositions = Find(searchPattern, amount);

            for (int i = 0; i < foundPositions.Length; i++)
            {
                stream.Seek(foundPositions[i], SeekOrigin.Begin);
                stream.Write(replacePattern, 0, replacePattern.Length);
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
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long[] foundPositions = FindAll(searchPattern);

            for (int i = 0; i < foundPositions.Length; i++)
            {
                stream.Seek(foundPositions[i], SeekOrigin.Begin);
                stream.Write(replacePattern, 0, replacePattern.Length);
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
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            long foundPosition = Find(searchPattern);
            stream.Seek(foundPosition, SeekOrigin.Begin);
            stream.Write(replacePattern, 0, replacePattern.Length);
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
                throw new ArgumentNullException("position should more than zero");
            if (position > stream.Length)
                throw new ArgumentNullException("position must be within the stream");
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
        /// Find byte array from start a stream
        /// </summary>
        /// <param name="searchPattern">Find</param>
        /// <returns>First index of byte array data, or -1 if find is not found</returns>
        public long Find(byte[] searchPattern)
        {
            if (searchPattern == null)
                throw new ArgumentNullException("searchPattern argument not given");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

            return FindFromPosition(searchPattern, 0);
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
                throw new ArgumentException("amount replace occurrences should be less than count bytes in stream");
            if (searchPattern.Length > bufferSize)
                throw new ArgumentException(string.Format("Find size {0} is too large for buffer size {1}", searchPattern.Length, bufferSize));

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
        /// Dispose the stream
        /// </summary>
        public void Dispose()
        {
            stream.Dispose();
        }
    }
}
