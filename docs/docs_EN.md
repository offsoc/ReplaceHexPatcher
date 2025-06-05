# ReplaceHexPatcher - Documentation

Language: [Русский](docs_RU.md) | English

- [ReplaceHexPatcher - Documentation](#replacehexpatcher---documentation)
  - [Preface](#preface)
  - [The basis (Core)](#the-basis-core)
  - [Wrappers](#wrappers)
    - [The "data inside" wrapper script](#the-data-inside-wrapper-script)
    - [The "data in template" wrapper script](#the-data-in-template-wrapper-script)
      - [Template template.txt](#template-templatetxt)
  - [Known limitations](#known-limitations)
  - [Testing](#testing)
  - [Utilities](#utilities)
  - [Answers to possible questions](#answers-to-possible-questions)


## Preface

Initially, my goal was to create a 2-click native Windows solution for finding and replacing bytes, as the `perl` and `sed` utilities can do in macOS and GNU Linux.

That is, to solve the task (search and replace bytes), you need to use only what is available in Windows immediately after installation. No third-party files/programs should be downloaded and used.

3 "programming tools" are preinstalled in Windows - CMD, Visual Basic Script, Powershell.
CMD is too limited in capabilities. In Visual Basic Script, I have not found a way to write effective code to find and replace a byte pattern in a file of any size. But Powershell is, very roughly speaking, a C# code execution environment, and with C# you can do a lot of things, and therefore using Powershell code it is quite possible to search and replace bytes in hex format.

I started looking for ways to do this on Powershell and first found [this one](https://stackoverflow.com/a/57339359) an example, but if I remember correctly, such byte search and replacement worked slowly for me. I couldn't find any other examples, so I turned to ChatGPT and it generated the necessary script for me. I tested and improved it and wrote additional wrapper scripts.

Of course, interpreted code runs slower than compiled utilities for these tasks, but it is possible if such utilities are written in C# ([HexAndReplace](https://github.com/jjxtra/HexAndReplace) or [BinaryFilePatcher](https://github.com/Invertex/BinaryFilePatcher)) if you rewrite it to Powershell, it will improve the code and the speed of its execution (but this is not accurate)

## The basis (Core)

The basis (core) of this tool is the Powershell script [ReplaceHexBytesAll.ps1](../core/ReplaceHexBytesAll.ps1), which is located in the "core" folder. It just performs the function of searching + replacing bytes and displaying a small report on whether all templates have been replaced or some templates have not been found.

It takes 3 arguments:
1. The path to the file in which to search and replace bytes is specified after the `-filePath` argument
2. Hex templates for searching and replacing bytes in the form of an array or 1 string, specified after the `-patterns` argument
3. The `-makeBackup` parameter if you need to create a backup of the original file

More detailed:

1. The path to the file

Everything is obvious with the file path. The path to the target file in which bytes will be searched and replaced. If no byte pattern is found, the file will not be affected in any way.

The path to the file is passed as an argument to run the script `-filePath "D:\path\to\file.exe"`

2. Hex patterns

Templates for searching + replacing bytes in hex format. Patterns for searching and patterns for replacing bytes are written in 1 line and separated by one of the characters `/` or `\` or `|`.

It is only important that the patterns contain hex characters (that is, they consist of the digits `0-9` and the letters `a-f` inclusive and case-insensitive). And wildcard characters `??` (the number of question marks must be a multiple of 2).
The patterns themselves do not have a strict format. There can be any number of spaces and `\x` characters between the values in the pattern - all of them will be deleted (their presence will not cause errors). That is, all these formats are valid - `AABBCC/112233`, `AA BB CC/1 122 3 3 `, `\xAA\xBB \xCC/1122\x33`,`??1FBA0E??????CD21B8014CCD21????/????????????????74C3????????????`

Wildcards `??` can be used in hex patterns and search and replace, but patterns cannot consist only of these characters (this is meaningless).

The wildcard `??` in the search pattern means that any byte can be in its place. For example, the pattern `00AABBCC??/1122334455` means that the sequences `00AABBCC00`, `00AABBCC11` and all up to `00AABBCCFF` will be considered valid and will be replaced with bytes from the replacement pattern. If it is possible to perform a patch without using wildcard characters `??`, then it is better not to use them, because they increase the number of search options, which reduces performance and, accordingly, increases the search time. It probably makes sense to use wildcards at the beginning of the search pattern only if byte substitution needs to be performed at the very beginning of the file with a certain indentation.

The wildcard `??` in the replacement pattern means that the original byte from the file will be used in its place. For example, with the patterns `00AABBCCDDFF/00AAC3CCDDFF` and `00AABBCCDDFF/????C3??????` are identical in this case.

All sets of patterns are passed after specifying the script launch argument `-patterns'.
They can be passed as a comma-separated array of strings `"AABB/1122", "CCDD/4455"`, or as 1 large string `"AABB/1122,CCDD/4455"`. This variation is made primarily because if you run a script from another Powershell script via the `Start-Process`, then the comma-separated strings are not recognized as an array.

3. Backup of the patched file

By passing the `-makeBackup` parameter, the original file (target) will be copied to the same folder where it was located and the text `.bak` will be added to its full name. The "Read-only" attribute of the file will be saved, as well as NTFS permissions and settings.

A backup will be made only if at least one pattern is found in the file.
If the patterns are not found, accordingly, the goal will not be changed in any way and there is no point in a backup.

In general, "under the hood" backup is done initially in a unique temporary file in the same folder before starting byte search. Because when we start reading the file, when we find the right patterns, they will be immediately replaced. There is no way to make a backup only when finding and replacing the first byte pattern, because file access to the file will be blocked during reading. If patterns are found and, accordingly, the target file is changed, then the temporary backup file will be renamed to the "true" backup file (the one with the extension `.bak`) and if such a backup file existed before the modification of the target file, then the existing backup file will be deleted.

To use the script, you must:
1. Start Powershell
2. Use `cd <path>` to go to the folder with the file `ReplaceHexBytesAll.ps1`
3. In the Powershell window, run:
```
.\ReplaceHexBytesAll.ps1 -filePath "D:\TEMP\file.exe" -patterns "48 83EC2 8BA2F 000000 488A/202 0EB1 1111 11111 111111","C42518488D4D68\90909011111175","45A8488D55A8|75EB88909090","\xAA\x7F\xBB\x08\xE3\x4D|\xBB\x90\xB1\xE8\x99\x4D","??1FBA0E??????CD21B8014CCD21????/????????????????74C3????????????" -makeBackup
```

Here are other examples of valid commands:
```
.\ReplaceHexBytesAll.ps1 -filePath "D:\TEMP\test\test.exe" -patterns "AABBCC/112233","44aa55\66bb77","1234|5678","????2600000FB6D8488D4C2440FF1578/EB032600000FB6D8488D4C2440FF1578"
```

```
.\ReplaceHexBytesAll.ps1 -filePath "D:\TEMP\file.exe" -patterns "4883EC28BA2F000000488A/2020EB1 111111111111111,C42518488D4D68/90909011111175,45A8488D55A8/75EB88909090,AA7FBB08E34D/BB90B1E8994D"
```


## Wrappers

The main script only searches and replaces bytes in 1 file. What if you need to do this for multiple files? And also create one or more files with text or block access to the files to the network using a firewall?

All these additional actions (side effects) can be done using additional code that I wrote in separate scripts. These scripts form commands to run the main patcher script with dynamically generated arguments, as well as perform additional actions.

There are 2 types of wrapper scripts:
1. Data inside the script (data inside)
2. Data from the template (data in template)


### The "data inside" wrapper script

This script is written in CMD with a small addition of Powershell code where you can't do without it. In this type of script, everything you need - paths or links to the "core", paths to target files for modifications, all patterns for search and replace, text for hosts and for other files - all this is inside the `Start.cmd` script

Before you run the script, you need to configure it. You need to enter the data that it will work with - add patterns, file paths for modifications, etc. - all this manually by changing existing variables and adding new variables.
I tried to write the script so that adding and changing these variables was a simple action and was done in a minimum number of places in the code (only in the "MAIN" code block).

For convenience, a checklist of what needs to be checked before considering it ready has been added to the script.

1. Target files for the patch
    - If you need to patch several files (target files), then you need to enter the number of files for the patch in the `count_target_files` variable
    - Put the path to each file in the variables `target_path_1` and the last digit of the variable must be a unique sequential index
2. Patches - patterns for searching +byte replacement for target files
    - The number of patterns for searching+byte replacement must be entered in the `count_patches_f1` variable. The last digit in the variable indicates the index of the target file for which patterns must be applied. If there are several target files, then you need to create several such variables by changing the indexes in their name to the indexes corresponding to the target files
    - Create variables `original_f1_1` and `patched_f1_1` in which hex patterns must be stored to search and replace bytes, respectively. For 1 hex pattern, there is 1 variable and if there are several patterns, increase the last index number in the new variables by 1. The text `f1` means the index of the file for which the pattern is intended
    - TODO: perhaps it is better to redo the script so that the search+replacement patterns are not written to different variables, but to 1 variable, for example `"pattern_f1_1=AABBCC/112233"`
3. Creating text files
    - If you do not need to create text files, comment out the line `call :create_all_text_files`
    - If you need to create only 1 text file, then
      - in the variable `file_text_path_1` - put the full path to the text file
      - enter the line ending type (CRLF or LF) in the variable `endline_text_file_1` - enter the "creation mode" of the file - FORCE or NOTOVERWRITE in the variable `create_mode_text_file_1`. In FORCE mode, the file will be overwritten if such a file exists, and in NOTOVERWRITE mode, the file will not be affected/overwritten if it already exists
      - inside the function `:create_text_file_1`, enter the text that needs to be placed in the file
    - If you need to create several text files, then create several of the above variables for each file and increase the index number at the end of the variable
      - And also for each file, create a function `:create_text_file_1` with individual text for the file content (well, increase the index number in the function name too)
4. Adding lines to hosts
    - If you do not need to add anything to the hosts file - comment out the line `call :block_hosts "NOTOVERWRITE" "WRITE HERE NAME OF GROUP FILES ADDED TO HOSTS"`
    - If you need to add some lines to the hosts file, then add the URLs themselves to block inside the function `:block_hosts`, when executing the script function will generate the strings itself and add them to the hosts, if there were no such strings before
      - Also, add the word "FORCE" or "NOTOVERWRITE" as the first argument to the call string of the function `call :block_hosts "NOTOVERWRITE" "WRITE HERE NAME OF GROUP FILES ADDED TO HOSTS"`. "FORCE" means stupidly adding lines to the end of hosts, and "NOTOVERWRITE" means not adding them if exactly the same set of lines with the same group name is at the end of the file
      - Well, instead of "WRITE HERE NAME OF GROUP FILES ADDED TO HOSTS", write the name/title for a group of lines, for example "Adobe servers"
5. Blocking target files using Windows Firewall
    - If the target files do not need to be blocked using a firewall, then comment out the line `call :block_targets_with_firewall`, otherwise leave this line unchanged

It might have been more logical to put some of the functionality in separate script files, but I wanted to make the most "monolithic" 2-click solution. 


### The "data in template" wrapper script

In the second solution, you do not need to go inside the script, all the data for the work is taken from the file `template.txt`. This template parses the corresponding script `Parser.ps1` and, if there is a block with paths + patterns, calls the script `ReplaceHexBytesAll.ps1` with dynamically generated arguments. The script parser also performs additional actions depending on the content of the file `template.txt` - adds or removes lines from `hosts`, adds or deletes files, etc.

The parser accepts 2 arguments - `-templatePath <string>` and `-patcherPath <string>`. With each argument, you must specify the path to the file or URL. It is not necessary to specify the `patcherPath` argument, because the path/URL to the patcher can also be written in `template.txt`, but if the `-patcherPath` argument is passed, then it will be the first in the queue to check the paths to the patcher (relative to the paths from template).

Here is an example of running the parser from Powershell:
```
.\Parser.ps1 -templatePath "C\Users\Public\template.txt" -patcherPath "C:\Users\Public\ReplaceHexBytesAll.ps1"
```

In the same folder there is `Start.cmd` - this is a wrapper over `Parser.ps1` so that the parser can be launched by double-clicking, rather than opening Powershell first and going to the folder with the parser.
In this wrapper script, you can specify in advance the full path (or URL) to the parser and to `template.txt` and to the patcher in the corresponding variables `parser_path`, `template_path`, `patcher_path` and then the parser will start with these arguments.

If the path (or URL) is not specified, then the parser (file named `Parser.ps1`) will be searched first in the current folder, if it is not there, then the parser will be downloaded via a direct link from the current repository and the path to the downloaded file will be the path to the parser.
Then the same search procedure will be applied to the file `template.txt`. And the path (or URL) to the patcher must be specified manually, otherwise it will not be passed (and the paths from the template file will be used).

Initially, all the code was written in 1 file `Parser.ps1`, it contained more than 1,500 lines and was not a template parser, but a multi-tool that, after parsing the template, "pulls the strings" of other functions, depending on the sections in the template. A file with a code of 1500 lines is not convenient to maintain and not all functions may be needed, it all depends on the template. Therefore, I have moved all the basic functionality that "pulls the strings" into separate Powershell files and they are imported or downloaded as needed through dot sourcing. These files are like libraries that connect to the main file. I have slightly prepared them for possible independent use, but in order to use them independently, they need to be finalized, but this is not necessary within the framework of this project.

The `Parser.ps1` file has remained a multi-tool, but now it contains less code, which has improved readability.
I left a version of this file where all the code is inside, but it's not worth using it. Its revision / adaptation / synchronization compared to the version divided into parts will be done "on a whim".

#### Template template.txt

Now about the template. The template structure was made so that the data could be easily filled in manually with the usual Ctrl+C and Ctrl+V, so the data templates are in the format `.json` and `.xml` are not suitable because it is easy to make mistakes and break the structure when filling them out.

**Template structure:**

1. Sections (blocks with rows/data)
   1. The template can contain different data and each data type must be located in its own section. The sections are separated by lines that contain the following text
   - `[start-SECTION NAME]` - the line is the beginning of the section
          - `[end-SECTION NAME]` - string end of section
          - everything between these lines (that is, inside the section) is the data of the section and will be analyzed by the parser depending on the name of the section
          - everything that is not inside any section will not be analyzed in any way, in fact, it can be considered comments on the template and sections, and you can write anything inside the sections
          - sections can be arranged in any sequence, this will not affect the order of their analysis. The order is set in the MAIN area in the parser
   1. There are such sections, more details about each will be further
       - `variables`
       - `pre_powershell_code`
       - `pre_cmd_code`
       - `patch_bin`
       - `patch_text`
       - `file_create_from_text`
       - `file_create_from_base64`
       - `hosts_add`
       - `hosts_remove`
       - `files_or_folders_delete`
       - `firewall_block`
       - `firewall_remove_block`
       - `registry_file`
       - `post_powershell_code`
       - `post_cmd_code`
2. Comments
   - Everything that is not inside any section will not be analyzed in any way, in fact, we can consider it comments on the template and sections, and you can write anything inside the sections
      - There may also be comments inside the sections. All lines containing this text `;;` are considered comments and will be deleted before further analysis
3. Global variables
    - The text `$USER` will be replaced with the name of the current Windows user everywhere in the template


**The sequence of actions in the parser**
1. Search and replace all global variables in the template
2. Checking for sections `hosts_remove`, `hosts_add`, `firewall_block`, `firewall_remove_block`, `registry_file`. If there are such sections and the parser is not running on behalf of the Administrator, we restart the parser with the arguments received on behalf of the Administrator, because when using data from these sections, 100% admin rights will be needed and in order not to request these rights in separate processes when processing data from each section, it is more convenient to restart the script with the necessary rights from the very beginning.
3. Search for sections and extract data from them in this order
    1. `variables`
    2. `pre_powershell_code`
    3. `pre_cmd_code`
    5. `patch_bin`
    6. `patch_text`
    7. `hosts_remove`
    8. `hosts_add`
    9. `files_or_folders_delete`
    10. `file_create_from_text`
    11. `file_create_from_base64`
    12. `firewall_remove_block`
    13. `firewall_block`
    14. `registry_file`
    15. `post_powershell_code`
    16. `post_cmd_code`
4. The first found section of each type will be used if one type (for example, `hosts_add`) has several sections in the template - all subsequent sections of this type, except the first one from above, will not be used.
    - The exception is the sections `file_create_from_text` and `file_create_from_base64`, because if you need to create multiple files, you need to place several such sections
5. When using data extracted from each section, the data is first "cleaned" - `Trim()` software for the block with the entire text of the section, and then search and replace variables from the `variables` section
    - The exception are the sections `file_create_from_text` and `file_create_from_base64` - for them, not `Trim()` is performed, but `TrimStart()`, that is, the removal of "voids" at the beginning of the text. This is done so that if the created text should have empty lines at the end, so that they are not deleted from the content of the section
    - All line endings of the text extracted from the template are reduced to the type `LF`, that is, `\n` for ease of processing. This does not affect the type of line endings in the files being created, because this value can be set manually in the appropriate sections 
6. Further, depending on the type of data section, they are used accordingly (for more information about this, see the information about each section)
7. If the script does not have Administrator rights, but Administrator rights are required to perform actions, a Powershell command will be formed and run in a separate process requesting admin rights
    - The exception is the sections `firewall_remove_block` and `firewall_block` - if there are no administrator rights, they will give errors
8. In each section, data is read and processed line by line
9. After the parser is running, all temporary files are deleted, the duration of the parser is displayed and the line `Press any key to continue...` is displayed, then pressing any key it closes.

**Sections (blocks with rows/data)**

1. `variables`

Here you can set variables if some piece of text (for example, a pattern or a file path) needs to be used several times further in the template. Each new variable is written from a new line, first the name of the variable, then the `=` sign, then the data associated with the variable.

Example
`path_to_prog = C:\Users\Public\some folder again\program.exe`

Then the string is divided into 2 parts by the sign `=` and `Trim()` of both parts is performed, and then in each section the variable name will be searched and replaced with its value. Therefore, specify a unique name for the entire text in the template.

1. `pre_powershell_code`

A block with Powershell code that is executed before applying hex patterns.

Here you specify the code that will be placed in a separate `.ps1` file and will be launched. The function processing this section has the parameters `-hideExternalOutput` and `-needRunAS`. By adding the `-hideExternalOutput` parameter, the entire standard output stream will be redirected to `$null` (this is done if the nested script has a lot of text to output to the terminal window and you need to hide this text), and the `-needRunAS` parameter runs this script with a request for Administrator rights. If the script is not restarted with admin rights in a separate process, the results of its work will be displayed in the current Powershell window.

The text from this section is also analyzed and variables are replaced with their values from the variables section.

If an error or exception occurs when executing this code, processing of other sections of the template will be stopped.

4. `pre_cmd_code`

A block with CMD code that is executed before applying hex patterns.

Here you specify the code that will be placed in a separate `.cmd` file and will be launched. The function processing this section has the parameters `-hideExternalOutput` and `-needRunAS` and `-needNewWindow`.  By adding the `-hideExternalOutput` parameter, the entire standard output stream will be redirected to `$null` (this is done if the nested script has a lot of text to output to the terminal window and you need to hide this text), and the `-needRunAS` parameter runs this script with a request for Administrator rights, and the `-needNewWindow` parameter runs the script is in a new window.

At the same time, if there is a `-needRunAS` parameter and the current parser script does not have admin rights, then the created `.cmd` script will in any case be launched in a new window to request Administrator rights.

The text from this section is also analyzed and variables are replaced with their values from the variables section.

If an error occurs when executing this code, processing of other sections of the template will be stopped.

5. `patch_bin`

Here are the file paths and patterns for searching + replacing files. First comes the string - the absolute path to the file. The following lines are patterns for searching+replacing bytes. The pattern strings can be either a separate string with bytes to search and a separate string to replace, or the string can contain both patterns, but they must be separated by the same separator that is used when passing patterns as arguments to `ReplaceHexBytesAll.ps1`.
In general, the file path string is searched first, and all the following lines are analyzed as hex patterns until the next file path string is found.

Well, don't forget that all this data (file paths and patterns) can be stored in variables and only variables can be written here.

There is a "flag" (indicator/switch) for this section - the phrase `MAKE BACKUP`. If this phrase is located in one of the following lines after the line with the path to the target file, then when executing `ReplaceHexBytesAll.ps1`, the `-makeBackup` flag will also be passed, which leads to the creation of a backup with the original file in the same folder. For more information about this flag, see the information about the main patch script.

6. `patch_text`

Here are the file paths and patterns for searching + replacing text in files. First comes the line - the absolute path to the file. The following lines are search+replace patterns. Each line in this section should contain one thing - either a path or a pattern/string/search text or a string to replace.
It supports both regular expression and exact string matching, as well as case-sensitive and case-independent search for both variants.

Well, don't forget that all this data (file paths and patterns) can be stored in variables and only variables can be written here.

7. `hosts_remove`

This specifies the strings or URLs that should be deleted from the `hosts` file. If the section line starts with the comment character `#` or with `127.0.0.1` or with `0.0.0.0`, then the exact same line will be searched, without taking into account the length of the spaces. Otherwise, it is assumed that the URL is specified (for example adobe.io), and lines containing such an address (such a word, that is, text and text borders will be spaces or line breaks) will be deleted.

At the same time, you can specify the asterisk symbol `*` and this will mean the regular expression `.*` (up to the word boundaries). That is, you can write a line with `*adobe*` in the section and this will lead to the deletion of all lines containing the word `adobe` with any characters, but if there is a line `adobe` without stars in the section, then lines that contain exactly this word without any additional characters will be deleted. Alternatively, you can also specify `*adobe.io `and this will remove all rows with sub-domains `adobe.io `

8. `hosts_add`

Here you can specify the lines that need to be added to the `hosts` file. Usually lines are added to block access to some URLs, so in this section you can simply write URLs (of course, each on a new line) and the string `0.0.0.0 <URL>` will be added to `hosts` and this will block access to the URL.

If the line in the section starts with `127.0.0.1` or with the comment character `#`, then it will be added to hosts without changes. Otherwise, the string is considered an immediate URL (for example adobe.com) and `0.0.0.0` will be added to the beginning of it, which will block the URL.

The function for working with this section works correctly - if the `hosts` file does not exist, then it will be created. If there is a "Read-only" attribute, it will be removed before changing the file, and then the attribute will be set again. If the script does not have Administrator rights to change the file, a separate command will be formed with text to add to the `hosts` and it will run in a separate Powershell process requesting admin rights.

There is a "flag" (indicator/switch) for this section - the phrase `NOT MODIFY IT`. If this phrase is at the very beginning of the section, all lines will be added to the `hosts` without changes. Only `Trim()` will be applied to strings.

6. `files_or_folders_delete`

Here you can specify the absolute paths to the files and folders that you want to delete.

The function for working with this section works correctly - if the file has a "Read-only" attribute, then it will be removed before deletion so that there are no errors. If you need administrator rights to delete some files or folders, they will all be formed into a separate internal list and a separate Powershell process will be launched with a request for administrator rights that will delete all these files and folders.

There is a "flag" (indicator/switch) for this section - the phrase `MOVE TO BIN'. If this phrase is at the very beginning of the section, all files and folders will be moved to the Trash, and not deleted from the system.

7. `file_create_from_text`

Here you specify the data for creating a text file. The first line of the section is the path to the file that needs to be created and filled with data. The second line can be either a "flag" (see here below) or already the beginning of the text that needs to be placed in the created file. If such a file already exists, it will be deleted first. Next are the lines with the text that will be placed in the created file. Empty lines will not be deleted.

There is a "flag" (indicator/switch) for this section - the phrase `CRLF` or `LF`. If this phrase is in the second line of the section, it will determine the type of line endings in the created text file. If this "flag" is not present, the line ending type will be the same as that used when working with text inside the script, that is, `LF'.

8. `file_create_from_base64`

Here you can specify the data for creating a file based on the decrypted base64 code. The first line of the section is the path to the file that needs to be created and filled with data. If the file specified in the path already exists, it will be deleted first. The second and subsequent lines are a single block of base64 code, and this code will be decrypted and its contents placed in a file (more precisely, the file will consist of the contents of the decrypted base64 code).

9. `firewall_remove_block`

Absolute file paths are specified here (obviously these should be `.exe` files) which must be removed from the Windows Firewall. It is assumed that this will be done to unlock Internet access for programs for which Internet access was previously blocked.All firewall rules for the specified paths will be deleted, although it may be worth adding some parameters so that only rules blocking Internet access are deleted.

If you need to apply the removal of rules to all `.exe` files in a folder and all subfolders, you can specify the path to this folder and at the end the path should end with the text `\*`. If you need to do the same thing, but without subfolders, but only for 1 specified folder, then the path should end with `\*.exe`.

To change the Windows Firewall settings, you definitely need administrator rights, and if for some reason the script does not have these rights when this function is running, there will be an error.

10. `firewall_block`

Absolute file paths are specified here (obviously these should be `.exe` files) who need to block access to the network using Windows Firewall.

If you need to block access to all `.exe` files in a folder and all subfolders, you can specify the path to this folder and at the end the path should end with the text `\*`. If you need to do the same thing, but without subfolders, but only for 1 specified folder, then the path should end with `\*.exe`.

To change the Windows Firewall settings, you definitely need administrator rights, and if for some reason the script does not have these rights when this function is running, there will be an error.

11. `registry_file`

Here you can specify the data for modifying the Windows Registry. Absolutely the same lines that are written in the `.reg` files can (should) be written here.

You don't need to write the "title" in the form of the first line `Windows Registry Editor Version 5.00`, it will be added dynamically if it is not at the beginning of the section.

If the script is run without Administrator rights, a `.reg` file will be created in the temporary folder in which this data will be written. Then a separate Powershell process will be launched with a request for administrator rights and in this process the command to import data from this file into the Windows registry will be executed.

12. `post_powershell_code`

A block with Powershell code that is executed after applying hex patterns.

The rest of the information is the same as in the `pre_powershell_code` section.

13. `post_cmd_code`

A block with a CMD code that is executed after applying hex patterns.

The rest of the information is the same as in the `pre_cmd_code` section.


## Known limitations

1. In the `patch_text` section, you cannot specify as a string/text/search pattern what can be recognized as an existing path in the `Test-Path` commandlet
   - Even strings like `/Users` or `\/Users`, for more information, see the documentation on (Test-Path)[https://learn.microsoft.com/powershell/module/microsoft.powershell.management/test-path]


## Testing

About this in the [additional file](../tests/testing_EN.md )


## Utilities

The folder [utilities](../utilities/) contains script files created based on functions from the main utility scripts.

The `.cmd` files in this folder contain functions (or to put it another way, they are made based on functions) from the file [Start.cmd](../wrappers/data%20inside/Start.cmd). Cmd scripts such as:
- [Add URLs To Hosts](../utilities/AddURLsToHosts.cmd)
- [Block With Firewall](../utilities/BlockWithFirewall.cmd)

I think the file names clearly say what these scripts do. The text/strings/data that the scripts work with are inside the scripts themselves, so to add/change URLs to add to hosts, you need to change 1 variable in the script [AddURLsToHosts.cmd](../utilities/AddURLsToHosts.cmd) by adding a list of addresses to it.

To change or add paths to files that need to be blocked using Windows Firewall, you need to add/change the variables `target_path_1` in the script [BlockWithFirewall](../utilities/BlockWithFirewall.cmd) by changing the counter-digit at the end of the variable, and then in the variable `count_target_files` change the digit that indicates the total number of these variables.
Each such variable can store either the absolute path to the exe file, or the path to the folder in which all exe files need to be blocked. The path to the folder must end with `\*.exe`, for example `D:\TEMP\test\sub folder\*.exe` and then all exe files will be blocked only in this folder. If you need to recursively lock exe files in all subfolders, then you need to set the value "TRUE" for the variable `USE_SUBFOLDERS` below in the code.

The `.ps1` files in this folder contain functions (or to put it another way, they are made based on functions) from the [Parser.ps1] file(../wrappers/data%20in%20template/Parser.ps1). Such Powershell scripts have been created as:
- [Add URLs To Hosts](../utilities/AddURLsToHosts.ps1)
- [Remove URLs From Hosts](../utilities/RemoveURLsFromHosts.ps1)
- [Block With Firewall](../utilities/BlockWithFirewall.ps1)
- [Remove Rules From Firewall](../utilities/RemoveRulesFromFirewall.ps1)

I think the file names clearly say what these scripts do. The text/strings/data that the scripts work with are located inside the scripts themselves, at the very top of the files. The data type is exactly the same as in the file `template.txt`, it's just that this data will need to be manually written in the scripts themselves.


## Answers to possible questions

1. Why is there so much code?
    - I don't have much experience in writing code. And this is the first time I'm writing code for Powershell and CMD
    - I tried to make the project monolithic so that only a couple of files could be transferred to the computer on which modifications need to be performed, including the template and just run the "executable file" with a double click
    - I tried to add various checks (for example, for the existence of a file path or something) wherever I thought it was necessary, and this is a lot of places. Probably, these checks are not needed everywhere. Especially if you think over the architecture of the project and bring it back to normal.
    - I had a desire (although, most likely, this is a personal sporting interest) to make the script possible to run and execute without administrator rights and these rights were requested only when they are needed. Because of this, we had to add and process checks to see if administrator rights were needed for this operation and run separate Powershell code (including multi-line) in separate processes requesting administrator rights. If you remove all these checks and check for rights only at the very beginning, the code will probably lose 1/5 of its weight.
2. Why is the template not in JSON or XML format?
    - Because these types of file structures have a fairly strict markup format and when filling out a file manually, it would be difficult to write and format text in a JSON or XML structure. I made the template structure such that it forgives errors and is less strict, unlike JSON and XML.
3. Is it possible to use byte search and replace to delete a sequence of bytes?
    - Yes, but it requires a little modification of the code. It in TODO-list in Readme.
    - This project (a byte search and replace patcher) is aimed mainly at patching binary files. In my practice (in my tasks), only byte substitution is used. Deleting bytes from a binary file, in most cases, leads to the file becoming broken (broken, non-working), at least in executable files and library files. Deleting bytes in binary files probably makes sense only if you need to delete some meta information, such as a digital signature, which is usually located at the end of exe files.
4. How can I help the project?
    - Do what is written in TODO (without compromising the functionality and performance of the code)
    - Refactor and improve the performance of the code/ utility
    - Or find someone who will do it
5. Why are there no `Replace()` functions? What do the `OverWrite()` functions do?
    - Because the concept and approach to file modification have changed.
    - The very word "replace" and the procedure for replacing the byte sequence means that when using the pattern `11223344/AABB3344`, we will search for the sequences `11223344` and completely replace these sequences with another sequence - `AABB3344`. What if we need to replace the sequence `11223344` with `AA`?
    - The `Replace()` functions implemented in the project at the time of writing this text cannot do this (because it will be necessary to split the file into parts and "stitch" it at the break points so that the file length changes. I have never seen the need for such replacements in executable files, because changing the size of the executable file causes it to malfunction). The `Replace()` functions can only change sequences of the same length. That is, the byte sequence replacement function cannot actually perform any sequence replacement.
    - In fact, such `Replace()` functions find sections that match the search patterns and in these sections, starting from the first byte, insert bytes from the replacement pattern with byte overwriting (that is, not inserting bytes between others, but with overwriting). This is not a byte swap.
    - Therefore, it is semantically correct to call such functions as "search for addresses of search patterns with insertion of replacement patterns with overwriting." Simply put - `OverwriteBytesAtPatternPositions()`
    - Why then does the word "Replace" appear in the name of the project and it is often said about replacing bytes rather than inserting and overwriting them into the found positions? Because the phrase "byte search and replacement", in my opinion, is a historically well-established expression and most hex patch tools do exactly byte search and replacement (for example, `perl` or `sed`) and in most cases they do this only if the search and replacement patterns are the same length.
