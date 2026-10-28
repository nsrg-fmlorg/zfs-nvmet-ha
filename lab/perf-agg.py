#!/usr/bin/env python3
"""Fold the outputs of several lab/perf.sh runs into one table.

  perf-agg.py DIR...

Each DIR holds one run (config.txt, fio-*.json, stat-*).  Runs with the
same pool layout and checksum setting are grouped, and each figure is
given as median (min - max) over the runs, because single runs on a
shared CI runner varied by up to seven times.
"""
import json
import os
import statistics
import sys

PATHS = ["raw", "zvol", "zvol4k", "zvol4k-mq", "zfsfile", "loop-raw", "loop-zvol", "loop-zvol4k", "loop-zvol4k-mq", "lio-raw", "lio-zvol"]
JOBS = [("randwrite", "write", "kIOPS"), ("randread", "read", "kIOPS"),
        ("syncwrite", "write", "kIOPS"), ("seqread", "read", "MiB/s")]


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


def kstat(d, path, job, name):
    def val(when):
        for line in open(os.path.join(d, f"stat-{path}-{job}.{when}")):
            f = line.split()
            if len(f) == 3 and f[0] == name and f[2].isdigit():
                return int(f[2])
        return 0
    return val("after") - val("before")


def cell(values, fmt):
    m = statistics.median(values)
    return f"{m:{fmt}} ({min(values):{fmt}}-{max(values):{fmt}})"


groups = {}
for d in sys.argv[1:]:
    try:
        cfg = open(os.path.join(d, "config.txt")).read().split()
    except OSError:
        continue
    groups.setdefault(tuple(cfg), []).append(d)

for (layout, cksum), dirs in sorted(groups.items()):
    print(f"### pool {layout}, checksum {cksum}: {len(dirs)} runs, median (min-max)\n")
    print("| path | " + " | ".join(f"{j} {u}" for j, _, u in JOBS) + " | randwrite VM busy % | randwrite ZIL commits per 1k writes | randwrite disk writes per write | randwrite txgs |")
    print("|---|" + "---|" * (len(JOBS) + 4))
    for p in PATHS:
        try:
            cells = [cell([figure(d, p, j, s, u) for d in dirs], ".1f" if u == "kIOPS" else ".0f")
                     for j, s, u in JOBS]
            cells.append(cell([busy(d, p, "randwrite") for d in dirs], ".0f"))
            # zil_commit_count over the writes fio completed in the run
            per = []
            for d in dirs:
                w = json.load(open(os.path.join(d, f"fio-{p}-randwrite.json")))["jobs"][0]["write"]["total_ios"]
                per.append(1000.0 * kstat(d, p, "randwrite", "zil_commit_count") / max(w, 1))
            cells.append(cell(per, ".0f"))
            amp, txgs = [], []
            for d in dirs:
                w = json.load(open(os.path.join(d, f"fio-{p}-randwrite.json")))["jobs"][0]["write"]["total_ios"]
                amp.append(kstat(d, p, "randwrite", "zpool_write_ops") / max(w, 1))
                txgs.append(kstat(d, p, "randwrite", "txg_count"))
            cells.append(cell(amp, ".2f"))
            cells.append(cell(txgs, ".0f"))
        except (OSError, KeyError):
            continue
        print(f"| {p} | " + " | ".join(cells) + " |")
    print()
