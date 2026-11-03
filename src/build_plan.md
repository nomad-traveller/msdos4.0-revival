# build_plan.md — MS-DOS 4.00: compile sources → bootable 720 KiB floppy (autonomous)

**Audience:** an autonomous LLM agent (subagents allowed, **no human intervention available**).
**Mission:** from the original 1988/89 MS-DOS 4.00 sources in this tree, run the complete build
with the shipped 16-bit toolchain inside DOSBox-X and deliver a bootable 720 KiB FAT12 floppy.
This document contains every step, gate, expected value and fallback needed to finish without
ever asking a human.

**Deliverable:** `build/msdos400.img` (737,280 bytes = 720 KiB), relative to this `src/` directory.

**Total time budget:** about 20–90 minutes (dominated by the DOSBox-X build).

---

## 0. Definition of Done — all gates must be green

- [ ] Phase 2: `bin/` holds exactly the 38 binaries of Appendix A (`ls bin | wc -l` = 38),
      `bin/io.sys` 33,321 B, `bin/msdos.sys` 37,376 B, `bin/command.com` 37,556 B.
- [ ] Phase 3: `build/msdos400.img` 737,280 B and
      `python3 build/inspect-image.py` prints `ALL GATES PASSED` (exit 0) — that one command
      covers: BPB geometry, boot sector identity (Appendix B), FAT entries, root order,
      \DOS content and 37/37 byte-identical stored files.
- [ ] Phase 4: boot proof on a COPY — serial `BOOT-OK` captured **and** guest-written
      `MARKER.TXT` visible in the image copy afterwards.
- [ ] Phase 5: sha256 written; pristine deliverable untouched by the boot test.

Known-failure shortcuts: if any gate fails, do not improvise — go to the Playbook (§8).

## 0b. First run on a different machine (portability)

The tree ships as a **byte-exact copy of the `src` tree** — everything the build needs is
inside it (fixed sources with their `.ORIG` backups, the drivers, and the 1988 toolchain
under `TOOLS/`). The host only needs the tools below.

1. **Copy the tree byte-exact** — never via a CRLF-mangling or case-mangling path:
   ```sh
   tar -czf msdos400-tree.tgz -C /home/user/project v4.0     # on the reference machine
   tar -xzf msdos400-tree.tgz                                # on the new machine → ./v4.0/src
   ```
   (a zip through Windows, or a git clone with autocrlf=true, silently corrupts the sources).
   Optionally also ship `/home/user/dos16/MS-DOS` (upstream git) — only A3's restore path needs it.
2. **Install host prerequisites** (Debian/Ubuntu names; adapt per distro):
   ```sh
   sudo apt install dosbox-x mtools dosfstools python3 git   # + `xvfb` if there is no display
   ```
   `dosbox-x` packaging varies by distro (`apt-cache policy dosbox-x`); if gates behave
   differently, note it in the final report.
3. **All pipeline drivers auto-adapt to the tree location**: `build-msdos.sh` regenerates
   `build/_dosbox-x.conf` from `build/dosbox-x.conf`, substituting `mount c <tree-root>`;
   every other driver (`make-floppy.sh`, `patch_bpb.py`, `build/fix-*.py`,
   `build/inspect-image.py`) resolves its paths relative to its own file. Only the
   `cd …` lines inside this plan's command blocks carry the reference-machine path
   `/home/user/project/v4.0/src` — replace them with your tree root (`…/v4.0/src`).
4. **Headless machines**: DOSBox-X needs X11 (§1). With `xvfb` installed, wrap the
   DOSBox-X invocations: `xvfb-run -a ./build-msdos.sh` and
   `xvfb-run -a timeout 60 dosbox-x -conf /tmp/bt.conf …` (this alternative was verified
   only conceptually — run the §1b smoke test first, via `xvfb-run -a`, before Phase 2).
5. Phase 0 (§1b) is written to prove the new machine before any real work: run it first.

---

## 1. Environment facts (verified — don't re-derive)

