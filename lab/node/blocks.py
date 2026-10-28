#!/usr/bin/env python3
"""Write numbered blocks with O_DIRECT|O_DSYNC, or verify them.

  blocks.py write <dev>    write block 0, 1, 2, ... until killed; print
                           each index only after the write has returned,
                           so every printed index was acknowledged
  blocks.py verify <dev> <last>
                           check blocks 0..last carry their own index

Each 4 KiB block holds a header with the index and a SHA-256 of a body
derived from the index, so a stale or torn block cannot pass.
"""
import hashlib
import mmap
import os
import struct
import sys
import time

BS = 4096
MAGIC = b"ZNHA"


def block(i):
    body = hashlib.sha256(b"%d" % i).digest() * ((BS - 48) // 32)
    hdr = MAGIC + struct.pack("<Q", i) + hashlib.sha256(body).digest()
    return (hdr + body).ljust(BS, b"\0")


def write(dev):
    fd = os.open(dev, os.O_WRONLY | os.O_DIRECT | os.O_DSYNC)
    buf = mmap.mmap(-1, BS)
    i = 0
    while True:
        buf.seek(0)
        buf.write(block(i))
        os.pwrite(fd, buf, i * BS)
        # monotonic: the guest's wall clock may be stepped mid-run
        print(i, "%.3f" % time.monotonic(), flush=True)
        i += 1


def verify(dev, last):
    fd = os.open(dev, os.O_RDONLY | os.O_DIRECT)
    buf = mmap.mmap(-1, BS)
    bad = []
    for i in range(last + 1):
        os.preadv(fd, [buf], i * BS)
        if bytes(buf) != block(i):
            bad.append(i)
    print("verified 0..%d, %d bad%s" % (last, len(bad),
          (": " + " ".join(map(str, bad[:20]))) if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    if sys.argv[1] == "write":
        write(sys.argv[2])
    else:
        sys.exit(verify(sys.argv[2], int(sys.argv[3])))
