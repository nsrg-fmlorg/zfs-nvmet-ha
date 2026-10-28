#!/usr/bin/env python3
"""Fold one or more lab/spdk.sh outputs into a table.

  spdk-agg.py DIR...

Each DIR holds one run (fio-<path>-<job>.json, stat-<path>-<job>.{before,after}).
Every figure is median (min-max) over the runs given: single runs on a
shared CI runner varied by up to seven times.
"""
import json
import os
import statistics
import sys

PATHS = ["k-raw", "s-null", "s-raw", "k-zvol", "s-zvol"]
JOBS = [("randread", "read", "kIOPS"), ("randwrite", "write", "kIOPS"),
        ("syncwrite", "write", "us p50"), ("seqread", "read", "MiB/s")]


def figure(d, path, job, side, unit):
    r = json.load(open(os.path.join(d, f"fio-{path}-{job}.json")))["jobs"][0][side]
    if unit == "kIOPS":
        return r["iops"] / 1000
    if unit == "MiB/s":
        return r["bw"] / 1024
    return r["clat_ns"]["percentile"]["50.000000"] / 1000


def busy(d, path, job):
    def cpu(when):
        line = open(os.path.join(d, f"stat-{path}-{job}.{when}")).readline()
        return [int(x) for x in line.split()[1:]]
    delta = [b - a for a, b in zip(cpu("before"), cpu("after"))]
    return 100.0 * (sum(delta) - delta[3] - delta[4]) / sum(delta)


def cell(values, fmt):
    m = statistics.median(values)
    return f"{m:{fmt}} ({min(values):{fmt}}-{max(values):{fmt}})"


dirs = [d for d in sys.argv[1:] if os.path.isdir(d)]
print(f"### SPDK nvmf_tgt (1 core) vs kernel nvmet over NVMe/TCP on 127.0.0.1: {len(dirs)} runs, median (min-max)\n")
print("| path | " + " | ".join(f"{j} {u}" for j, _, u in JOBS) + " | randread VM busy % |")
print("|---|" + "---|" * (len(JOBS) + 1))
for p in PATHS:
    try:
        cells = [cell([figure(d, p, j, s, u) for d in dirs], ".1f" if u == "kIOPS" else ".0f")
                 for j, s, u in JOBS]
        cells.append(cell([busy(d, p, "randread") for d in dirs], ".0f"))
    except (OSError, KeyError, ValueError, statistics.StatisticsError):
        continue
    print(f"| {p} | " + " | ".join(cells) + " |")
