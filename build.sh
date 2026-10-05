#!/bin/bash
# Build the watch app or watch face. Usage: ./build.sh <app|face> [device] [release]
#   ./build.sh face                       debug face for fenix847mm (DEMO data with no phone)
#   ./build.sh face fenix847mm release    release face to sideload
#   ./build.sh app fenix843mm release     release app for the 43 mm watch
#   ./build.sh screenshots                simulator build with fake Trio replies, for README images
#   ./build.sh test                       run the app's (:test) functions in the simulator
set -euo pipefail
cd "$(dirname "$0")"
TARGET="${1:?usage: ./build.sh <app|face|test> [device] [release]}"
DEVICE="${2:-fenix847mm}"
SDK_ROOT="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
SDK="${SDK:-$(ls -1dt "$SDK_ROOT"/connectiq-sdk-mac-* | head -1)}"
KEY="${DEVELOPER_KEY:-$HOME/.garmin/developer_key}"
if [[ "$TARGET" == "screenshots" ]]; then
  # Fake Trio replies for README screenshots. Simulator only, never sideload.
  mkdir -p bin/simulator-only
  "$SDK/bin/monkeyc" -f app/screenshots.jungle -d "$DEVICE" -y "$KEY" -o bin/simulator-only/SIMULATOR-DO-NOT-INSTALL.prg
  echo "Built bin/simulator-only/SIMULATOR-DO-NOT-INSTALL.prg (simulator only)"
  exit 0
fi
if [[ "$TARGET" == "test" ]]; then
  mkdir -p bin
  "$SDK/bin/monkeyc" -f app/monkey.jungle -d "$DEVICE" -y "$KEY" -o bin/test.prg --unit-test
  pgrep -qf ConnectIQ.app || { open "$SDK/bin/ConnectIQ.app"; sleep 5; }
  exec "$SDK/bin/monkeydo" bin/test.prg "$DEVICE" -t
fi
NAME="TrioCompanion"; [[ "$TARGET" == "face" ]] && NAME="TrioCompanionFace"
mkdir -p bin
EXTRA=()
[[ "${3:-}" == "release" ]] && EXTRA=(-r)
"$SDK/bin/monkeyc" -f "$TARGET/monkey.jungle" -d "$DEVICE" -y "$KEY" -o "bin/$NAME-$DEVICE.prg" ${EXTRA[@]+"${EXTRA[@]}"}
echo "Built bin/$NAME-$DEVICE.prg"
