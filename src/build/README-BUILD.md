# MS-DOS 4.00 build-to-bootable-floppy pipeline

Everything is produced from the original 1988/89 sources in this tree
using the shipped 16-bit toolchain (`TOOLS/`, also mirrored at
`/home/user/dos16/DOSTOOLS`: MASM, LINK, NMAKE, MS C 2.x, EXE2BIN,
NOSRVBLD, ...) executed inside DOSBox-X (2026.01.02 SDL2).

Deliverable: `build/msdos400.img` — a bootable 720 KiB FAT12 floppy.

## Pipeline

Run from the tree root (`src/`):

1. `./build-msdos.sh` – builds the whole tree with the shipped toolchain
   inside DOSBox-X (`dosbox-x.conf` mounts the tree as C:, sets
   `LIB/INCLUDE/INIT/TEMP/PATH` and `COUNTRY=usa-ms`, then calls
   `dosall.bat`). `dosall.bat` runs `nmake -i all` once per leaf module
   and redirects each into `log/m-<module>.txt` (recursive NMAKE calls
   lose their output through parent `>` redirections in DOSBox-X, so the
   leaves are flattened instead). Afterwards the script collects
   `io.sys`, `msdos.sys`, `command.com`, the ~35 utilities/drivers and
   `msboot.bin` into `build/bin/` (38 files). The tee'd emulator console
   log (incl. all MASM link/map chatter on stderr) lands in `src/log/`.

2. `./make-floppy.sh` – creates `build/msdos400.img`:
   1. `mkfs.fat -C -F 12 -S 512 -M 0xF9 … 720` (blank 720 KiB FAT12),
   2. the built MS-DOS 4.00 boot sector (`BOOT/MSBOOT.ASM`) with its BPB
      statically patched to the 720K geometry by `patch_bpb.py`
      (512 B/sector, 2 sectors/cluster, 112 root entries, 1440 sectors,
      media 0xF9, 3 sectors/FAT, 9 sectors/track, 2 heads,
      drive number 0, extended BPB signature 0x29),
   3. `IO.SYS` / `MSDOS.SYS` copied as the FIRST TWO root-directory
      entries (the `MSBOOT.ASM` loader, built with
      `IBMCOPYRIGHT EQU FALSE` in `INC/VERSION.INC`, searches for
      exactly those 11-byte names in this order),
   4. `COMMAND.COM` in the root, the remaining utilities and device
      drivers under `\DOS`.

3. `./run-floppy.sh` – boots the image in DOSBox-X.

Requirements: `dosbox-x`, `mtools`, `mkfs.fat`, `python3`
(QEMU is NOT usable as a boot tester on this host, see Known issues).

## Autonomous walkthrough (all-in-one)

`bash build/walkthrough.sh` (from the tree root) runs `build_plan.md` Phases 1–5 in
one command with hard gates, appending every step to `build/BUILD-REPORT.txt`.

* **Exit 0 == all gates passed** and `build/msdos400.img` is a freshly built,
  boot-verified deliverable. Any failed gate logs `[$FAIL] <name>` and aborts.
* **Phase 0 preflight** checks host tools (`dosbox-x mcopy mdir mtype mmd mkfs.fat
  python3 git sha256sum timeout awk stat`), `xvfb-run` when headless, the shipped
  `TOOLS/` toolchain and the driver scripts — before anything is touched.
* **Phase 1 self-heals and re-verifies**: mojibake → `#` (dry-run anchored on the
  exact summary line), SELECT2.ASM ≤ 80 cols, USA.INF == PANEL.INF, CRLF restore.
* **Phase 2**: a stray DOSBox-X is killed first; by default `reset-clean.sh` runs
  for a true from-scratch rebuild, stale `build/log/M-*.TXT` are rotated away so
  the fatal-error gate only sees this run, and the plan's §4 gates are enforced
  (38/38 binaries, boot-essential byte sizes, ≈400 `.OBJ`, ≥50 non-empty logs).
  Pass `WALKTHROUGH_INCREMENTAL=1` to keep the tree and reuse NMAKE products —
  incremental logs may legitimately be empty when up-to-date, so log-count gates
  are reported, not enforced, in that mode.
* **Phase 4** boots a `/tmp` COPY (invariant: never boot the deliverable) and now
  verifies `sha256(build/msdos400.img)` is unchanged after the run.
* Headless-safe: without `DISPLAY`, DOSBox-X calls are wrapped in `xvfb-run -a`.

## Boot verification

`boottest.conf` (`imgmount a … -t floppy` + `boot a:`) boots the image
in DOSBox-X to an MS-DOS 4.00 shell. Verified on 2026-11-03 by two
independent, automated proofs:

* **File-system write-back**: a test copy of the image booted with an
  `AUTOEXEC.BAT` that created `A:\MARKER.TXT` and `A:\DIRLIST.TXT`
  (via INT 13h writes) — both files appeared in the image file after
  the run, and `DIRLIST.TXT` contains the guest's own `DIR A:\`
  listing (all root files, 11-03-26 dates).
* **Serial capture**: `AUTOEXEC.BAT` redirected output to COM1 and
  DOSBox-X `[serial] serial1=file file:/tmp/com1.txt` captured
  `MSDOS400-BOOT-OK` / `AUTOEXEC-RAN` from the running guest. (Serial
  capture works on MS-DOS 4.00 because `COM1` is the AUX device going
  through INT 14h; the DOS 3.x-era control image instead creates a
  *file* named `COM1` — both are proof the AUTOEXEC ran.)

Both the image with `CONFIG.SYS`/`AUTOEXEC.BAT` and the pristine
deliverable (serial-only test) boot successfully.

### Reproduce the boot proof

