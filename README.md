# CC Link

An extension used to sync vscode with computercraft/cc-tweaked

## Installation

### Server

To install the server, you can use the Dockerfile provided at the root of the [repository](https://github.com/Kensaa/cc-link) \
Environment Variables:

-   Port : The port the server serves on
-   URL : The URL used to access this server (should contain the port if needed)
-   DATABASE_FILE : The path to the database file (should start with `file:`)

### Extension

Download the vsix file from the [release](https://github.com/Kensaa/cc-link/releases/latest)
Go into VSCode Extensions tab and press the 3 dots labeled `Views and more actions` at the top and click `Install from VSIX` then provide the vsix file you downloaded.

Next, You need to provide the server you'll be using to the extension.
To do that, you can either :

-   go into the settings of VSCode and set the `cclink.serverURL` field
-   use the `CC Link: Change server` command

## How does it works

### In VSCode

When you want to upload a file, click the `Upload to CC Link` in the bottom left or use the `CC Link: Upload file` command.
If it's the first upload, a line will be added to the top of your file that will be used by the extension to know that this file was already uploaded once,
in the line you'll find the id of the file that will be used on the Minecraft side.\
note: you shouldn't touch this line, if you change the id, the file will no longer be updated on the computers in Minecraft

### In Minecraft

to install the client you can use the following command :\
`wget run [server_url]` \
You will be prompted multiple things :

-   The IDs of the file you want to sync. This is the number in the header of the file you uploaded
-   The root directory. This is the folder you want the file to be downloaded in on the computer
-   The entrypoint. This is the file that will be launched after all the files have been downloaded. By default, it launches `startup` if the file exists or launches the first lua file found

This config can be modified in cc-link.conf
