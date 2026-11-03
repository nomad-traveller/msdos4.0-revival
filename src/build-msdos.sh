#!/usr/bin/env bash
# Build the MS-DOS 4.00 source tree with the shipped 16-bit toolchain,
# run inside DOSBox-X. Output binaries are collected into build/bin.
set -e
cd "$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd .. && pwd)/src"

mkdir -p bin log
mkdir -p "$SRC/build/log"   # dosall.bat redirects to c:\src\build\log\ - must exist

echo ">>> Running DOSBox-X build (this takes a few minutes)..."
# build/dosbox-x.conf's mount line hardcodes the host path of this tree.
# Regenerate the conf with the actual tree root so the pipeline is portable
# to another machine (same result when the tree sits at its original place).
TOP="$(cd .. && pwd)"
sed "s#^mount c .*#mount c $TOP#" ./build/dosbox-x.conf > ./build/_dosbox-x.conf
dosbox-x -nologo -machine cga -conf ./build/_dosbox-x.conf 2>&1 | tee log/dosbox-build.log

echo ">>> Collecting resulting binaries into build/bin..."
copy() { if [ -f "$SRC/$1" ]; then cp "$SRC/$1" "bin/$2"; echo "  $2  <= $1"; else echo "  !! MISSING: $1 (see log/)"; fi; }

# --- boot essentials ---
copy BIOS/IO.SYS              io.sys
copy DOS/MSDOS.SYS            msdos.sys
copy CMD/COMMAND/COMMAND.COM  command.com

# --- utilities from CPY.BAT ---
copy CMD/APPEND/APPEND.EXE       append.exe
copy CMD/ASSIGN/ASSIGN.COM       assign.com
copy CMD/ATTRIB/ATTRIB.EXE       attrib.exe
copy CMD/BACKUP/BACKUP.COM       backup.com
copy CMD/CHKDSK/CHKDSK.COM       chkdsk.com
copy CMD/COMP/COMP.COM           comp.com
copy CMD/DEBUG/DEBUG.COM         debug.com
copy CMD/DISKCOMP/DISKCOMP.COM   diskcomp.com
copy CMD/DISKCOPY/DISKCOPY.COM   diskcopy.com
copy CMD/EDLIN/EDLIN.COM         edlin.com
copy CMD/FDISK/FDISK.EXE         fdisk.exe
copy CMD/FIND/FIND.EXE           find.exe
copy CMD/FORMAT/FORMAT.COM       format.com
copy CMD/JOIN/JOIN.EXE           join.exe
copy CMD/LABEL/LABEL.COM         label.com
copy CMD/MEM/MEM.EXE             mem.exe
copy CMD/MODE/MODE.COM           mode.com
copy CMD/MORE/MORE.COM           more.com
copy CMD/PRINT/PRINT.COM         print.com
copy CMD/RECOVER/RECOVER.COM     recover.com
copy CMD/RESTORE/RESTORE.COM     restore.com
copy CMD/SHARE/SHARE.EXE         share.exe
copy CMD/SORT/SORT.EXE           sort.exe
copy CMD/SUBST/SUBST.EXE         subst.exe
copy CMD/SYS/SYS.COM             sys.com
copy CMD/TREE/TREE.COM           tree.com
copy CMD/XCOPY/XCOPY.EXE         xcopy.exe
copy CMD/KEYB/KEYB.COM           keyb.com

# --- device drivers ---
copy DEV/ANSI/ANSI.SYS            ansi.sys
copy DEV/DISPLAY/DISPLAY.SYS      display.sys
copy DEV/KEYBOARD/KEYBOARD.SYS    keyboard.sys
copy DEV/PRINTER/PRINTER.SYS      printer.sys
copy DEV/RAMDRIVE/RAMDRIVE.SYS    ramdrive.sys
copy DEV/SMARTDRV/SMARTDRV.SYS    smartdrv.sys

# --- boot sector built from BOOT/MSBOOT.ASM ---
copy BOOT/MSBOOT.BIN  msboot.bin

echo ">>> Done. Binaries in build/bin/, build log in build/log/dosbox-build.log"
