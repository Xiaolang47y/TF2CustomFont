#!/usr/bin/env python3
"""
Sanity check for the generated templates.

It simulates the engine's #base merge (KeyValues::MergeBaseKeys) and asserts
that every font glyph-set that should be replaced ends up pointing at the
replacement family while everything else is still inherited from the base.

Usage:
    python3 tools/dev/verify.py
"""

from __future__ import annotations

import copy
import os
import sys

sys.dont_write_bytecode = True

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from importlib import import_module

bt = import_module("build-templates")

ROOT = bt.ROOT
NAME = "DejaVu Sans"
FILE = "resource/customfont.ttf"


def load(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return bt.parse(bt.tokenize(fh.read()))


def merge(base, cur):
    """Mirror KeyValues::RecursiveMergeKeyValues: both sides win over base."""
    if not base.is_block or not cur.is_block:
        return
    for bc in base.children:
        match = None
        for cc in cur.children:
            if cc.name == bc.name:
                match = cc
                break
        if match is not None:
            merge(bc, match)
        else:
            cur.children.append(copy.deepcopy(bc))


def find(node, name):
    for c in node.children:
        if c.name.lower() == name.lower():
            return c
    return None


def main():
    failures = []

    jobs = [
        ("clientscheme", bt.SKIP_FONTS),
        ("chatscheme", {"Marlett", "MarlettSmall"}),
    ]
    for scheme, skips in jobs:
        base = load(os.path.join(ROOT, "tools", "base", scheme + ".res"))
        tpl_text = open(os.path.join(ROOT, "tools", "template", scheme + ".res"),
                        "r", encoding="utf-8").read()
        tpl_text = tpl_text.replace("__CUSTOM_FONT_NAME__", NAME).replace("__CUSTOM_FONT_FILE__", FILE)
        tpl = bt.parse(bt.tokenize(tpl_text))

        merged = copy.deepcopy(tpl)
        merge(base, merged)

        base_fonts = find(find(base, "Scheme"), "Fonts")
        merged_fonts = find(find(merged, "Scheme"), "Fonts")
        if merged_fonts is None:
            failures.append("%s: Fonts section lost" % scheme)
            continue

        merged_by_name = {}
        for f in merged_fonts.children:
            merged_by_name.setdefault(f.name, []).append(f)

        overridden = 0
        for font in base_fonts.children:
            if not font.is_block:
                continue
            candidates = merged_by_name.get(font.name, [])
            if not candidates:
                failures.append("%s: font %s disappeared" % (scheme, font.name))
                continue
            for block in [b for b in font.children if b.is_block]:
                mblocks = [b for b in candidates[0].children if b.is_block and b.name == block.name]
                if not mblocks:
                    failures.append("%s: %s/%s disappeared" % (scheme, font.name, block.name))
                    continue
                name_node = find(mblocks[0], "name")
                got = name_node.value if name_node else None
                if font.name in skips:
                    base_name = find(block, "name")
                    if got != (base_name.value if base_name else None):
                        failures.append("%s: skipped font %s was modified" % (scheme, font.name))
                else:
                    if got != NAME:
                        failures.append("%s: %s/%s name = %r" % (scheme, font.name, block.name, got))
                    else:
                        overridden += 1

        # colors / borders / custom font files must survive
        for section in ("Colors", "Borders", "BaseSettings", "CustomFontFiles"):
            b = find(find(base, "Scheme"), section)
            m = find(find(merged, "Scheme"), section)
            if b is not None and (m is None or len(m.children) < len(b.children)):
                failures.append("%s: section %s was damaged" % (scheme, section))

        cf = find(find(merged, "Scheme"), "CustomFontFiles")
        entry = next((c for c in cf.children if c.name == bt.CUSTOM_FONT_ID), None)
        if entry is None or find(entry, "name").value != NAME or find(entry, "font").value != FILE:
            failures.append("%s: CustomFontFiles entry missing/broken" % scheme)

        print("%-14s %3d glyph-sets overridden" % (scheme, overridden))

    # The shipped (already expanded) files must also be parseable.
    deployed = os.path.join(ROOT, "tf", "custom", "!000_customfont", "resource")
    for scheme in ("clientscheme", "chatscheme"):
        path = os.path.join(deployed, scheme + ".res")
        if not os.path.exists(path):
            continue
        text = open(path, "r", encoding="utf-8", errors="replace").read()
        if "__CUSTOM_FONT" in text:
            failures.append("%s.res still contains placeholders" % scheme)
        try:
            bt.parse(bt.tokenize(text))
        except Exception as exc:
            failures.append("%s.res does not parse: %s" % (scheme, exc))
        print("%-14s deployed file parsed" % scheme)

    if failures:
        print("\nFAILED")
        for f in failures:
            print("  -", f)
        return 1
    print("\nOK: #base merge produces the expected result")
    return 0


if __name__ == "__main__":
    sys.exit(main())
