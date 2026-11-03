#!/usr/bin/env bash
# Assemble a bootable 720 KiB MS-DOS 4.00 floppy image from build/bin.
#   1. create blank FAT image          (mkfs.fat)
#   2. write the built MS-DOS 4.00 boot sector with a 720K BPB
#   3. copy IO.SYS/MSDOS.SYS as the FIRST
#      TWO root directory entries - the MSBOOT.ASM loader (built with
#      IBMCOPYRIGHT=FALSE) searches for exactly those names in that order
#   4. add COMMAND.COM in the root and the rest under \DOS
set -e
cd "$(dirname "$0")"
BIN=bin
IMG=build/msdos400.img

[ -f $BIN/io.sys ]    || { echo "No $BIN/io.sys - run ./build-msdos.sh first"; exit 1; }
[ -f $BIN/msdos.sys ] || { echo "No $BIN/msdos.sys"; exit 1; }
[ -f $BIN/msboot.bin ]|| { echo "No $BIN/msboot.bin"; exit 1; }

echo ">>> Creating blank 720 KiB FAT image..."
rm -f $IMG
mkfs.fat -C -F 12 -S 512 -M 0xF9 $IMG 720 >/dev/null

echo ">>> Writing built MS-DOS 4.00 boot sector (BPB patched to 720K)..."
python3 patch_bpb.py $BIN/msboot.bin $IMG

echo ">>> Copying system files (IO.SYS/MSDOS.SYS must be first two entries)..."
mcopy -i $IMG "$BIN/io.sys"     ::IO.SYS
mcopy -i $IMG "$BIN/msdos.sys"  ::MSDOS.SYS
mcopy -i $IMG "$BIN/command.com"      ::COMMAND.COM

mkdir -p /tmp/opencode/dos400
for f in $BIN/*.exe $BIN/*.com $BIN/*.sys; do [ -f "$f" ] && cp -f "$f" /tmp/opencode/dos400/; done

echo ">>> Copying utilities and drivers to \\DOS..."
mmd -i $IMG ::DOS
mcopy -i $IMG /tmp/opencode/dos400/ansi.sys      ::DOS/
mcopy -i $IMG /tmp/opencode/dos400/display.sys   ::DOS/
mcopy -i $IMG /tmp/opencode/dos400/keyboard.sys  ::DOS/
mcopy -i $IMG /tmp/opencode/dos400/printer.sys   ::DOS/
mcopy -i $IMG /tmp/opencode/dos400/ramdrive.sys  ::DOS/
mcopy -i $IMG /tmp/opencode/dos400/smartdrv.sys  ::DOS/
for f in /tmp/opencode/dos400/*.com /tmp/opencode/dos400/*.exe; do
  base=$(basename "$f")
  case "$base" in command.com) continue;; esac
  mcopy -i $IMG "$f" ::DOS/
done

echo ">>> Floppy image: $IMG"
mdir -i $IMG | head -40