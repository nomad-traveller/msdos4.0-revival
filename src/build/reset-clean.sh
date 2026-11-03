#!/usr/bin/env bash
# reset-clean.sh — clean-slate reset: remove all REPRODUCIBLE build outputs so the
# next ./build-msdos.sh performs a genuine from-scratch compile (build_plan.md §8.C4).
#
# Protected (never touched): TOOLS/, INC/ (shipped .OBJ/.LIB inputs), LIB/, H/,
# build/ (pipeline drivers+configs), *.sh/*.py drivers, *.ORIG provenance backups,
# LOCSCR, ZERO.DAT (input data), USA-MS.MSG (source), OPENPTMS.DAT, *.SKL, *.LNK.
# Deleted: the tree's own .OBJ/.EXE/.COM/.SYS/.MAP/.CTL/.CL*/.IDX/.BIN/.HLP/.DAT
# outputs and USA-MS.IDX (stale index), stale logs, stale bin/ and stale image.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRC" || exit 1
echo "=== reset-clean: $SRC ==="

find . -name '*.ORIG' -prune -o \( \
  \( -name '*.OBJ' -o -name '*.obj' -o -name '*.EXE' -o -name '*.exe' \
     -o -name '*.COM' -o -name '*.com' -o -name '*.SYS' -o -name '*.sys' \
     -o -name '*.MAP' -o -name '*.map' -o -name '*.CTL' -o -name '*.CL1' \
     -o -name '*.CLA' -o -name '*.CLB' -o -name '*.CLO' -o -name '*.IDX' \
     -o -name '*.BIN' -o -name '*.HLP' -o -name '*.DAT' \) \
  ! -path './TOOLS/*' ! -path './INC/*' ! -path './LIB/*' ! -path './H/*' \
  ! -path './build/*' \) -print 2>/dev/null \
  | grep -vE 'ZERO\.DAT|LOCSCR|USA-MS\.MSG|OPENPTMS\.DAT' > /tmp/reset-clean.del.txt

if grep -qE '^\./(TOOLS|INC|LIB|H|build)/' /tmp/reset-clean.del.txt; then
  echo "GUARD: protected paths in delete list — aborting (nothing deleted)"; exit 1
fi
xargs -r -a /tmp/reset-clean.del.txt rm -fv 2>/dev/null | wc -l | sed 's/^/deleted build outputs: /'
rm -fv MESSAGES/USA-MS.IDX
rm -f  build/log/M-*.TXT build/_dosbox-x.conf
rm -rf bin
rm -f  build/msdos400.img build/msdos400.img.sha256
mkdir -p build/log bin
echo "done. Next: ./build-msdos.sh (from-scratch; expect ~54 non-empty build/log/M-*.TXT on success)"