## List of changes:

Language: [Русский](changelog_RU.md) | English

### v2.3

Added:
- template flag `PATCH_ONLY_ALL_BIN_PATTERNS_EXIST_1_TIME`
- support for Windows environment variables in file paths in the template sections `patch_bin` and `patch_text`
- display of the total number of patterns found

Fixed:
- the problem with the patcher is when all the files specified in the template sections `patch_bin` and `patch_text` are missing
- the problem of incorrect deletion of comments from sections of the template during their processing
- the problem was when offsets were displayed in decimal format and they were displayed in hexadecimal format, in situations where not all hex patterns were found.
- the problem where the hex patterns from the template were not cleaned of unnecessary characters
- the problem was when there was another template variable in the value of the template variable and it was not replaced with its own value when used.
- the problem was when hex patterns were applied to multiple files with the `PATCH_ONLY_ALL_PATTERNS_EXIST` flag
- improved hiding of the output of logging messages in the absence of the `VERBOSE` template flag

Improved:
- renamed the template flag `PATCH_ONLY_ALL_PATTERNS_EXIST` to `PATCH_ONLY_ALL_BIN_PATTERNS_EXIST`
- output of information about not found patterns
- hidden errors when trying to delete non-existent temporary files

### v2.2.2

Fixed:
- hidden error output when trying to delete a non-existent backup file
- assigning values to variables whose values also contain variables in the `variables` section of the template

### v2.2.1

Added:
- removing single and double quotes when clearing hex patterns

Fixed:
- an attempt to remove a digital signature from files that are not on the disk from the section was prevented `patch_bin`

### v2.2

Added:
- added template flags `EXIT_IF_ANY_PATCH_BIN_FILE_NOT_EXIST` and `EXIT_IF_ANY_PATCH_TEXT_FILE_NOT_EXIST`

Fixed:
- in the core script: a backup file is not created if the search patterns were not found
- in the core script: the algorithm for creating a temporary file when searching for patch patterns has been fixed, now the file is created truly unique (with a unique name) and does not overwrite any existing file
- when processing the `patch_bin` section, now the character `?` being replaced `??` only in patterns (when using the `WILDCARD_IS_1_Q_SYMBOL` flag), and not in the text of the entire section
  - it will this prevent damage to paths that contain the `?` symbol

Improved:
- in the core script, `,` and all kinds of indentation are now removed from hex patterns, not just spaces.

### v2.1

Added:
- output information about the initial number of lines in the hosts file, the number of lines added/deleted, and the total number of lines in the updated hosts file
  - when the `hosts_remove` and `hosts_add` sections are working

Fixed:
- working with the "Read-only" attribute for backup files in the "core"
- removed the creation of backup files with the `CHECK_OCCURRENCES_ONLY` or `CHECK_ALREADY_PATCHED_ONLY` flag, because these flags are used only for counting, not for changing files.
- deleted the text in the log stating that the found patterns were replaced when using the `PATCH_ONLY_ALL_PATTERNS_EXIST` flag when not all patterns were found
- information about the found patterns in the `patch_text` section
- comments for the hosts file in the `hosts_remove` and `hosts_add` sections were considered template comments and were deleted before the section was processed.
- the replacement of the entire text `127.0.0.1` with `0.0.0.0` in the hosts file has been removed for any actions in the `hosts_remove` and `hosts_add` sections

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
