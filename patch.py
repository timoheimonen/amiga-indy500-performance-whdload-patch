#!/usr/bin/env python3
# Indianapolis 500 WHDLoad Slave V1.0
# Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
# Licensed under the MIT License. See the LICENSE file for details.
"""Install Indianapolis 500 for WHDLoad from your own disk image.

    python3 patch.py DISK.ipf [--output Indy500] [--slave Indy500.slave]

The disk image is the IPF (SPS / CAPS) image of the original disk. Its
sectors are decoded and written as Disk.1. Only the Python standard library
is needed when Indy500.slave lies next to this script; in a source checkout
without it the slave is assembled with vasmm68k_mot. The disk image is read,
never changed; every output is new and is read back before success is
reported.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path
import struct
import subprocess
import zlib

HERE = Path(__file__).resolve().parent
SLAVE = 'Indy500.slave'
TRACKS, SECTORS, SECTOR = 160, 11, 512    # cylinder x 2 + side, AmigaDOS format
DISK_SIZE = TRACKS * SECTORS * SECTOR
# SHA-256 of the decoded sectors (Disk.1), not of the IPF file.
DISK_SHA256 = '3b0686e516934aabc35ff496c0e020d0e37fd4924a15106234f43188402aa08c'
SYNC = bytes.fromhex('44894489')
# A byte's bits moved to the even bit positions of a word.
SPREAD = [sum((byte >> bit & 1) << 2 * bit for bit in range(8)) for byte in range(256)]
# The icon's picture: '.' background (colour 0), 'k' black (1), 'w' white (2),
# 'b' blue (3) in the standard Workbench palette. A race car seen from above.
ICON_PICTURE = '''\
...........kkkk...........
.....kkkkkkkkkkkkkkkk.....
.....kkkkkkkkkkkkkkkk.....
...........bbbb...........
...kkk....bbbbbb....kkk...
...kkkbbbbbbbbbbbbbbkkk...
...kkk....bbwwbb....kkk...
..........bwkkwb..........
..........bbwwbb..........
..........bbbbbb..........
...kkk...bbbbbbbb...kkk...
...kkkbbbbbbbbbbbbbbkkk...
...kkk...bbbbbbbb...kkk...
...kkk...bbbbbbbb...kkk...
..........bbbbbb..........
.......kkkkkkkkkkkk.......
.......kkkkkkkkkkkk.......
..........................'''
# PRELOAD keeps the disk image in memory; NOWRITECACHE writes saves at once;
# WRITEDELAY=10 waits 0.2 s after a write instead of WHDLoad's 3 s default.
ICON_TOOLTYPES = ['PRELOAD', 'NOWRITECACHE', 'WRITEDELAY=10']


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def ipf_records(data: bytes):
    """The records of an IPF file as (type, fields, data area). Each record
    has a CRC-32 over itself (its CRC field as zero); a DATA record is
    followed by a data area with a CRC of its own."""
    if data[:4] != b'CAPS':
        raise ValueError('not an IPF image')
    pos = 0
    while pos < len(data):
        kind = data[pos:pos + 4]
        length, crc = struct.unpack('>II', data[pos + 4:pos + 12])
        if length < 12 or pos + length > len(data):
            raise ValueError('damaged IPF record')
        if zlib.crc32(data[pos:pos + 8] + bytes(4) + data[pos + 12:pos + length]) != crc:
            raise ValueError('IPF record checksum error')
        fields = struct.unpack(f'>{(length - 12) // 4}I', data[pos + 12:pos + length])
        pos += length
        area = b''
        if kind == b'DATA':
            area = data[pos:pos + fields[0]]
            if len(area) != fields[0] or zlib.crc32(area) != fields[2]:
                raise ValueError('IPF data checksum error')
            pos += fields[0]
        yield kind, fields, area


def block_elements(area: bytes, block: tuple) -> list[tuple[int, bytes]]:
    """The data stream of one block as (type, bytes): 1 sync (as MFM),
    2 data (before MFM encoding), 3 gap, 4 raw, 5 weak bits."""
    in_bits, pos, elements = block[5] & 4, block[7], []
    while area[pos]:
        width, kind = area[pos] >> 5, area[pos] & 31
        size = int.from_bytes(area[pos + 1:pos + 1 + width], 'big')
        if in_bits:
            size = (size + 7) // 8
        pos += 1 + width
        elements.append((kind, area[pos:pos + size]))
        pos += size
    return elements


def merge(stored: bytes) -> bytes:
    """AmigaDOS stores a field's odd bits first, then its even bits."""
    half = len(stored) // 2
    out = bytearray()
    for odd, even in zip(stored[:half], stored[half:]):
        out += (SPREAD[odd] << 1 | SPREAD[even]).to_bytes(2, 'big')
    return bytes(out)


