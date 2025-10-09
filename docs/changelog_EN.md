## List of changes:

Language: [Русский](changelog_RU.md) | English

### v2.0

Working with bytes and hex patterns:
- The core has been rewritten in C#
- Now the speed of byte search and replacement has increased many times, especially for small-length patterns
  - The C# kernel code is inside a Powershell script in an uncompiled form and is compiled when the script is run
  - the C# code is written in C# v4.8, which allows it to be compiled natively into Windows 10 without installing anything.
  - The C# code also contains various additional functions that are not involved in the ReplaceHexBytesAll patch, but may be useful to those who want to perform various byte operations using C# in other projects.
- Added support for using replacement patterns of shorter and longer length than search patterns
  - Replacement patterns will not replace search patterns, but will be inserted into the positions/offsets of the found places of the search patterns, and replacement patterns will be inserted from the beginning of the found positions, overwriting the bytes in which they are inserted
  - This will allow you to write more readable pairs of patterns in situations where you need to change bytes only at the beginning of the found search patterns.
- Added the `-skipStopwatch` argument to disable the stopwatch if you are not interested in the speed of the search and replace performed 
- Added the `-onlyCheckOccurrences` argument to check the occurrence of patterns without replacing them
  - That is, only for searching patterns-searching and displaying information about search results 
- Arguments `-showMoreInfo`, `-showFoundOffsetsInDecimal`, `-showFoundOffsetsInHex` have been added to display more detailed information about the changes made

Working with a template:
- Removed support in the template for multiple sections for creating files - `file_create_from_text` and `file_create_from_base64`
  - Now the parser will use only the first section found, not all of them.
  - If you need to create/unpack several files and they are small, you can pack them into a zip archive, and put it as a base64 code and process it and the files from it using powershell or cmd code. Or put this archive next to the template and also process this moment in the sections with the code.
- Removed the global variable `$USER` to `$env:USERNAME`
- Added global variables, support for replacing the text `USERNAME_FIELD`, `USERPROFILE_FIELD` and `USERHOME_FIELD` with `$env:USERNAME` and `$env:USERPROFILE`
  - So that these variables can be used in the text with paths when it is necessary to specify the path to files/folders located inside the user's folder.
- Added support for comments with `#`
- Added support for template processing if it is transmitted as a base64 code
  - This is convenient if the template needs to be placed on some public server and at least minimally hide what it does. If a pirated modification/patch of the program is used as a template, the template may be deleted, but the base64 text is less likely to be suspected.
- Removed support for the `BINARY DATA` flag for the base64 file creation section
- the base64 code is decoded into bytes and a file is created from these bytes. There is no need to label the contents in encrypted base64 code.
- Added new flags: `REMOVE_SIGN_PATCHED_PE`, `CHECK_OCCURRENCES_ONLY`, `CHECK_ALREADY_PATCHED_ONLY`, `EXIT_IF_NO_ADMINS_RIGHTS`, `SHOW_EXECUTION_TIME`, `SHOW_SPACES_IN_LOGGED_PATTERNS`, `REMOVE_SPACES_IN_LOGGED_PATTERNS`, ` PATCH_ONLY_ALL_PATTERNS_EXIST`

Other:
- Added a native utility to remove the digital signature from PE files (.exe, .dll and others)
- Added support for checking the link and downloading addresses from it to add to hosts
  - if the first line in the add section contains the text `SEE_HERE_FIRST`, and then a link to the list and the link is indeed there and it is available for download, then we add the content downloaded from the link to hosts, and not the rest of the lines in the add section
- Fixed various bugs
- Optimization of some code has been performed
- Fixed the starter script `Start.cmd`

### v1.4

- Fixed some bugs
- Added support wildcards `??` for search and replace hex-patterns

### v1.3

- Fixed some bugs
- Added additional folder for testing only algorithms/strategies for search + replace bytes and added some algorithms
- Found fast algorithm for search + replace bytes
- Replaced algorithm in patcher and refactored it

### v1.2

- Fixed some bugs
- Extracted main functions in separated Powershell-files and import it by condition

### v1.1

- Fixed case when patterns not found in patcher
- Fixed case in patcher when we have no rights for read file

### v1.0

- Initial release with full working version
