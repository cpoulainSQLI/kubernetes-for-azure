"""Build a self-contained copy of a lesson for publishing.

Usage: python tools/inline.py lessons/0001-x.html build/0001-x.html [old_href=new_url ...]
Inlines ../assets/course.css and ../assets/quiz.js, and rewrites listed hrefs
(for example relative links to other lessons) to published artifact URLs.
"""
import sys, pathlib, re

src, dst, *maps = sys.argv[1:]
root = pathlib.Path(__file__).resolve().parent.parent
html = pathlib.Path(src).read_text(encoding="utf-8")
css = (root / "assets/course.css").read_text(encoding="utf-8")
js = (root / "assets/quiz.js").read_text(encoding="utf-8")
html = html.replace('<link rel="stylesheet" href="../assets/course.css">', "<style>\n" + css + "\n</style>")
html = html.replace('<script src="../assets/quiz.js"></script>', "<script>\n" + js + "\n</script>")
for m in maps:
    old, new = m.split("=", 1)
    html = html.replace('href="' + old + '"', 'href="' + new + '"')
out = pathlib.Path(dst); out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(html, encoding="utf-8")
print("built", out)
