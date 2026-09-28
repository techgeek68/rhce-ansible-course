#!/usr/bin/env python3
"""Adds or refreshes navigation links in every course page.

Study order is taken from the file system:
  * chapter directories are the top level directories named NN_something, in order;
  * inside a chapter, README.md (the lesson) comes first, then NN_*.md files in order.

Run from the repository root after adding or renaming any page:
    python3 tools/build_nav.py
The script is idempotent: it only rewrites the blocks between its own markers,
and it regenerates the course contents table in the root README.md.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HEAD_START, HEAD_END = "<!-- nav:start -->", "<!-- nav:end -->"
FOOT_START, FOOT_END = "<!-- navfoot:start -->", "<!-- navfoot:end -->"
TOC_START, TOC_END = "<!-- toc:start -->", "<!-- toc:end -->"
CHAPTER_RE = re.compile(r"^\d\d_[a-z0-9_]+$")
PAGE_RE = re.compile(r"^\d\d_[a-z0-9_]+\.md$")


def title_of(path):
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem


def kind_of(path):
    name = path.name
    if name == "README.md":
        return "Lesson"
    if "guided_exercise" in name:
        return "Guided exercise"
    if name.endswith("_quiz.md"):
        return "Quiz"
    if name.endswith("_lab_solution.md"):
        return "Lab solution"
    if name.endswith("_lab.md"):
        return "Graded lab"
    return "Guide"


def course_pages():
    chapters = sorted(p for p in ROOT.iterdir() if p.is_dir() and CHAPTER_RE.match(p.name))
    pages = []
    for chapter in chapters:
        readme = chapter / "README.md"
        if not readme.exists():
            sys.exit(f"{chapter.name} has no README.md")
        pages.append(readme)
        pages.extend(sorted(p for p in chapter.iterdir() if PAGE_RE.match(p.name)))
    return chapters, pages


def strip_block(text, start, end):
    return re.sub(rf"\n*{re.escape(start)}.*?{re.escape(end)}\n*", "\n", text, flags=re.S).strip("\n")


def rel(src, dst):
    if src.parent == dst.parent:
        return dst.name
    return f"../{dst.parent.name}/{dst.name}"


def build_navigation(chapters, pages):
    for index, page in enumerate(pages):
        chapter = page.parent
        siblings = [p for p in pages if p.parent == chapter]
        position = siblings.index(page) + 1
        chapter_title = title_of(chapter / "README.md")
        head = (
            f"{HEAD_START}\n"
            f"[Course home](../README.md) › [{chapter_title}](README.md) › "
            f"{kind_of(page)} ({position} of {len(siblings)})\n"
        )
        if page.name == "README.md" and len(siblings) > 1:
            head += "\n**Pages in this chapter, in study order:**\n\n"
            for step, sibling in enumerate(siblings, start=1):
                label = "this page" if sibling == page else f"[{title_of(sibling)}]({sibling.name})"
                head += f"{step}. {kind_of(sibling)}: {label}\n"
        head += HEAD_END
        links = []
        if index > 0:
            prev = pages[index - 1]
            links.append(f"← Previous: [{title_of(prev)}]({rel(page, prev)})")
        if index + 1 < len(pages):
            nxt = pages[index + 1]
            links.append(f"Next: [{title_of(nxt)}]({rel(page, nxt)}) →")
        else:
            links.append("You have reached the last published page. [Back to the course home](../README.md)")
        foot = f"{FOOT_START}\n\n---\n\n" + " | ".join(links) + f"\n\n{FOOT_END}"
        body = page.read_text()
        body = strip_block(body, HEAD_START, HEAD_END)
        body = strip_block(body, FOOT_START, FOOT_END)
        page.write_text(f"{head}\n\n{body}\n\n{foot}\n")


def build_toc(chapters, pages):
    lines = [TOC_START, ""]
    for chapter in chapters:
        lines.append(f"### [{title_of(chapter / 'README.md')}]({chapter.name}/README.md)")
        lines.append("")
        lines.append("| Step | Type | Page |")
        lines.append("|---|---|---|")
        for step, page in enumerate([p for p in pages if p.parent == chapter], start=1):
            lines.append(f"| {step} | {kind_of(page)} | [{title_of(page)}]({chapter.name}/{page.name}) |")
        lines.append("")
    lines.append(TOC_END)
    readme = ROOT / "README.md"
    text = readme.read_text()
    if TOC_START not in text:
        sys.exit("README.md has no toc markers")
    text = re.sub(rf"{re.escape(TOC_START)}.*?{re.escape(TOC_END)}", "\n".join(lines), text, flags=re.S)
    readme.write_text(text)


if __name__ == "__main__":
    chapters, pages = course_pages()
    build_navigation(chapters, pages)
    build_toc(chapters, pages)
    print(f"Navigation refreshed on {len(pages)} pages in {len(chapters)} chapters")