| Item | Value |
|---|---|
| Tree | `/home/user/project/v4.0/src` (this directory) |
| Upstream pristine reference | `/home/user/dos16/MS-DOS` (git; `v4.0/...` paths) — use only to restore individual source files |
| DOS toolchain | inside this tree: `TOOLS/` (MASM, LINK 3.65, NMAKE 1.00.05, CL/MS C 2.x, EXE2BIN, ASC2HLP, BUILDMSG, BUILDIDX, COMPRESS.COM, `BLD/` with lib+inc). Mirror: `/home/user/dos16/DOSTOOLS` |
| Execution environment | `/usr/bin/dosbox-x` — the ONLY thing that can run the 16-bit tools and boot the result |
| Image tools | see "External dependencies" below (mtools, dosfstools, python3, coreutils) |
| Host limitations | QEMU 10.2.1/SeaBIOS **never boots floppies** here (verified exhaustively — don't try); screenshots are impossible (GNOME sandbox); host locale German (cosmetic) |

### External dependencies (versions verified 2026-11-03)

| Tool | Verified version | Role | Requirement |
|---|---|---|---|
| `dosbox-x` (`/usr/bin/dosbox-x`) | 2026.01.02, commit 59915c1, Linux SDL2 64-bit | runs MASM/LINK/NMAKE/CL (Phase 2); boots the image for the proof (Phase 4) | REQUIRED. A reachable **X11 display is a hard prerequisite** — without one SDL2 fails: `E_Exit: Can't init SDL x11 not available`; `[sdl] output=dummy` does **not** bypass it and Xvfb is not installed. Headless workaround: install `xvfb` and wrap the dosbox-x calls with `xvfb-run -a …` (see §0b). |
| GNU `mtools` (`mcopy`, `mdir`, `mtype`, `mmd`) | 4.0.49 | write/verify the FAT12 image (`-i <img> ::…`) | REQUIRED (`mcopy -V`) |
| `mkfs.fat` (dosfstools) | 4.2 (2021-01-31) | create the blank 720 KiB image | REQUIRED (`mkfs.fat --help 2>&1 | tail -1`) |
| `python3` | 3.14.4 | `patch_bpb.py`, `fix-mojibake.py`, `fix-lines-80.py`, `inspect-image.py`, boot-sector verification | REQUIRED |
| POSIX `awk` | mawk 1.3.4 | Phase-1 line-length gate | REQUIRED (any awk works) |
| `bash` + coreutils (`timeout`, `sha256sum`, `tee`, `stat`, `cp`, `grep`, `find`) | bash 5.3.9 | script drivers, gates, delivery manifest | REQUIRED |
| `git` | 2.53.0 (upstream repo `/home/user/dos16/MS-DOS`) | only used to restore pristine files (§3 MSG note, A3 remedy) | optional for the build itself; needed only if that fallback triggers |
| `qemu-system-*` | 10.2.1 (installed, unused) | — | **NOT required. DO NOT USE** — SeaBIOS on this host never boots floppy images in any configuration tried |
| 16-bit toolchain (MASM, LINK 3.65, NMAKE 1.00.05, MS C 2.x, EXE2BIN, ASC2HLP, BUILDMSG, BUILDIDX, COMPRESS.COM) | shipped 1988 binaries | the actual compile, run inside DOSBox-X | REQUIRED — must exist in `TOOLS/` (Phase 0 checks), mirror at `/home/user/dos16/DOSTOOLS` |

**Drivers already in the tree (use them, don't reinvent):**

| Path | Role |
|---|---|
| `build-msdos.sh` | Phase 2 driver: DOSBox-X build + collect 38 binaries into `bin/` |
| `make-floppy.sh` | Phase 3 driver: blank 720K image → boot sector → files |
| `patch_bpb.py` | boot-sector BPB patcher (see §8.B2 history — do not "simplify" it) |
| `run-floppy.sh` | convenience boot wrapper (`build/boottest.conf`) |
| `build/dosbox-x.conf` | build mount config incl. mandatory `set country=usa-ms` |
| `build/dosall.bat` | flattened build batch: one redirected `nmake -i` per leaf → `build/log/M-*.TXT` |
| `build/fix-mojibake.py` | tree-wide `EF BF BD`→`#` fixer, `.ORIG` backups, idempotent, binary-guarded |
| `build/fix-lines-80.py` | rewrites a MASM source to ≤ 80-byte lines (SELECT2.ASM) |
| `build/inspect-image.py` | read-only gate inspector for the finished image |
| `build/boottest.conf` | boot-test config (deliverable path) |
| `build/reset-clean.sh` | clean-slate reset (deletes only reproducible outputs; benchmark runs start here) |
| `build/walkthrough.sh` | one-command autonomous end-to-end run: Phases 1–5 with hard gates → `build/BUILD-REPORT.txt` (exit 0 = all gates) |
| `build/README-BUILD.md` | human-readable pipeline notes |

## 1b. Phase 0 — Preflight (≈ 3 min, gates before any work)

```sh
cd /home/user/project/v4.0/src
command -v dosbox-x mcopy mdir mtype mmd mkfs.fat python3 git sha256sum timeout awk stat
ls TOOLS/MASM.EXE TOOLS/LINK.EXE TOOLS/NMAKE.EXE TOOLS/CL.EXE TOOLS/EXE2BIN.EXE \
   TOOLS/ASC2HLP.EXE TOOLS/BUILDMSG.EXE TOOLS/BUILDIDX.EXE TOOLS/COMPRESS.COM \
   TOOLS/BLD/LIB TOOLS/BLD/INC
```

- Gate: every host tool resolves and every TOOLS file exists.
  Gate fail on TOOLS → restore the missing files by name from the mirror
  `/home/user/dos16/DOSTOOLS`. Gate fail on a host tool → environment failure; report it (§1 table).
- The pipeline drivers must exist: `build-msdos.sh`, `make-floppy.sh`, `patch_bpb.py`,
  `run-floppy.sh`, `build/{dosall.bat, dosbox-x.conf, boottest.conf, fix-mojibake.py,
  fix-lines-80.py, inspect-image.py}`. Missing scripts: recreate only from §1/§5 specs.

Version + smoke check (each §1 dependency; the 10-second smoke test also proves the
X11 display is reachable — see the SDL2 note in §1):

```sh
mcopy -V | head -1 && mkfs.fat --help 2>&1 | tail -1 && python3 --version && git --version
printf '[dosbox]\nmachine=cga\nmemsize=16\n[autoexec]\nexit\n' > /tmp/dbx-smoke.conf
timeout 30 dosbox-x -conf /tmp/dbx-smoke.conf -nogui -nomenu >/dev/null 2>&1 \
  || { echo "FAIL: dosbox-x cannot initialize (X11 display required — see §1)"; exit 1; }
rm -f /tmp/dbx-smoke.conf
```

`build/dosbox-x.conf` `[autoexec]` must set up the build environment exactly like this
(the env vars + `country` are mandatory — a missing COUNTRY env aborts builds; lowercase
`tools/bld` paths are DOS-side, case-insensitive; the host dirs are `TOOLS/BLD/LIB`, `TOOLS/BLD/INC`):

```
mount c /home/user/project/v4.0
c:
set lib=c:\src\tools\bld\lib
set include=c:\src\tools\bld\inc
set init=c:\src\tools
set temp=c:\src
set path=c:\src\tools
set country=usa-ms
c:\src\build\dosall.bat
```

---

## 2. Global invariants (read before doing anything)

1. **CRLF everywhere the DOS side reads**: `.BAT` files, `messages/USA-MS.MSG`, `bios/LOCSCR`,
   `dev/display/ZERO.DAT`, `dev/printer/ZERO.DAT`, every `.SKL`. Git autocrlf stripped CRs in
   the past; the 1988 tools read bare-LF as data (e.g. `0x0A`-EOF crash in `exe2bin`).
2. **One DOSBox-X process at a time.** Never boot or otherwise modify the deliverable
   `build/msdos400.img` — boot tests always use a `cp` first.
3. **No interactive 16-bit tool in batch.** The 1988 `exe2bin` prompts
   ("Fix-ups needed - base segment (hex):") when relocations exist — that hangs an unattended
   build forever. `build/dosall.bat`'s SELECT leaf is deliberately pinned to
   `nmake -i select.exe select.com select.hlp` for exactly this reason. Do not "restore"
   `nmake -i all` for SELECT.
4. **Mojibake rule**: one 3-byte `EF BF BD` (U+FFFD) = exactly ONE original 1988 byte → replace
   1:1 with one `#` (restores byte/string geometry). Legit CP437 content is NEVER touched:
   box-drawing bytes (0xC4 ─ 43k×, 0xCD ═ 15k×, 0xB3 │, corners…), GRAFTABL `GRTAB*.ASM` font
   tables (127–128 distinct byte values each), `KDF*.ASM` keyboard tables, 0xAE/0xAF pairs in
   `DEV/DISPLAY` includes. Binaries are never touched (the fix scripts' NUL-byte guard exists
   because `.OBJ/.EXE/.DAT` can contain the pattern by chance).
5. **Everything host-side stays read-only except** `build/bin/*`, `build/*.img`, `build/log/*`,
   `log/*` and the explicitly documented file fixes.
6. Anti-cheat: boot markers must come **from the guest** (AUTOEXEC in the emulator). Never
   fabricate `/tmp/com1.txt`, marker files, or "fix" the loader.

---

## 3. Phase 1 — Source state check / minimal fixes (about 5 min, idempotent)

Run and gate:

```sh
cd /home/user/project/v4.0/src
python3 build/fix-mojibake.py . --dry-run | tail -3        # GATE: "0 files to fix"
awk '{sub(/\r$/,""); if(length($0)>80) print FILENAME":"FNR" len="length}' SELECT/SELECT2.ASM   # GATE: no output
cmp -s SELECT/USA.INF SELECT/PANEL.INF && echo INF-OK      # GATE: INF-OK
python3 - <<'EOF'                                          # GATE: all CRLF-OK (or "no file")
import glob
for f in ["build/dosall.bat","MESSAGES/USA-MS.MSG","BIOS/LOCSCR",
          "DEV/DISPLAY/ZERO.DAT","DEV/PRINTER/ZERO.DAT","SELECT/SELECT2.ASM"]:
    for p in glob.glob(f):
        data = open(p,"rb").read()
        bad = sum(1 for l in data.split(b"\r\n")[1:] if l.endswith(b"\n"))
        print(p, "CRLF-OK" if bad==0 else f"CRLF-BAD({bad})")
EOF
# NOTE on MESSAGES/USA-MS.MSG: the CRLF gate above is the only MSG gate. Its size may be
# 54,434 B (built, CRLF, stamp "0087") or the pristine 53,248 B blob (LF, stamp "0085")
# — both are fine; a stale/duplicated MSG is what A3 handles.
```

Fixes if a gate fails (each is a one-command, documented operation):

| Gate failure | Command / action |
|---|---|
| mojibake present | `python3 build/fix-mojibake.py .` (auto-creates `<file>.ORIG` backups; re-run dry-run → 0) |
| SELECT2.ASM lines > 80 | `python3 build/fix-lines-80.py SELECT/SELECT2.ASM` |
| USA.INF ≠ PANEL.INF | fix USA.INF (as above), then `cp SELECT/USA.INF SELECT/PANEL.INF` |
| CRLF-BAD on a file | rewrite that file CRLF (byte-preserving, e.g. python `data.replace(b"\n", b"\r\n")` for a file known to lack CRs — verify with the same gate) |
| USA-MS.MSG ≠ 53,248 B | restore pristine from upstream git:
  `git -C /home/user/dos16/MS-DOS show HEAD:v4.0/src/MESSAGES/USA-MS.MSG > MESSAGES/USA-MS.MSG`
  then normalize to CRLF byte-safely:
  `python3 -c "f='MESSAGES/USA-MS.MSG'; d=open(f,'rb').read(); open(f,'wb').write(d.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))"`
  (if `M-MESSA.TXT` later shows `A2004` redefinitions, delete `MESSAGES/USA-MS.IDX` and rebuild — the messages leaf's `buildidx` step recreates it) |

Do **not** delete the 16 `<name>.ORIG` backups in the tree (fix provenance, never re-scanned).
Do not clean the tree "for freshness": NMAKE handles incrementally; a true from-scratch run is
optional (§8.C4).

**For a benchmark/from-scratch walkthrough:** run `bash build/reset-clean.sh` first — it deletes
only reproducible build outputs (the microsoft/MS-DOS archive SHIPS 750+ pre-built 1988
artifacts, so an untouched tree builds "instantly" as up-to-date), plus stale
`MESSAGES/USA-MS.IDX`, logs, `bin/` and a stale image — then proceed to Phase 2.

---

## 4. Phase 2 — Full build (about 15–60 min, unattended)

```sh
cd /home/user/project/v4.0/src
timeout -k 60 7200 -s INT ./build-msdos.sh ; echo "exit=$?"
```

`build-msdos.sh` runs `dosbox-x -conf build/dosbox-x.conf` (mounts the tree as C:, sets
LIB/INCLUDE/INIT/TEMP/PATH + `COUNTRY=usa-ms`, runs `c:\src\build\dosall.bat`, whose last
statement is `exit` → DOSBox-X terminates). Then it collects 38 binaries into `bin/`.
Console log (incl. MASM/LINK stderr): `log/dosbox-build.log`.

**Gates:**

```sh
ls bin | wc -l                       # GATE: 38  (list = Appendix A; script prints "!! MISSING" otherwise)
stat -c '%s %n' bin/io.sys bin/msdos.sys bin/command.com   # 33321 / 37376 / 37556
find build/log -iname 'm-*.txt' | wc -l        # GATE: 59 (60 nmake leaves; see note below)
find build/log -iname 'm-*.txt' -size +0 | wc -l   # GATE: ≥50 for a clean run — LESS means A10
                                                   # (instant-finish: missing build/log or
                                                   #  shipped-artifact up-to-date — see §8)
find build/log -iname 'm-*.txt' -size 0 | sed 's/.*\///i' | sort
grep -l 'error' build/log/M-*.TXT | xargs -r grep -in 'fatal\|error A\|error L\|E_Exit' | head   # GATE: nothing
grep -ci 'e_exit\|critical' log/dosbox-build.log               # GATE: 0
```

- Known-ALWAYS-empty (not failures): `M-EGA.TXT M-LCD.TXT M-5202.TXT M-EMM.TXT M-MEMM.TXT`
  (their NMAKE steps print nothing; code links into display.sys/printer.sys).
- 8.3 truncation applies: DOSBox's redirect writes `M-KEYBOA.TXT` for keyboard, etc.
  One collision is known: **DISKCOPY and DISKCOMP both truncate to `M-DISKCO.TXT`** (60 leaves
  → 59 files on disk).
- After an *incremental* re-run most logs may be empty (NMAKE prints nothing when up-to-date).
  That is NOT a failure — the authoritative gates are `bin` count 38/38, zero fatal patterns,
  and the boot proof. To measure full logs regardless: delete `build/log/M-*.TXT` before the run.
- Any module's log shows a real error → read the log's first error, apply §8, then re-run
  `./build-msdos.sh` (incremental NMAKE rebuilds only what's needed).

SELECT build gate (not on the floppy but must build): `SELECT/SELECT.EXE` ≈ 95.1 KB
(95,107 B on a fresh full rebuild; 95,123 B on a mixed-incremental tree),
plus `SELECT/SELECT.COM` and `SELECT/SELECT.HLP` exist. `SELECT.DAT` is NOT rebuilt by dosall.bat
(interactive `exe2bin` trap) — see §8.A4/B3 if it ever needs rebuilding.

---

## 5. Phase 3 — Floppy assembly (about 2 min)

```sh
cd /home/user/project/v4.0/src && ./make-floppy.sh
python3 build/inspect-image.py ; echo "gate=$?"          # GATE: ALL GATES PASSED, exit 0
```

`make-floppy.sh` does: `mkfs.fat -C -F 12 -S 512 -M 0xF9 … 720` → `patch_bpb.py` writes the
**built** boot sector with a static 720K BPB and fixes both FAT[0] entries to `F9 FF FF` →
`IO.SYS`/`MSDOS.SYS` copied as the FIRST TWO root entries (the MSBOOT.ASM loader, built with
`IBMCOPYRIGHT EQU FALSE`, searches exactly the names `IO      SYS`, then `MSDOS   SYS`) →
`COMMAND.COM` in root → remaining 34 files under `\DOS`.

`inspect-image.py` (read-only) verifies, printing one PASS line each:
1. size 737,280; 2. BPB = 512/2/1/2/112/1440/0xF9/3/9/2; 3. boot sector 0 == **last 512 bytes
of bin/msboot.bin** (exe2bin put the loader at the image tail) except exactly the BPB offsets
`0x0d 0x11 0x12 0x13 0x14 0x15 0x16 0x18 0x1a 0x1c 0x24`; 4. FAT1[0] == FAT2[0] == `F9 FF FF`;
5. root order IO=2 / MSDOS=35 / COMMAND=72 / DOS=109; 6. `\DOS` holds 34 files;
7. all 37 stored files byte-identical to `bin/` originals (zero-padding beyond EOF).

---

## 6. Phase 4 — Boot proof (about 2 min, always on a COPY)

`boot a:` **with the colon** (`boot a` is parsed as an image *file name* and fails silently).

```sh
cd /home/user/project/v4.0/src
cp build/msdos400.img /tmp/test.img                                        # never boot the deliverable
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
rm -f /tmp/com1.txt
timeout 60 dosbox-x -conf /tmp/bt.conf -nogui -nomenu -time-limit 35
grep -q BOOT-OK /tmp/com1.txt && echo PROOF1-SERIAL-OK || echo PROOF1-FAIL   # GATE PROOF1
mdir -i /tmp/test.img | grep -q MARKER.TXT && echo PROOF2-WRITEBACK-OK || echo PROOF2-FAIL  # GATE PROOF2
sha256sum build/msdos400.img                                                 # unchanged vs Phase 5 pre-state
rm -f /tmp/test.img /tmp/autoexec.bat /tmp/bt.conf /tmp/com1.txt
```

Why this works: MS-DOS 4.00's `COM1` is the AUX device via INT 14h, so guest `echo > COM1`
lands in the host file captured by `[serial] serial1=file`; the guest's INT 13h write of
`MARKER.TXT` persists into the image file (DOSBox-X write-back). Both signals = boot proof.
PROOF1-FAIL → §8.B6/B2. PROOF2-FAIL → §8.B2 (loader shift).
Normal (not failures): the console shows `ERROR BIOS:Disk 1/2 not active` and
`INT15:Unknown call ax=4100` lines during every DOS boot — expected DOSBox-X chatter.

---

## 7. Phase 5 — Deliver

```sh
cd /home/user/project/v4.0/src
sha256sum build/msdos400.img | tee build/msdos400.img.sha256
mdir -i build/msdos400.img | head -40
ls -l bin | wc -l
```

Final report: PASS/FAIL per gate of Phases 1–4, the sha256, and the two proof outputs.
Nothing else in the tree changed (Phase 2 writes only build artifacts/logs/bin).

---

## 8. Failure Playbook (symptom → cause → exact remedy)

### A. Build-time
| # | Symptom | Cause | Remedy |
|---|---|---|---|
| A1 | `select2.asm(xx): error A2106: Line too long` | repo stores some CP437 banner bytes as 3-byte UTF-8 U+FFFD; MASM 4.x line buffer overflows | `python3 build/fix-lines-80.py SELECT/SELECT2.ASM` (rewrites ≤ 80 B/line, keeps token stream; expect 631 lines) |
| A2 | `panels.asm(1687): error A2029: Division by 0 or overflow`, `panel.inf(xxxx): A2106`, then `LINK : fatal error L1093: PANELS.OBJ: object not found` | U+FFFD triples in PANELS.ASM/USA.INF/PANEL.INF break panel string-width equate math | replace every `EF BF BD` (3 B) with `#` (1 B) in `SELECT/PANELS.ASM`, `SELECT/USA.INF`, copy USA.INF→PANEL.INF. PANEL.INF is generated FROM USA.INF by the build — fixing only PANEL.INF gets overwritten |
| A3 | messages leaf: `error A2004: ... redefinition` | stale/duplicated USA-MS.MSG/IDX | restore pristine from upstream git (`git -C /home/user/dos16/MS-DOS show HEAD:v4.0/src/MESSAGES/USA-MS.MSG > MESSAGES/USA-MS.MSG`, CRLF-normalized per §3), delete `MESSAGES/USA-MS.IDX`, replay messages leaf via `./build-msdos.sh`. (Builds may legitimately re-stamp the MSG: pristine = 53,248 B LF "0085"; on disk after builds = 54,434 B CRLF "0087") |
| A4 | build hangs; console shows `Fix-ups needed - base segment (hex):` | 1988 `exe2bin` prompts when its input has relocations (the `select.dat` target) | kill emulator (timeout does it). Keep dosall.bat's SELECT leaf at `nmake -i select.exe select.com select.hlp`. To (re)build SELECT.DAT deterministically: `python3 -c "d=open('SELECT/SEL-PAN.EXE','rb').read(); open('SELECT/SEL-PAN.DAT','wb').write(d[32*16:])"` — drop the 512-byte EXE header (32 paragraphs × 16 B); SEL-PAN.EXE has 0 relocations and CS:IP=0, so the output is identical (55,983 B). Then in DOSBox: `cd \src\select` + `compress` (shipped `TOOLS/COMPRESS.COM`, hardcoded SEL-PAN.DAT→SELECT.DAT, non-interactive) → SELECT.DAT 22,784 B |
| A5 | whole build hangs after one leaf / a leaf log missing | interactive prompt (see A4) or batch lost CRLF | A4, or check `build/dosall.bat` line endings; final line must be `exit`, CRLF |
| A6 | MASM "cannot open"/immediate exits | env incomplete | `build/dosbox-x.conf` must set lib/include/init/temp/path exactly as in-tree + `set country=usa-ms` |
| A7 | `0x0A`-EOF crash in DOS tools under redirected input | a DOS-read file lost CRLF | fix to CRLF (§2 rule 1), rerun |
| A8 | `error A2106` in any other .ASM/.INC | same mojibake pattern elsewhere | `python3 build/fix-mojibake.py .` (tree-wide, `.ORIG` backup, binary-guarded, idempotent) |
| A9 | NMAKE `U1002`/syntax storm | dosall.bat edited badly | regenerate strictly as "one line: cd \src\<leaf> / nmake -i <targets> > c:\src\build\log\m-<name>.txt", CRLF, end with `exit` |
| A10 | build "finishes" in seconds with ALL `M-*.TXT` 0 B and the collector spams `!! MISSING` | guest-side redirects failed (classic: `build/log/` never created) or the tree still carries shipped artifacts (instant up-to-date) | `mkdir -p build/log` (build-msdos.sh now does it itself) — and run `bash build/reset-clean.sh` for benchmark runs; verify Phase-2 logs show real work (≥50 non-empty) |

### B. Image-time
| # | Symptom | Cause | Remedy |
|---|---|---|---|
| B1 | mtools errors "Cannot initialize ::" | forgot `-i <img>` | always `mcopy/mdir/mtype -i <img> ::…` |
| B2 | boots silently, hangs, no serial output | boot loader shifted: e.g. `boot[0x36:0x3D] = b"FAT12   "` expands the bytearray by 1 byte and misaligns the loader at 0x3E (historical bug, fixed) | `patch_bpb.py` must write exactly `boot[0x36:0x3E] = b"FAT12   "` (8-byte slice) and the GEOM table of BPB fields; re-run make-floppy + inspect gates (gate 3/5 catch any shift) |
| B3 | see A4 (SELECT.DAT) | — | — |
| B4 | `mkfs.fat` gives FAT[0]=`AA FF FF` | media byte mismatch vs BPB 0xF9 | patched by `patch_bpb.py` (both copies); verify via `inspect-image.py` gate 4 |
| B5 | IO.SYS loads, DOS not found / boot loop | root order wrong | `IO.SYS`, `MSDOS.SYS` must be the first two root entries (make-floppy.sh does this; re-check with gate 5) |
| B6 | `boot a` does nothing on screen | colon missing | `boot a:` |

### C. Environment
| # | Symptom | Remedy |
|---|---|---|
| C1 | QEMU boots nothing | platform limitation — use DOSBox-X only |
| C2 | screenshot tools fail/return black image | no screenshots on this host — use serial + write-back proofs |
| C3 | host text in German | cosmetic; ignore |
| C4 | tree builds "instantly" / NMAKE up-to-date | the archive ships 750+ pre-built 1988 outputs | run `bash build/reset-clean.sh` (whitelist-guarded: protects TOOLS/, INC/ .OBJ+LIB inputs, H/, build/, drivers, .ORIG, LOCSCR, ZERO.DAT, USA-MS.MSG, OPENPTMS.DAT, *.SKL, *.LNK) and re-run Phase 2; for a benchmark, ALWAYS walk through this clean run (measured: ~2.6 min on aarch64, ~30 s on the reference x86) |
| C5 | need to debug INSIDE the emulator: no DOS output on the console | DOSBox-X console carries only `LOG:` lines (emulator diagnostics) | capture guest output into FILES from inside DOS (`nmake -i all > c:\src\build\log\diag.txt` etc.), then read them host-side — the file is stored as UPPERCASE 8.3 (`DIAG.TXT`); guest-side writes need the target directory to exist (`build/log`) |

---

## Appendix A — the 38 collected binaries (exact list)

Boot essentials: `io.sys` (BIOS/IO.SYS), `msdos.sys` (DOS/MSDOS.SYS), `command.com`
(CMD/COMMAND/COMMAND.COM) — from CMD (28): append.exe, assign.com, attrib.exe, backup.com,
chkdsk.com, comp.com, debug.com, diskcomp.com, diskcopy.com, edlin.com, fdisk.exe, find.exe,
format.com, join.exe, keyb.com, label.com, mem.exe, mode.com, more.com, print.com,
recover.com, restore.com, share.exe, sort.exe, subst.exe, sys.com, tree.com, xcopy.exe —
drivers (6): ansi.sys, display.sys, keyboard.sys, printer.sys, ramdrive.sys, smartdrv.sys —
plus `msboot.bin` (BOOT/MSBOOT.BIN, 32,256 B; its LAST 512 bytes are the boot sector).
Floppy layout: IO.SYS, MSDOS.SYS, COMMAND.COM in root; the 34 others in `\DOS`.

## Appendix B — image geometry (verified by build/inspect-image.py)

720 KiB FAT12: 512 B/sector · 2 sectors/cluster · 1 reserved · 2 FATs × 3 sectors ·
112 root entries · 1440 total sectors · media 0xF9 · 9 sectors/track · 2 heads ·
drive 0 · ext-BPB signature 0x29 · FAT[0]=`F9 FF FF` in both copies ·
boot sector = last 512 B of `bin/msboot.bin` with only the BPB fields rewritten;
loader = `jmp 0x7C3E` after a BPB at 0x0B, resumes `FA 33 C0` (CLI) at 0x3E —
**any byte shift in the 0x36–0x3D region kills the boot silently** (see §8.B2).

## Appendix C — one-page condensed runtime (happy path)

```sh
cd /home/user/project/v4.0/src
python3 build/fix-mojibake.py . --dry-run | tail -1            # "0 files", else run for real
timeout -k 60 7200 -s INT ./build-msdos.sh                     # Phase 2 (15-60 min)
ls bin | wc -l                                                 # GATE: 38
./make-floppy.sh                                               # Phase 3 (idempotent)
python3 build/inspect-image.py                                 # GATE: ALL GATES PASSED
cp build/msdos400.img /tmp/test.img && printf 'echo BOOT-OK > COM1\r\necho X > A:\\MARKER.TXT\r\n' > /tmp/autoexec.bat
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
rm -f /tmp/com1.txt && timeout 60 dosbox-x -conf /tmp/bt.conf -nogui -nomenu -time-limit 35
grep -q BOOT-OK /tmp/com1.txt && mdir -i /tmp/test.img | grep -q MARKER.TXT && echo BUILD-AND-BOOT-VERIFIED
```

*Status of the tree at the time this plan was written:* all Phase 1 gates green
(0 mojibake files; SELECT2.ASM ≤ 80 cols; INF-OK; all CRLF-OK; USA-MS.MSG = 54,434 B CRLF,
stamp "0087" — the expected post-build form). Phase 2/3 complete (38/38 in `bin/`, image
737,280 B, `python3 build/inspect-image.py` prints ALL GATES PASSED), and the Phase 4 proof
recorded as green (serial `MSDOS400-BOOT-OK`/`BOOT-OK`, `MARKER.TXT` write-back). A fresh
agent run should therefore reach Definition of Done quickly; the plan remains sufficient to
rebuild everything from scratch after a full reset.
