#!/usr/bin/env python3
# Indianapolis 500 WHDLoad Slave V1.1
# Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
# Licensed under the MIT License. See the LICENSE file for details.
"""Build the Indianapolis 500 WHDLoad slave and an install directory.

Usage: python3 whdload/build.py [IPF] [-o OUTPUT_DIR] [--hd HD_DIR] [--interp] [--cpufill] [--vasm PATH]
       python3 whdload/build.py --check [--vasm PATH]

The install directory gets Indy500.slave and Disk.1 (the sectors of the
supported disk, decoded from its IPF image by patch.py). Without options the
slave is the plain one (the game from a hard drive, 68000 code); --interp
adds the frames between the simulation steps and --cpufill the view drawn by
the CPU, and both together are the slave that patch.py installs. With --hd a
bootable WHDLoad hard disk directory for Amiberry is written as well: the
boot files and WHDLoad from an Amiberry tree beside this one and a
startup-sequence that starts the game. --check assembles the four builds
(plain, --interp, --cpufill, both) and writes nothing.
"""
from __future__ import annotations

import argparse
import importlib.util
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
AMIBERRY = ROOT.parent / "amiberry-8.3.0"    # an Amiberry tree beside this one, for --hd
INSTALL_NAME = "Indy500"
TOOLTYPES = "PRELOAD NOWRITECACHE WRITEDELAY=10"  # as in the patch.py icon


GAME_BASE = 0xC00000      # main program layout the sources are written for
PROBE_BASE = 0xD00000     # second build that shows which longs depend on it
HEADER = 32               # hunk header of a one-hunk executable up to the code


def _vasm(vasm: str, defines: list[str]) -> bytes:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "Indy500.slave"
        subprocess.run([vasm, "-m68000", "-Fhunkexe", "-nosym", "-quiet", *defines,
                        "-I", str(HERE / "src"), "-o", str(out), str(HERE / "src/slave.s")],
                       check=True)
        return out.read_bytes()


def assemble(vasm: str, interp: bool = False, cpufill: bool = False) -> bytes:
    """Assemble the slave and append its game_refs table.

    The slave is assembled for GAME_BASE and again for PROBE_BASE. Every long
    that differs by exactly the difference is a game address; their offsets
    from the start of the code are appended as a zero terminated word list
    at the end of the code (the game_refs label), where the slave reads them.
    """
    defines = (["-DINTERP=1"] if interp else []) + (["-DCPUFILL=1"] if cpufill else [])
    a = _vasm(vasm, defines + [f"-DGAME_BASE=${GAME_BASE:X}"])
    b = _vasm(vasm, defines + [f"-DGAME_BASE=${PROBE_BASE:X}"])
    if b"\x00\x00\x03\xec" in a:
        raise SystemExit("the slave must not contain relocations")
    words = struct.unpack(">8I", a[:HEADER])
    if (words[:5] != (0x3F3, 0, 1, 0, 0) or words[6] != 0x3E9 or words[5] != words[7]
            or len(a) != len(b) or len(a) != HEADER + words[5] * 4 + 4):
        raise SystemExit("unexpected slave hunk layout")
    code_a, code_b = a[HEADER:-4], b[HEADER:-4]
    refs, offset = [], 0
    while offset < len(code_a):
        if code_a[offset:offset + 2] != code_b[offset:offset + 2]:  # high word of the long
            va = struct.unpack(">I", code_a[offset:offset + 4])[0]
            vb = struct.unpack(">I", code_b[offset:offset + 4])[0]
            if (vb - va) & 0xFFFFFFFF != PROBE_BASE - GAME_BASE:
                raise SystemExit(f"slave offset ${offset:X}: not a game address")
            refs.append(offset)
            offset += 4
        else:
            offset += 2
    # The cpufill slave reads the offsets unsigned, the others signed.
    if any(r > (0xFFFF if cpufill else 0x7FFF) for r in refs):
        raise SystemExit("game_refs offsets must fit in a word")
    table = struct.pack(f">{len(refs) + 1}H", *refs, 0)
    table += bytes(-len(table) % 4)
    code = code_a + table
    size = len(code) // 4
    return (struct.pack(">8I", 0x3F3, 0, 1, 0, 0, size, 0x3E9, size)
            + code + struct.pack(">I", 0x3F2))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("ipf", nargs="?", type=Path, default=ROOT / "original/Indianapolis500.ipf")
    ap.add_argument("-o", "--output", type=Path, default=ROOT / "build")
    ap.add_argument("--hd", type=Path, help="also write a bootable HD directory")
    ap.add_argument("--vasm", default="vasmm68k_mot")
    ap.add_argument("--interp", action="store_true",
                    help="render interpolated frames between simulation steps")
    ap.add_argument("--cpufill", action="store_true",
                    help="fill polygons with the CPU instead of the blitter")
    ap.add_argument("--check", action="store_true",
                    help="assemble the four builds and write nothing")
    args = ap.parse_args()

    if args.check:
        for interp, cpufill in ((False, False), (True, False), (False, True), (True, True)):
            flags = [f for f, on in (("--interp", interp), ("--cpufill", cpufill)) if on]
            slave = assemble(args.vasm, interp, cpufill)
            print(f"{' '.join(flags) or 'plain'}: {len(slave)} bytes")
        return

    spec = importlib.util.spec_from_file_location("indy500_patch", ROOT / "patch.py")
    patch = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(patch)
    try:
        disk = patch.verified_disk(args.ipf)
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
    slave = assemble(args.vasm, args.interp, args.cpufill)

    targets = [args.output]
    if args.hd:
        if args.hd.exists():
            shutil.rmtree(args.hd)
        args.hd.mkdir(parents=True)
        with zipfile.ZipFile(AMIBERRY / "whdboot/boot-data.zip") as archive:
            archive.extractall(args.hd)
        shutil.copyfile(AMIBERRY / "whdboot/WHDLoad", args.hd / "C/WHDLoad")
        (args.hd / "S").mkdir(exist_ok=True)
        (args.hd / "S/startup-sequence").write_text(
            f"cd DH0:{INSTALL_NAME}\nWHDLoad {INSTALL_NAME}.slave {TOOLTYPES}\n")
        targets.append(args.hd / INSTALL_NAME)
    for target in targets:
        target.mkdir(parents=True, exist_ok=True)
        (target / f"{INSTALL_NAME}.slave").write_bytes(slave)
        (target / "Disk.1").write_bytes(disk)
        print(f"{target}: {INSTALL_NAME}.slave ({len(slave)} bytes), Disk.1")


if __name__ == "__main__":
    main()