```sh
cp build/msdos400.img /tmp/test.img
printf 'echo BOOT-OK > COM1\r\necho X > A:\\MARKER.TXT\r\n' > /tmp/autoexec.bat
mcopy -i /tmp/test.img -o /tmp/autoexec.bat ::AUTOEXEC.BAT
cat > /tmp/bt.conf <<'EOF'
[dosbox]
machine=cga
memsize=16
[cpu]
cputype=486
cycles=max
[serial]
serial1=file file:/tmp/com1.txt timeout:1000
[autoexec]
imgmount a /tmp/test.img -t floppy
boot a:
EOF
dosbox-x -conf /tmp/bt.conf -nogui -nomenu -time-limit 35
cat /tmp/com1.txt        # -> BOOT-OK
mdir -i /tmp/test.img    # -> MARKER.TXT present
```

## Known issues / notes

* **QEMU**: this host's QEMU 10.2.1 + SeaBIOS never boots from a floppy
  image in any configuration tried (`-fda -boot a`,
  `-drive if=floppy -boot order=a`, `-global isa-fdc.fdtypeA=144`,
  720K and 1440K images). The image is valid (mtools, DOSBox-X and the
  control image all accept/boot it) — use DOSBox-X for boot testing.
* **DOSBox-X boot syntax**: when the floppy is attached with
  `imgmount a <img> -t floppy`, the boot command must be `boot a:`
  (with the colon). `boot a` is parsed as an image *file name* and
  fails silently on screen (this masked the first boot tests).
* **patch_bpb.py** previously wrote the FAT system ID with
  `boot[0x36:0x3D] = b"FAT12   "` — 8 bytes into a 7-byte slice —
  which expanded the bytearray and shifted the loader code behind the
  label by one byte, hanging the boot silently. It now uses the
  8-byte slice `[0x36:0x3E]`.
* CRLF matters: all `.SKL` files, `MESSAGES/USA-MS.MSG`,
  `BIOS/LOCSCR`, `DEV/DISPLAY/ZERO.DAT`, `DEV/PRINTER/ZERO.DAT` and
  every `.BAT` read by DOS (incl. `dosall.bat`) must carry CR+LF
  (git's autocrlf had stripped the CRs; the 1988 tools read plain LF
  as part of the data, e.g. the DOS 0x0A redirected-input EOF crash in
  `exe2bin`).
* To write to a real floppy: `dd if=build/msdos400.img of=/dev/fd0 bs=512`.
* Per-module build logs: `log/m-*.txt` (one file per leaf from the last
  full run of `dosall.bat`). Five second-level leaves (`m-ega.txt`,
  `m-lcd.txt`, `m-5202.txt`, `m-emm.txt`, `m-memm.txt`) stay empty
  because those NMAKE steps print nothing directly; their code is
  linked into `display.sys`/`printer.sys` (or not used by the boot flow).
* **SELECT module**: the repo stores some CP437 box-drawing banner
  characters of `SELECT/SELECT2.ASM` as UTF-8-encoded U+FFFD (3 bytes
  each), inflating comment lines past MASM 4.x's line buffer and
  aborting with `A2106: Line too long` (6 severe errors, no
  `select2.obj`). `build/fix-lines-80.py` rewrites every line to
  <= 80 bytes: each 3-byte U+FFFD becomes the CP437 light-shade byte
  0xB0 (comments only), long code lines get their internal whitespace
  squeezed and their trailing `;ANnnn;` comments moved onto separate
  comment lines. After this SELECT2.OBJ assembles with 0 errors and
  the full `SELECT.EXE` link (95 KB) succeeds. The same 3-byte U+FFFD
  rows in `USA.INF` (copied to `PANEL.INF`, included by `PANELS.ASM`/
  `COLORS.ASM`) were likewise replaced by `#` (1033 triples; panel
  byte-geometry restored to the original 1988 widths, so the
  `PANELxx_W/L` equate math and the former `panels.asm(1687)` A2029
  overflow resolve), plus one whitespace-inflated line (437) squeezed.
  All four module outputs now build: SELECT.EXE, SELECT.COM (SSTUB),
  SELECT.HLP (asc2hlp, 57 topics) and SELECT.DAT.
  `sel-pan.exe`/`sel-pan.dat` with a bare `exe2bin sel-pan.exe
  sel-pan.dat`, which (as in 1988) prompts "Fix-ups needed - base
  segment" on the console and hangs a batched build. The exe has 0
  relocations and CS:IP=0, so the identical conversion is performed
  deterministically by stripping the 512-byte header
  (SEL-PAN.DAT = 55,983 B), after which the shipped `compress`
  (hardcoded SEL-PAN.DAT -> SELECT.DAT) produces SELECT.DAT (22,784 B)
  non-interactively. From-scratch rebuilds should not invoke the
  `select.dat` target; the other targets of `nmake -i all` are safe
  (dosall.bat's SELECT leaf therefore builds only
  `select.exe select.com select.hlp`).
* **Mojibake**: the repo stores 1988 CP437 box characters throughout
  the tree as UTF-8-encoded U+FFFD (3 bytes). `build/fix-mojibake.py`
  replaces every occurrence in text sources (`.ASM .INC .MAC .EQU
  .SKL .MSG .TXT .INF`) with `#`, backing each untouched original up
  as `<file>.ORIG` first, skipping binaries/logs, and is idempotent
  (a re-run reports 0 files). All 16 affected files (SELECT0-9,
  SELECT2A/5A, COLORS, SCROLL, INPUT, ROUTINES, DATA.MAC,
  INT10COM.INC — 1,858 triples on the sweep, after the earlier
  PANELS.ASM/USA.INF work) were converted this way and the full
  build + floppy boot test re-verified afterwards.