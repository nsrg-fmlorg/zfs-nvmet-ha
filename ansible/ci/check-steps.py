#!/usr/bin/env python3
"""Fail when site.yml's steps and MANUAL.md's steps differ.

  check-steps.py site.yml MANUAL.md

site.yml marks each step with a "# Step N. Title" comment, MANUAL.md
with a "## Step N. Title" heading; both lists must be the same, in the
same order.
"""
import re
import sys

play = re.findall(r"^\s*# (Step \d+\. .+)$", open(sys.argv[1]).read(), re.M)
manual = re.findall(r"^## (Step \d+\. .+)$", open(sys.argv[2]).read(), re.M)
if not play:
    sys.exit("no steps in " + sys.argv[1])
if play != manual:
    for a, b in zip(play + [""] * len(manual), manual + [""] * len(play)):
        if a != b:
            print(f"playbook: {a!r}\nmanual:   {b!r}")
            break
    sys.exit("site.yml and MANUAL.md disagree on the steps")
print(f"{len(play)} steps agree")