def checksum(stored: bytes) -> bytes:
    """The AmigaDOS checksum of a field as it is stored: the exclusive or of
    the data bits of the field's MFM longs, 16 bits to a long, which has no
    odd bits."""
    value = 0
    for (word,) in struct.iter_unpack('>H', stored):
        value ^= word
    return struct.pack('>HH', 0, value)


def decode_ipf(data: bytes) -> bytes:
    """The 1760 sectors of an IPF image whose tracks 0-79 are all in the
    AmigaDOS format (11 sectors: sync, header, label, checksums, data)."""
    tracks, areas = {}, {}
    for kind, fields, area in ipf_records(data):
        if kind == b'IMGE':
            tracks[fields[0] * 2 + fields[1]] = fields
        elif kind == b'DATA':
            areas[fields[3]] = area
    disk = bytearray(DISK_SIZE)
    found = set()
    for track in range(TRACKS):
        image = tracks.get(track)
        if image is None or image[10] != SECTORS or image[13] not in areas:
            raise ValueError(f'track {track} is not an AmigaDOS track')
        area = areas[image[13]]
        for index in range(SECTORS):
            block = struct.unpack('>8I', area[index * 32:index * 32 + 32])
            elements = block_elements(area, block)
            stored = [content for kind, content in elements if kind == 2]
            if ([content for kind, content in elements if kind == 1] != [SYNC]
                    or len(stored) != 1 or len(stored[0]) != 28 + SECTOR):
                raise ValueError(f'track {track} is not an AmigaDOS track')
            stored = stored[0]
            info = merge(stored[:4])
            position = track * SECTORS + info[2]
            if info[0] != 0xFF or info[1] != track or info[2] >= SECTORS or position in found:
                raise ValueError(f'track {track}: unexpected sector header')
            if (stored[20:24] != checksum(stored[:20])
                    or stored[24:28] != checksum(stored[28:])):
                raise ValueError(f'track {track}: sector checksum error')
            found.add(position)
            disk[position * SECTOR:(position + 1) * SECTOR] = merge(stored[28:])
    return bytes(disk)


def verified_disk(path: Path) -> bytes:
    """The sectors of the supported disk, decoded from its IPF image."""
    data = path.read_bytes()
    if data[:4] != b'CAPS':
        raise ValueError(f'{path}: not an IPF image (ADF images are not supported)')
    try:
        disk = decode_ipf(data)
    except (IndexError, struct.error) as error:
        raise ValueError(f'{path}: damaged IPF image') from error
    except ValueError as error:
        raise ValueError(f'{path}: {error}') from error
    if sha(disk) != DISK_SHA256:
        raise ValueError(f'{path}: unsupported version of the game disk (SHA-256 of the '
                         f'sectors {sha(disk)})')
    return disk


def load_slave(path: Path | None) -> bytes:
    """The prebuilt slave, or one assembled from whdload/src."""
    candidate = path or HERE / SLAVE
    if candidate.is_file():
        data = candidate.read_bytes()
    elif path is None and (HERE / 'whdload/src/slave.s').is_file():
        # build.py appends the table of game addresses the slave relocates.
        spec = importlib.util.spec_from_file_location('indy500_build', HERE / 'whdload/build.py')
        build = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(build)
        data = build.assemble('vasmm68k_mot', interp=True, cpufill=True)
    else:
        raise ValueError(f'slave not found: {candidate}')
    if data[:4] != b'\0\0\x03\xf3' or b'WHDLOADS' not in data[:64]:
        raise ValueError(f'{candidate}: not a WHDLoad slave')
    return data


