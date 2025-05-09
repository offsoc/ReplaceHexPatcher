using System;
using System.IO;

namespace HexAndReplace
{
    /// <summary>
    /// Find/replace binary data in a seekable stream
    /// </summary>
    public sealed class BinaryReplacer : IDisposable
    {
        private readonly Stream stream;
        private readonly int bufferSize;

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="stream">Stream</param>
        /// <param name="bufferSize">Buffer size</param>
        public BinaryReplacer(Stream stream, int bufferSize = ushort.MaxValue)
        {
            if (bufferSize < 2)
                throw new ArgumentOutOfRangeException("bufferSize");

            this.stream = stream;
            this.bufferSize = bufferSize;
        }

        /// <summary>
        /// Find and replace binary data in a stream
        /// </summary>
        /// <param name="find">Find</param>
        /// <param name="replace">Replace</param>
        /// <returns>First index of replaced data, or -1 if find is not found</returns>
        /// <exception cref="ArgumentException">Find and replace are not the same length</exception>
        public long Replace(byte[] find, byte[] replace)
        {
            if (find == null)
                throw new ArgumentNullException("find");
            if (replace == null)
                throw new ArgumentNullException("replace");
            if (find.Length != replace.Length)
                throw new ArgumentException("Find and replace hex must be same length");
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

        /// <summary>
        /// Dispose the stream
        /// </summary>
        public void Dispose()
        {
            stream.Dispose();
        }
    }
}
