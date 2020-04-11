# dropfromshell

A script, written in Swift, to up- and download files from Dropbox.

# Purpose

The code is meant for those interactions with Dropbox, you'd normally do with a
shell script. It's not meant for usage in a full-fledged macOS or iOS app.
There are probably better solutions for that. This code is explicitly
structured to be super-simple, and very easy to understand and hack yourself.

# Usage

To use it, first create an OAuth token on the Dropbox site, see here:
https://www.dropbox.com/developers/reference/oauth-guide

To use this token, there are two options:
* At the top of the `dropfromshell.swift` file, put it in `var oauthAccessToken`
* Or create a JSON file in `~/.config/dropfromshell/dropfromshell.json` with
  the
  following content:

```
{
    "oauthAccessToken" : "your_token_here_ABCDEFG34567890POIUf"
}
```

Then, copy the `dropfromshell.swift` file anywhere you want to start scripting,
make it executable (i.e. `chmod 755 dropfromshell.swift`) and start coding at
the bottom of the file.

Note, it would be much cleaner if you could start an empty file, and just
include `dropfromshell.swift` but that's not a feature that Swift supports
right now.

# Inspiration

My inspiration was the great Dropbox Uploader script. Arguably, it might be a
better solution if you're fluent in Bash.
https://github.com/andreafabrizi/Dropbox-Uploader

