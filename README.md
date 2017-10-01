# clientupdate
This is a package that installs the most common/important software in a clean installation of Ubuntu or debian.
It's my own software selection, but it has several bash scripts to do interesting things, check them in the /usr/local/bin or /usr/src paths.

Build
-----
Enter the path with the architecture that you want (amd64/i386) and run the script build.sh, this will generate a debian package in the same directory.

Notes
-----
This package selfupdates from a custom server, without using a debian repository nor validating the package integrity.
Take it into account if you plan to use it.
