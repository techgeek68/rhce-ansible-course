#!/usr/bin/env python3
"""Fails if any relative Markdown link points to a missing file or heading.

Run from anywhere:  python3 tools/check_links.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def anchors(path):
    found = set()
    for line in path.read_text().splitlines():
        if line.startswith("#"):
            text = line.lstrip("#").strip().lower()
            text = re.sub(r"[^\w\- ]", "", text).replace(" ", "-")
            found.add(text)
    return found


def main():
    errors = []
    for page in sorted(ROOT.rglob("*.md")):
        if ".git" in page.parts:
            continue
        in_code = False
        for number, line in enumerate(page.read_text().splitlines(), start=1):
            if line.lstrip().startswith("```"):
                in_code = not in_code
                continue
            if in_code:
                continue
            for target in LINK_RE.findall(line):
                if re.match(r"^[a-z]+://|^mailto:", target):
                    continue
                path_part, _, anchor = target.partition("#")
                dest = (page.parent / path_part).resolve() if path_part else page
                if not dest.exists():
                    errors.append(f"{page.relative_to(ROOT)}:{number}: missing {target}")
                elif anchor and dest.suffix == ".md" and anchor not in anchors(dest):
                    errors.append(f"{page.relative_to(ROOT)}:{number}: missing heading #{anchor}")
    for error in errors:
        print(error)
    print(f"{len(errors)} broken links")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
