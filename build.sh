#!/bin/bash
set -ex
dest=xcede
swift build -c release --arch arm64 --arch x86_64
if [[ -e $dest ]]; then
    rm -rf "$dest"
fi
cp -r bin "$dest"
cp .build/apple/Products/Release/xcede-dap "$dest"

set +x
echo
echo "Now move the '$dest' directory to your location of choice and add it to your \$PATH 🗿"


