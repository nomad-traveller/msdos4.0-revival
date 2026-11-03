@echo off
rem FLATTENED MS-DOS 4.00 build - one redirected nmake per leaf module
rem (avoids: recursive nmake output not surviving shell redirects in DOSBox-X)
cd \src\messages
nmake -i all > c:\src\build\log\m-messages.txt
cd \src\mapper
nmake -i all > c:\src\build\log\m-mapper.txt
cd \src\boot
nmake -i all > c:\src\build\log\m-boot.txt
cd \src\bios
nmake -i all > c:\src\build\log\m-bios.txt
cd \src\dos
nmake -i all > c:\src\build\log\m-dos.txt
cd \src\cmd\command
nmake -i all > c:\src\build\log\m-command.txt
cd \src\cmd\attrib
nmake -i all > c:\src\build\log\m-attrib.txt
cd \src\cmd\assign
nmake -i all > c:\src\build\log\m-assign.txt
cd \src\cmd\chkdsk
nmake -i all > c:\src\build\log\m-chkdsk.txt
cd \src\cmd\debug
nmake -i all > c:\src\build\log\m-debug.txt
cd \src\cmd\edlin
nmake -i all > c:\src\build\log\m-edlin.txt
cd \src\cmd\exe2bin
nmake -i all > c:\src\build\log\m-exe2bin.txt
cd \src\cmd\find
nmake -i all > c:\src\build\log\m-find.txt
cd \src\cmd\fc
nmake -i all > c:\src\build\log\m-fc.txt
cd \src\cmd\format
nmake -i all > c:\src\build\log\m-format.txt
cd \src\cmd\join
nmake -i all > c:\src\build\log\m-join.txt
cd \src\cmd\more
nmake -i all > c:\src\build\log\m-more.txt
cd \src\cmd\print
nmake -i all > c:\src\build\log\m-print.txt
cd \src\cmd\recover
nmake -i all > c:\src\build\log\m-recover.txt
cd \src\cmd\sort
nmake -i all > c:\src\build\log\m-sort.txt
cd \src\cmd\subst
nmake -i all > c:\src\build\log\m-subst.txt
cd \src\cmd\sys
nmake -i all > c:\src\build\log\m-sys.txt
cd \src\cmd\share
nmake -i all > c:\src\build\log\m-share.txt
cd \src\cmd\nlsfunc
nmake -i all > c:\src\build\log\m-nlsfunc.txt
cd \src\cmd\ifsfunc
nmake -i all > c:\src\build\log\m-ifsfunc.txt
cd \src\cmd\mem
nmake -i all > c:\src\build\log\m-mem.txt
cd \src\cmd\filesys
nmake -i all > c:\src\build\log\m-filesys.txt
cd \src\cmd\backup
nmake -i all > c:\src\build\log\m-backup.txt
cd \src\cmd\comp
nmake -i all > c:\src\build\log\m-comp.txt
cd \src\cmd\diskcomp
nmake -i all > c:\src\build\log\m-diskcomp.txt
cd \src\cmd\diskcopy
nmake -i all > c:\src\build\log\m-diskcopy.txt
cd \src\cmd\fdisk
nmake -i all > c:\src\build\log\m-fdisk.txt
cd \src\cmd\label
nmake -i all > c:\src\build\log\m-label.txt
cd \src\cmd\mode
nmake -i all > c:\src\build\log\m-mode.txt
cd \src\cmd\restore
nmake -i all > c:\src\build\log\m-restore.txt
cd \src\cmd\tree
nmake -i all > c:\src\build\log\m-tree.txt
cd \src\cmd\replace
nmake -i all > c:\src\build\log\m-replace.txt
cd \src\cmd\xcopy
nmake -i all > c:\src\build\log\m-xcopy.txt
cd \src\cmd\graftabl
nmake -i all > c:\src\build\log\m-graftabl.txt
cd \src\cmd\fastopen
nmake -i all > c:\src\build\log\m-fastopen.txt
cd \src\cmd\append
nmake -i all > c:\src\build\log\m-append.txt
cd \src\cmd\graphics
nmake -i all > c:\src\build\log\m-graphics.txt
cd \src\cmd\keyb
nmake -i all > c:\src\build\log\m-keyb.txt
cd \src\dev\country
nmake -i all > c:\src\build\log\m-country.txt
cd \src\dev\ansi
nmake -i all > c:\src\build\log\m-ansi.txt
cd \src\dev\keyboard
nmake -i all > c:\src\build\log\m-keyboard.txt
cd \src\dev\display
nmake -i all > c:\src\build\log\m-display.txt
cd \src\dev\display\ega
nmake -i all > c:\src\build\log\m-ega.txt
cd \src\dev\display\lcd
nmake -i all > c:\src\build\log\m-lcd.txt
cd \src\dev\printer
nmake -i all > c:\src\build\log\m-printer.txt
cd \src\dev\printer\5202
nmake -i all > c:\src\build\log\m-5202.txt
cd \src\dev\driver
nmake -i all > c:\src\build\log\m-driver.txt
cd \src\dev\ramdrive
nmake -i all > c:\src\build\log\m-ramdrive.txt
cd \src\dev\smartdrv
nmake -i all > c:\src\build\log\m-smartdrv.txt
cd \src\dev\xma2ems
nmake -i all > c:\src\build\log\m-xma2ems.txt
cd \src\dev\vdisk
nmake -i all > c:\src\build\log\m-vdisk.txt
cd \src\dev\xmaem
nmake -i all > c:\src\build\log\m-xmaem.txt
cd \src\select
nmake -i select.exe select.com select.hlp > c:\src\build\log\m-select.txt
cd \src\memm\emm
nmake -i all > c:\src\build\log\m-emm.txt
cd \src\memm\memm
nmake -i all > c:\src\build\log\m-memm.txt
rem ---- done ----
exit
