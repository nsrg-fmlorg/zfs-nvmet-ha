#!/usr/bin/env python3
"""Run every ```sh <where> block of MANUAL.md, in order.

  run-manual.py MANUAL.md

<where> is ctl-a, ctl-b, host (as root there, over "ssh <where>"),
both (ctl-a, then ctl-b) or admin (here, with the repository root as
the current directory).  Stops at the first block that fails.
"""
import re
import subprocess
import sys

text = open(sys.argv[1]).read()
blocks = re.findall(r"^```sh (\S+)\n(.*?)^```$", text, re.M | re.S)
if not blocks:
    sys.exit("no sh blocks found")
for i, (where, body) in enumerate(blocks, 1):
    nodes = ["ctl-a", "ctl-b"] if where == "both" else [where]
    for n in nodes:
        print(f"--- block {i} on {n}", flush=True)
        if n == "admin":
            cmd = ["sh", "-eux"]
        elif n in ("ctl-a", "ctl-b", "host"):
            cmd = ["ssh", n, "sudo", "sh", "-eux"]
        else:
            sys.exit(f"block {i}: unknown place {where}")
        r = subprocess.run(cmd, input=body, text=True)
        if r.returncode:
            sys.exit(f"block {i} on {n} failed: {r.returncode}")
print(f"ran {len(blocks)} blocks")
