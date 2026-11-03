# MS-DOS 4.00 Source (revival)

A clean, source-only mirror of the MS-DOS 4.00 tree — the IBM/Microsoft 1988/89 16-bit
sources. **No build intermediates, no generated images, no logs** are checked in. Only
source code and build scripts (`*.asm`, `*.inc`, `*.c`, `*.h`, Makefiles, INF/INI, `.bat`,
`.sh`, and the MS-DOS build/tuning scripts under `src/build/`).

## Prerequisites

Runs under Linux (tested with DOSBox-X 2026.01.02 + SDL2):

- `dosbox-x`
- `mtools` (`mcopy`, `mdir`, ...)
- `dosfstools` (`mkfs.fat`)
- `python3`
- `git`, `sha256sum`, `timeout`, `awk`, `stat` (used by the walkthrough gates)

Install example (Debian/Ubuntu):
`sudo apt install dosbox-x mtools dosfstools python3 git coreutils`

## Status

- **Type**: Source-preservation / study project.
- **Original copyright**: Copyright © IBM and Microsoft Corporation. Released under the
  MIT License (see `LICENSE`). The copyright notice is retained verbatim.
- **Build**: Requires the shipped 16-bit DOS toolchain (MASM, LINK, NMAKE, MS C 2.x,
  EXE2BIN, NOSRVBLD) executed inside DOSBox-X. See `src/build/README-BUILD.md` and
  `src/build_plan.md`.
- **Deliverable**: A bootable 720 KiB FAT12 floppy image (`build/msdos400.img`) — the
  reproducible output of the verified pipeline (boot sector + `IO.SYS`/`MSDOS.SYS`/
  `COMMAND.COM` + utilities).
- **Verified**: A from-scratch DOSBox-X rebuild, 38/38 binaries collected, boot proof
  via serial `BOOT-OK`. See `src/build/BUILD-REPORT.txt`.

## Contents

```
src/
├── BIOS/      IO.SYS / bios source
├── BOOT/      MSBOOT.ASM (boot sector)
├── CMD/       utilities (COMMAND.COM, ATTRIB, FORMAT, FDISK, ...)
├── DEV/       device drivers (ANSI, DISPLAY, KEYBOARD, PRINTER, RAMDRIVE, SMARTDRV, ...)
├── DOS/       MSDOS.SYS kernel
├── INC/, H/   headers and macros
├── LIB/, MESS/ shared
├── MAPPER/    NLS/ country-code mapper
├── MEMM/      XMA/EMM managers
├── SELECT/    SELECT
├── build/      scripts, reproducible pipeline, gates
└── TOOLS/     shipped 16-bit toolchain
LICENSE        MIT (IBM and Microsoft)
```

## Building

From the `src/` directory (requires `dosbox-x`, `mtools`, `mkfs.fat`, `python3`):

```bash
cd src
bash build/walkthrough.sh        # all-in-one, exit 0 == all gates passed
```

See `src/build/README-BUILD.md` for the step-by-step pipeline.

## Not for production use

These sources are 16-bit x86 and run only inside a 16-bit DOS emulation environment.
They are provided for study, build experiments, and OS-history context.

## Output of a successful build

After `bash build/walkthrough.sh` (or the manual pipeline) succeeds, the deliverable is a
**single 720 KiB FAT12 floppy image**:

```
v4.0/src/build/msdos400.img
```

The build boots via `IO.SYS` → `MSDOS.SYS` → `COMMAND.COM` and includes the utilities
under `\\DOS` (see `src/build/README-BUILD.md`).

## Licence

MIT — original copyright notice in `LICENSE` must be retained in any copy or substantial
portion of the Software.
"