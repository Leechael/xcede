# xcede: Build, run and debug Xcode projects outside Xcode

Tools to enable development of iOS and Mac apps in the [Zed editor](https://zed.dev/). In fact it doesn't
contain anything Zed-specific and might well be useful in other editors.

There are two parts to this:

- a script to let you build and run iOS and macOS apps with a single shell command
- a wrapper for lldb-dap that enables convenient and intuitive debugging of Apple platform apps in editors other than Xcode

For now, this article serves as documentation:
https://luxmentis.org/blog/ios-and-mac-apps-in-zed/

## Status

This is fairly new and unlikely to be rock-solid, and it's not intended to be a massive engineering effort
because surely it will be superceded by a more official effort in time. (Surely.) Consequently you won't find it in brew.

Do try it out though, and raise issues for any feedback.

## Installation

Download the release, put the directory somewhere and make sure it's in your $PATH.

If you prefer to build it yourself, just `swift build -c release --arch arm64 --arch x86_64`
then copy the `xcede-dap` executable into the bin directory (it needs to be in the same location as the scripts).