def icon_image() -> bytes:
    """The Image structure and both bit planes of the icons' picture."""
    rows = ICON_PICTURE.splitlines()
    width, height = len(rows[0]), len(rows)
    words = (width + 15) // 16
    planes = []
    for plane in (1, 2):
        data = bytearray()
        for row in rows:
            bits = 0
            for x in range(words * 16):
                colour = '.kwb'.index(row[x]) if x < width else 0
                bits = bits << 1 | (colour & plane != 0)
            data += bits.to_bytes(words * 2, 'big')
        planes.append(bytes(data))
    return struct.pack('>hhhhhIBBI', 0, 0, width, height, 2, 1, 3, 0, 0) + b''.join(planes)


def disk_object(kind: int, *, tool: bool, drawer: bool, stack: int) -> bytes:
    """A DiskObject whose gadget shows icon_image() and is placed by Workbench."""
    rows = ICON_PICTURE.splitlines()
    no_position = 0x80000000
    return struct.pack(
        '>HH' 'IhhhhHHH' 'IIIIIHI' 'BB' 'IIIIIII',
        0xE310, 1,                                  # magic, version
        0, 0, 0, len(rows[0]), len(rows) + 1, 4, 3, 1,  # gadget: size, image, boolean
        1, 0, 0, 0, 0, 0, 0,                        # gadget render image only
        kind, 0,
        int(tool), int(tool), no_position, no_position, int(drawer), 0, stack)


def icon(slave_name: str) -> bytes:
    """A Workbench project icon whose default tool is WHDLoad."""

    def string(text: str) -> bytes:
        data = text.encode('ascii') + b'\0'
        return struct.pack('>I', len(data)) + data

    tooltypes = [f'SLAVE={slave_name}'] + ICON_TOOLTYPES
    return (disk_object(4, tool=True, drawer=False, stack=10240)       # WBPROJECT
            + icon_image() + string('WHDLoad')
            + struct.pack('>I', (len(tooltypes) + 1) * 4) + b''.join(string(t) for t in tooltypes))


def drawer_icon() -> bytes:
    """The drawer icon written beside the install directory, so that Workbench
    shows the drawer without Show all files."""
    window = struct.pack('>hhhhBBIIIIIIIhhHHH',
                         80, 40, 220, 90, 255, 255,  # position, size, default pens
                         0, 0, 0, 0, 0, 0, 0,        # no IDCMP, flags, gadgets, title
                         0, 0, 0, 0, 1)              # no size limits, WBENCHSCREEN
    return (disk_object(2, tool=False, drawer=True, stack=0)          # WBDRAWER
            + window + struct.pack('>ii', 0, 0) + icon_image())


def publish(root: Path, files: dict[str, bytes], drawer: bytes) -> None:
    """Create the new directory, its files and the drawer icon beside it, and
    read every file back. On failure everything created here is removed."""
    beside = root.parent / (root.name + '.info')
    for path in (root, beside):
        if path.exists() or path.is_symlink():
            raise ValueError('output must not exist yet: ' + str(path))
    outputs = [(root / name, data) for name, data in files.items()] + [(beside, drawer)]
    created: list[Path] = []
    try:
        root.mkdir()
        for path, data in outputs:
            with path.open('xb') as stream:
                created.append(path)
                stream.write(data)
            if path.read_bytes() != data:
                raise OSError('output readback differs: ' + path.name)
    except Exception:
        for path in reversed(created):
            path.unlink(missing_ok=True)
        try:
            root.rmdir()
        except OSError:
            pass
        raise


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog='patch.py', description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('disk', type=Path, help='IPF image of the original disk')
    parser.add_argument('--output', type=Path, default=Path('Indy500'),
                        help='new install directory (default: Indy500)')
    parser.add_argument('--slave', type=Path, help='prebuilt Indy500.slave')
    args = parser.parse_args(argv)
    try:
        # Every input is checked before any output is created.
        disk = verified_disk(args.disk)
        files = {SLAVE: load_slave(args.slave), 'Indy500.info': icon(SLAVE), 'Disk.1': disk}
        publish(args.output, files, drawer_icon())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, 'Error: ' + str(error) + '\n')
    print('Created ' + str(args.output.resolve()) + ' and its drawer icon '
          + args.output.name + '.info')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
