# xcede: Build, run and debug Xcode projects outside Xcode

Tools to enable development of iOS and Mac apps in the [Zed editor](https://zed.dev/). In fact it doesn't
contain anything Zed-specific and might well be useful in other editors.

There are two parts to this:

- a script to let you build and run iOS and macOS apps with a single shell command
- a wrapper for lldb-dap that makes debugging on devices and simulators work like you think it should

For now, this article serves as documentation:
https://luxmentis.org/blog/ios-and-mac-apps-in-zed/

## Status

"Works for me." I've been using it, and damn it's nice to do the bulk of coding outside Xcode.

Also: it's fairly new, relatively quick-and-dirty, and unlikely to be rock-solid. It's not intended to be a
massive engineering effort because surely it will be superseded by some more official effort in time.
(Surely.)

Consequently, you won't find it in brew.

Do try it out, and raise issues for any feedback.

## Installation

- download the latest release (or clone the repo)
- run `build.sh`
- put the `xcede` directory in your location of choice
- add the directory to your $PATH.
