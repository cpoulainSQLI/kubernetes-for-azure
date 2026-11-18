#!/usr/bin/env python3
"""Builds the lab sheet of each chapter: courses/<course>/chapters/NN-name/lab-sheet.html.

A lab sheet is the Lab section and the Clean up section of the chapter page, alone on
one compact page, for a second screen or for printing. It is generated, so the chapter
page stays the only place where the lab is written. Never edit a lab sheet by hand.

Run from anywhere:  python3 scripts/build-lab-sheets.py
scripts/check-course.py fails when a lab sheet no longer matches its chapter page.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

TEMPLATE = """<!DOCTYPE html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lab sheet, {short} | Kubernetes, hands-on</title>
<link rel="stylesheet" href="{root}assets/course.css">
<script src="{root}assets/search-index.js" defer></script>
<script src="{root}assets/course.js" defer></script>
</head>
<body class="sheet" data-root="{root}" data-page="{page}">
<a class="skip-link" href="#main">Skip to the content</a>
<header class="site-header" id="site-header"><a class="brand" href="{root}index.html">Kubernetes, hands-on</a></header>
<div class="layout">
<nav class="site-nav" id="site-nav" aria-label="Course"><a href="../../index.html">Course home</a></nav>
<main id="main" class="content">
<nav class="breadcrumb" aria-label="Breadcrumb"><a href="../../index.html">{course}</a> / <a href="index.html">{title}</a></nav>
<h1 id="lab-sheet">Lab sheet, {short}</h1>
<p class="lede">The lab of <a href="index.html">{title_lower}</a> on one page: tasks, acceptance criteria, commands and clean-up. The explanations are in the chapter. This page is generated from it.</p>
{block}</main>
<aside class="page-toc" id="page-toc" aria-label="On this page"></aside>
</div>
<footer class="site-footer" id="site-footer"></footer>
</body>
</html>
"""


def chapter_pages():
    return sorted(ROOT.glob("courses/*/chapters/*/index.html"))


def sheet_path(page):
    return page.parent / "lab-sheet.html"


def render(page):
    """Returns the lab sheet of a chapter page as text."""
    text = page.read_text(encoding="utf-8")
    title = re.search(r"<h1[^>]*>(.*?)</h1>", text, re.S).group(1).strip()
    short = title.split(":")[0].strip().lower()
    block = text[text.index('<h2 id="lab">'):text.index('<h2 id="sources">')]
    block = re.sub(r'<p class="sheet-link">.*?</p>\n', "", block, flags=re.S)
    own_ids = set(re.findall(r'\bid="([^"]+)"', block))

    def anchor(match):
        # A link to a section that is not on the sheet goes to the chapter page.
        if match.group(1) in own_ids:
            return match.group(0)
        return f'href="index.html#{match.group(1)}"'

    block = re.sub(r'href="#([^"]+)"', anchor, block)
    page_path = sheet_path(page).relative_to(ROOT).as_posix()
    course_home = (page.parent.parent.parent / "index.html").read_text(encoding="utf-8")
    course = re.search(r"<h1[^>]*>(.*?)</h1>", course_home, re.S).group(1).strip()
    return TEMPLATE.format(
        root="../" * page_path.count("/"),
        course=course,
        short=short,
        title=title,
        title_lower=title[0].lower() + title[1:],
        page=page_path,
        block=block,
    )


def main():
    for page in chapter_pages():
        sheet_path(page).write_text(render(page), encoding="utf-8", newline="\n")
    print(f"Wrote {len(chapter_pages())} lab sheets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
