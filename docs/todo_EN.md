# List of tasks

Language: [Русский](todo_RU.md) | English

- [List of tasks](#list-of-tasks)
  - [ToDo](#todo)
    - [Miscellaneous](#miscellaneous)
    - [Template Parser](#template-parser)
    - [Search and replace core only](#search-and-replace-core-only)
    - [Information output](#information-output)


Here is a list of functions that are specific and I may forget to implement them.

## ToDo

### Miscellaneous

- [ ] Add a way to unlock target files if they are blocked by another `FileStream.Read()` or used somewhere
- [ ] Find a normal way to check if administrator rights are needed to delete a folder
  - The current method checks this by creating and deleting an empty file in the required folder (this is wrong from the point of view of logic and performance, but in most situations it works as it should)

### Template Parser

- [ ] Implement pattern reading from the file in the patcher itself
- [ ] Implement reading a template from the base64 code
- As in the case of a base64 file, there is an argument string.
- [x] Add sections with `pre-cmd` and `pre-powershell` code and with `post-cmd` and `post-powershell` code
- The code in the sections must be executed before and after the patch is executed according to the section names
  - If the execution of the section code failed, abort the patcher operation.
- [ ] Add [globbing] support(https://stackoverflow.com/questions/30229465/what-is-file-globbing ) in the lines with the paths to the files/folders to be found in the template file
- [ ] Add support for working with relative paths
- Meaning the file paths in the template
- [ ] In the section for deleting files and folders, add support for deleting only all attached data or attached files according to some pattern (for example, `\*exe`), although this is probably globbing.
- [ ] It may be worth adding the logic of running `.ps1` files as an administrator in the parser script.
   - This means files created from the code in the template
- [ ] Replace the current method of restarting the patch with a request for administrator rights
  - The current method is noticeably cumbersome and adds a lot of difficult-to-read code
  - It's worth replacing it with checking whether the file can be read, and the ability to overwrite the file is probably better implemented in the C# core, because the file is being modified there.

### Search and replace core only

- [ ] Rewrite the core in C#
- [x] Implement overloads of all functions to which patterns are passed
  - So that patterns can be transmitted both as a string and as an array of bytes, as well as an array of bytes and an array mask for wildcard characters.
- [x] Implement search support with wildcard `??` in patterns like in [AutoIt](https://www.autoitscript.com/autoit3/docs/functions/StringRegExp.htm) or in [010 Editor](https://www.sweetscape.com/010editor/manual/Find.htm) or in [Frida Memory scan](https://frida.re/docs/javascript-api/#memory)
  - [x] Wildcard in search patterns
  - [x] Wildcard in replacement patterns
  - [x] The functions should check for wildcard characters in the search and replace patterns. If the patterns do not have wildcard symbols, then functions without wildcard support should be used. Because functions with wildcards support have more conditions and checks at each iteration, and they run slower than functions without wildcards support (but this is just a hypothesis).
- [x] Implement the StartsWith and EndsWith functions to verify that a file begins or ends with a specified set of bytes
- [x] Implement search optimization to speed up your search
  - [x] Search optimization in the case when the search pattern starts with or ends with wildcard characters
    - In the case when the search pattern starts with wildcard characters - you need to find the first regular (non-wildcard) byte and search for it, and when searching, indent from the beginning of the file in length between the beginning of the search pattern and the first regular a byte. Otherwise, the search for the wildcard character will turn into a sequential search of all the bytes of the file.
    - If the search pattern ends with wildcard characters, then you do not need to search for them, it will be enough to check that there are more bytes from the current index of the last regular byte in the pattern to the end of the file than there are wildcard characters to the end of the pattern.
  - [x] Search optimization, when the search pattern starts with a sequence of identical characters
    - In the case when the search pattern starts with a sequence of identical characters (for example, in the search pattern, the first 10 bytes are zero bytes), then it is necessary to "virtually delete" all duplicate bytes at the beginning (that is, delete 9 zero bytes), leaving only 1 byte from the sequence of identical ones. When this byte is found, you will need to check that there are 9 bytes in front of it that are the same as itself.
    - I am not sure that this will speed up the work when using patterns with a sequence of identical bytes at the beginning, so it is necessary to conduct competent tests and performance checks with such optimization.
- [ ] Implement a check for the rights to modify/overwrite the file immediately after the first found pattern, rather than after going through all the patterns in the main script
- [ ] To transfer part of the functionality from `ReplaceHexBytesAll` to the C# code
  - Consider the possibility of transferring both to separate classes and to the `BytesHandler` class
- [ ] Reorganize/rewrite/split the kernel code into different files in an OOP-style
  - For example, how [тут](https://github.com/Invertex/BinaryFilePatcher/blob/master/BinaryFilePatcher/BinaryFilePatcher.cs )
- [ ] Implement regular expression support in hex templates as in `sed` or `perl`
  - Maybe [this one](https://stackoverflow.com/a/55314611 ) an example will help
- [ ] Implement the search using the Boyer-Moore-Horspool algorithm
  - [ ] Compare the speed of the current algorithm with the Boyer-Moore-Horspool algorithm
  - Links to examples of implemented search functions by this algorithm are in the [file](./additional_info_EN.md#implementations-of-hex-pattern-search-in-c) with additional information
- [ ] Implement support for deleting found hex patterns from a file
- [ ] Implement a hex pattern search function starting from a specific offset in the file or starting from a specific part of the file in %
- [ ] Implement support specifying indexes of found patterns (if not all found sequences need to be replaced)
- [ ] Figure out whether it's worth storing the C# code inside a Powershell script as a zip archive in base64 or a cab archive.
  - This will help reduce the size of the Powershell script by 10-20 kilobytes, but it will probably increase the duration of its operation, because in order to compile the C# code, you will first need to decode the base64 string, and then unpack the resulting zip archive or cab archive.
  - Most likely it is not necessary
- [ ] Add functionality for working with PE headers
  - https://chentiangemalc.wordpress.com/2021/02/24/parsing-pe-files-in-powershell/
  - https://github.com/secana/PeNet
- [ ] Implement the native CRC32 calculation utility
  - It is worth considering C# code from other projects:
  - https://damieng.com/blog/2006/08/08/calculating_crc32_in_c_and_net/
    - https://github.com/damieng/DamienGKit/blob/master/CSharp/DamienG.Library/Security/Cryptography/Crc32.cs
  - https://github.com/zoltraks/csharp-crc32/blob/main/src/Crc32/Crc32.cs
  - https://forums.mydigitallife.net/threads/c-calculating-crc32-hash-from-any-file-or-string.29306/
  - https://staceyw1.wordpress.com/2005/06/09/crc32-in-c/
  - Perhaps the new version of C#/.NET already has an implementation of the CRC32 calculation - https://learn.microsoft.com/ru-ru/dotnet/api/system.io.hashing.crc32

### Information output

- [ ] Stylize progress bars
  - When searching for Firewall rules with the specified paths to the exe, a progress bar appears that displays the progress of the process. It appears at the top of the terminal simply with the name of the method `Get-NetFirewallRule`
- [ ] Add logging levels
  - Perhaps it is better to regulate this by using a flag in the flags section.
