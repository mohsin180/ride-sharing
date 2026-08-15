#!/usr/bin/env bash
# run-emulator.sh — start the Android emulator so its window actually paints
# on this Mac, then (optionally) run the app on it.
#
#   ./run-emulator.sh          # just boot the emulator
#   ./run-emulator.sh --run    # boot it, then `flutter run` on it
#
# Two settings matter, both learned the hard way:
#
#   -gpu guest    THE fix for the black emulator window. It resolves to
#                 SwANGLE (ANGLE over SwiftShader) and is the only mode of the
#                 four that paints: `swiftshader_indirect`, host GL and `auto`
#                 all gave a solid black window, and `angle_indirect` isn't
#                 even valid in emulator 36.6.11.
#
#                 The symptom is easy to misread: the guest renders perfectly
#                 the whole time — `adb exec-out screencap -p > s.png` shows
#                 the app — while macOS never paints the window, and nothing
#                 is logged anywhere. `-no-hidpi-scaling` also makes the
#                 window paint, but at 1:1 physical pixels, so it comes out
#                 half-size on a Retina display and no flag brings it back
#                 (`-scale` prints "obsolete and will be ignored", and
#                 dragging the corner doesn't help). `-gpu guest` keeps HiDPI
#                 scaling on, so the window is both visible AND full size —
#                 use this, not the scaling flag.
#
#   --no-enable-impeller
#                 Belt-and-braces on top of the same flag in
#                 AndroidManifest.xml. Flutter's Impeller renderer used to
#                 crash the whole emulator: qemu died with SIGILL inside
#                 libgfxstream_backend at glInvalidateFramebuffer, a call its
#                 GL translation layer can't handle. That is a DIFFERENT
#                 failure from the black window — there the emulator vanishes
#                 and you get "Lost connection to device".
#
# AVD stays at its stock 1080x2400 @ 420dpi. Lowering it to make the window
# bigger backfires: guest pixels map to physical pixels, so fewer pixels means
# a smaller window, not a larger one.

set -e
AVD="${AVD:-Medium_Phone}"
EMULATOR="$HOME/Library/Android/sdk/emulator/emulator"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"

if "$ADB" devices | grep -q "^emulator-"; then
  echo "Emulator already running — skipping launch."
else
  echo "Booting $AVD ..."
  # -crash-report-mode disabled: after any emulator crash, the next launch
  # otherwise stops at a "send this crash report?" consent dialog and never
  # boots — it just sits there logging "Showing crashdialog to get consent"
  # while adb reports no devices, which reads exactly like a hung emulator.
  "$EMULATOR" -avd "$AVD" \
      -gpu guest \
      -crash-report-mode disabled \
      -no-snapshot-load \
      -no-boot-anim &
  "$ADB" wait-for-device
  until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
  done
  echo "Emulator ready."
fi

if [ "$1" = "--run" ]; then
  cd "$(dirname "$0")"
  exec flutter run -d emulator-5554 --no-enable-impeller
fi
