#!/usr/bin/env bash
# Runs the test suite. With only Command Line Tools (no Xcode), swift-testing lives
# outside the default search paths, so point the compiler and linker at it.
set -euo pipefail
cd "$(dirname "$0")/.."
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools && -d "$F/Testing.framework" ]]; then
  exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
fi
exec swift test "$@"
