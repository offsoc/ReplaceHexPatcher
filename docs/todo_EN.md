# List of tasks

## ToDo

- [ ] Make support for limiting substitutions of found patterns (if you need to replace not all found sequences)
- [ ] Make byte deletion support
- [x] Make support wildcards `??` in patterns as in [AutoIt](https://www.autoitscript.com/autoit3/docs/functions/StringRegExp.htm)
- [ ] Make regular expression support in hex templates like in `sed` or `perl`
  - Maybe [this one](https://stackoverflow.com/a/55314611) an example will help
- [ ] Make a search function starting from a certain offset in the file or starting from a certain part of the file in %
- [ ] To read patterns from a file in the patcher-script itself
- [ ] Make a check for the rights to change/overwrite the file immediately after the first pattern found, and not after going through all the patterns in the main script
- [ ] Make a check for the necessary permissions immediately after the first pattern found, and not after going through all the patterns in the main script
- [ ] Add support [globbing](https://stackoverflow.com/questions/30229465/what-is-file-globbing) in the lines with the paths to the files/folders to be found in the template file
- [ ] Add support for working with relative paths
   - This means the file paths in the template
- [ ] In the section for deleting files and folders, add support for deleting only all attached data or attached files according to some pattern (for example `\*exe`), although this is probably globbing
- [ ] It may be worth adding logic for running `.ps1` files as an administrator in the parser script
   - This means files created from the code in the template
- [ ] Find a normal way to check if you need administrator rights to delete a folder
  - The current method checks this by creating and deleting an empty file in the required folder (this is wrong from the point of view of logic and performance, but in most situations it works as it should)
- [ ] Stylize progress bars
  - When searching for Firewall rules with the specified paths to the exe, a progress bar appears showing the progress of the process. It appears at the top of the terminal simply with the name of the `Get-NetFirewallRule` method
- [ ] Add some way to set the execution order for sections in the template
  - There may be situations when custom Powershell code or CMD code from the template needs to be executed first, for example, to do something with services (delete or restart or something else)
- [ ] Add the ability to set attributes for created files
  - For example, if the created file needs to be made invisible or system-wide
- [ ] Add a way to unlock target files if they are blocked by another `FileStream.Read()` or are being used somewhere
