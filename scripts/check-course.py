#!/usr/bin/env python3
"""Checks of the website that linters do not cover. Run from anywhere:

    python3 scripts/check-course.py

Checks:
  1. Writing rules in the text of every page: no em or en dash, no semicolon,
     no bold, no "eg" in brackets, no filler words, sentence-case headings.
  2. Page template, internal links and anchors (including the navigation in
     assets/course.js), alternative text of images, and platform tabs.
  3. No subscription or tenant ID (any GUID except built-in role IDs), public IP
     address, e-mail address or secret in any file, and no file of the lab kit,
     old script path or mention of the former hosting left in the site.
  4. The Terraform of the hosting (infra/) tags every resource with local.tags,
     and never with the course tag of the kit.
  5. The search index and the lab sheets are up to date.
  6. Cross-checks against a checkout of the lab kit, found through KIT_DIR, or else in
     the sibling folder kubernetes-for-azure-labs:
       - the stages of each validator match the tasks of its chapter page, and the page
         presents --guided, --deep and the broken lab with its --restore option,
       - every course command that a page shows exists in the kit, with its lab and options,
       - every data-kit path of a page exists in the kit.

Optional: PRIVATE_TERMS="name one,name two" also searches for terms that must
never appear in the course. Never write those terms in a file of the course.
Only the Python standard library is needed. Exit code 0 when no error is found, 1 otherwise.
"""
import importlib.util
import ipaddress
import os
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KIT = Path(os.environ.get("KIT_DIR") or ROOT.parent / "kubernetes-for-azure-labs").resolve()
ARCHIVED = ("archive/lessons/", "archive/reference/", "archive/assets/", "archive/tools/")
# Names the checks leave alone: tool folders, and what Git ignores on the author's machine. These are the local
# notes, the agent instructions and .claude, where a coding agent keeps its settings and its working copies.
# .terraform holds the providers that terraform init downloads when the checks run, and _site the pages that
# the deployment collects.
SKIP_NAMES = {".git", "node_modules", "handoff", "CLAUDE.md", "CLAUDE.local.md", ".claude", ".terraform", "_site"}
TEXT_SUFFIXES = {".md", ".html", ".tf", ".hcl", ".yaml", ".yml", ".py", ".css", ".js", ".json", ""}
PLATFORMS = {"windows", "macos", "linux"}

# IDs of Azure built-in roles: identical in every tenant, so they are not personal data.
ALLOWED_GUIDS = {
    "b24988ac-6180-42a0-ab88-20f7382dd24c",  # Contributor
    "8311e382-0749-4cb8-b61a-304f252e45ec",  # AcrPush
}
FILLER_WORDS = ["robust", "seamless", "seamlessly", "tailored", "foster", "fostering", "genuinely", "leverage", "delve", "crucial"]
PROPER_PHRASES = [
    "Azure Red Hat OpenShift", "Azure Container Registry", "Azure Kubernetes Service", "Azure Bastion",
    "Azure Static Web Apps", "Static Web Apps", "GitHub Actions",
    "Red Hat", "Microsoft Learn", "Microsoft Entra ID", "Docker Hub", "Docker Engine", "Visual Studio", "VS Code",
    "Developer Sandbox", "Open Container Initiative", "Network Watcher", "Git Bash", "Windows PowerShell",
]
PROPER_WORDS = {
    "Azure", "Kubernetes", "OpenShift", "Docker", "Dockerfile", "Microsoft", "Terraform", "HashiCorp", "Ubuntu", "Go", "Git",
    "GitHub", "Bash", "PowerShell", "Podman", "Entra", "Linux", "Windows", "macOS", "AKS", "ARO", "ACR", "Helm",
    "NodePort", "ClusterIP", "LoadBalancer", "ReplicaSet", "ReplicaSets", "Deployment", "Deployments",
    "Service", "Services", "Pod", "Pods", "EndpointSlice", "EndpointSlices", "Namespace", "Namespaces",
}
# Paths of the course before the lab kit had its own repository. A page shows course commands instead.
STALE_PATHS = [r"~/aro-k8s-course/", r"\bchapters/\d\d-[a-z0-9-]+/lab/", r"\bscripts[/\\]lab-vm", r"\bchapters\\\d\d-", r"\blab-vm\.(sh|ps1)\b"]
# Files that belong to the lab kit, never to the website.
KIT_SUFFIXES = {".sh", ".ps1", ".psd1", ".go", ".mod"}
FORMER_HOSTING = "GitHub" + " Pages"

errors = []


def report(path, line_no, message):
    location = f"{path.relative_to(ROOT).as_posix()}:{line_no}" if isinstance(path, Path) else str(path)
    errors.append(f"{location}: {message}")


def relative(path):
    return path.relative_to(ROOT).as_posix()


def is_archived(path):
    return relative(path).startswith(ARCHIVED)


def iter_files():
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or any(part in SKIP_NAMES for part in path.relative_to(ROOT).parts):
            continue
        if path.suffix in TEXT_SUFFIXES or path.suffix in KIT_SUFFIXES or path.name == "Dockerfile":
            yield path


# ---------------------------------------------------------------------------
# HTML pages
# ---------------------------------------------------------------------------


class PageParser(HTMLParser):
    """Collects the prose, headings, links, ids, images, tabs, code and kit links of a page."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.prose = []  # (line, text)
        self.headings = []  # (line, level, text)
        self.links = []  # (line, attribute, value)
        self.ids = set()
        self.images = []  # (line, alt)
        self.bold = []  # line numbers
        self.tabs = []  # list of panels: (line, data-os, data-label)
        self.code = []  # (line, text) of code and pre elements, and of data-ps attributes
        self.kit_links = []  # (line, tag, data-kit value)
        self.html_lang = None
        self.body = {}
        self.landmarks = []
        self._heading = None

    def _in(self, *tags):
        return any(tag in self.stack for tag in tags)

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        line = self.getpos()[0]
        if tag == "html":
            self.html_lang = attributes.get("lang")
        if tag == "body":
            self.body = attributes
        if "id" in attributes:
            self.ids.add(attributes["id"])
            if attributes["id"] in {"site-header", "site-nav", "main", "page-toc", "site-footer"}:
                self.landmarks.append(attributes["id"])
        for attribute in ("href", "src"):
            if attribute in attributes:
                self.links.append((line, attribute, attributes[attribute]))
        if "data-kit" in attributes:
            self.kit_links.append((line, tag, attributes["data-kit"] or ""))
        if attributes.get("data-ps"):
            self.code.append((line, attributes["data-ps"]))
        if tag == "img":
            self.images.append((line, attributes.get("alt")))
        if tag in {"strong", "b"}:
            self.bold.append(line)
        classes = (attributes.get("class") or "").split()
        if tag == "div" and "tabs" in classes:
            self.tabs.append({"line": line, "panels": []})
        if "tab-panel" in classes and self.tabs:
            self.tabs[-1]["panels"].append((line, attributes.get("data-os", ""), attributes.get("data-label", "")))
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            self._heading = [line, tag, []]
        if tag not in {"br", "img", "input", "meta", "link", "hr"}:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if self._heading and tag == self._heading[1]:
            self.headings.append((self._heading[0], tag, "".join(self._heading[2]).strip()))
            self._heading = None
        while self.stack:
            if self.stack.pop() == tag:
                break

    def handle_data(self, data):
        if self._in("script", "style"):
            return
        code = self._in("code", "pre")
        if code:
            self.code.append((self.getpos()[0], data))
        if self._heading is not None and not code:
            self._heading[2].append(data)
        if not code and data.strip():
            self.prose.append((self.getpos()[0], data))


def parse_page(path):
    parser = PageParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser


def check_sentence_case(path, line, heading):
    text = heading
    for phrase in PROPER_PHRASES:
        text = text.replace(phrase, "")
    words = re.findall(r"[A-Za-z][A-Za-z0-9'\-]*", text)
    first = re.search(r"[A-Za-z][A-Za-z0-9'\-]*", heading)
    for index, word in enumerate(words):
        if index == 0 and first and heading.startswith(word, first.start()):
            continue
        if word in PROPER_WORDS or word.isupper() or not any(c.isupper() for c in word):
            continue
        report(path, line, f"heading not in sentence case: '{word}' in '{heading}'")


def check_prose_text(path, line, text):
    if ";" in text:
        report(path, line, "semicolon in prose")
    if re.search(r"\((e\.g\.|eg)\b", text, re.IGNORECASE):
        report(path, line, "'eg' in brackets: write 'for example'")
    if path.name != "style-guide.html":
        for word in FILLER_WORDS:
            if re.search(rf"\b{word}\b", text, re.IGNORECASE):
                report(path, line, f"filler word '{word}'")


def check_html(path, pages):
    page = pages[path]
    if page.html_lang != "en-GB":
        report(path, 1, "the html element needs lang=\"en-GB\"")
    for line, text in page.prose:
        check_prose_text(path, line, text)
    for line in page.bold:
        report(path, line, "bold text (strong or b)")
    for line, _level, heading in page.headings:
        check_sentence_case(path, line, heading)
    for line, alt in page.images:
        if not alt:
            report(path, line, "image without alt text")

    expected_root = "../" * (len(path.relative_to(ROOT).parts) - 1)
    if page.body.get("data-root") != expected_root:
        report(path, 1, f"data-root should be '{expected_root}'")
    if page.body.get("data-page") != relative(path):
        report(path, 1, f"data-page should be '{relative(path)}'")
    if page.landmarks != ["site-header", "site-nav", "main", "page-toc", "site-footer"]:
        report(path, 1, f"page template elements out of order or missing: {page.landmarks}")

    for tabs in page.tabs:
        if len(tabs["panels"]) < 2:
            report(path, tabs["line"], "a tabs block needs at least two tab-panel elements")
        covered = set()
        for line, os_list, label in tabs["panels"]:
            platforms = set(os_list.split())
            if not label or not platforms or not platforms <= PLATFORMS:
                report(path, line, "tab-panel needs data-label and data-os from windows, macos, linux")
            covered |= platforms
        if covered != PLATFORMS:
            report(path, tabs["line"], f"tabs block does not cover every platform: {sorted(covered)}")

    for line, attribute, value in page.links:
        check_link(path, line, value, pages)


def check_link(path, line, value, pages):
    if re.match(r"^[a-z][a-z0-9+.-]*:", value) or value.startswith("//"):
        return
    file_part, _, anchor = value.partition("#")
    target = (path.parent / file_part).resolve() if file_part else path
    if not target.exists():
        report(path, line, f"broken link: {value}")
        return
    if target.is_dir():
        report(path, line, f"link to a folder, which a hosted site cannot list: {value}")
        return
    if anchor and target.suffix == ".html":
        if target not in pages:
            pages[target] = parse_page(target)
        if anchor not in pages[target].ids:
            report(path, line, f"broken anchor: {value}")


def check_nav_links(pages):
    script = (ROOT / "assets/course.js").read_text(encoding="utf-8")
    for number, line in enumerate(script.splitlines(), start=1):
        for href in re.findall(r'href: "([^"#][^"]*)"', line):
            target = ROOT / href
            if not target.exists():
                report(ROOT / "assets/course.js", number, f"navigation link to a missing page: {href}")
            elif target not in pages:
                report(ROOT / "assets/course.js", number, f"navigation link to a page outside the checks: {href}")


def check_markdown(path, text):
    in_fence = False
    for number, line in enumerate(text.splitlines(), start=1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        prose = re.sub(r"`[^`]*`", "", re.sub(r"\]\([^)]*\)", "]", line))
        check_prose_text(path, number, prose)
        if "**" in prose:
            report(path, number, "bold text")
        heading = re.match(r"^#{1,6}\s+(.*)$", prose)
        if heading:
            check_sentence_case(path, number, heading.group(1).strip())
        for target in re.findall(r"\]\(([^)\s]+)\)", line):
            if not re.match(r"^[a-z]+:", target) and not (path.parent / target.partition("#")[0]).exists():
                report(path, number, f"broken link: {target}")


# ---------------------------------------------------------------------------
# Other files
# ---------------------------------------------------------------------------


def check_text(path, text, private_terms):
    secret_patterns = [
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
        r"AccountKey=",
        r"SharedAccessSignature",
        r"\beyJ[A-Za-z0-9_-]{15,}\.",
        r"ssh-(ed25519|rsa) AAAA[0-9A-Za-z+/]{20,}",
        r"(?i)\bpassword\s*[:=]\s*\S+",
        r"(?i)client_secret\s*[:=]\s*\S+",
    ]
    archived = is_archived(path)
    for number, line in enumerate(text.splitlines(), start=1):
        if not archived and (chr(0x2014) in line or chr(0x2013) in line):
            report(path, number, "em or en dash")
        for guid in re.findall(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b", line):
            if guid.lower() not in ALLOWED_GUIDS:
                report(path, number, "GUID (possible subscription or tenant ID)")
        for candidate in re.findall(r"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])", line):
            try:
                address = ipaddress.ip_address(candidate)
            except ValueError:
                continue
            if not (address.is_private or address.is_loopback or address.is_unspecified):
                report(path, number, f"public IP address {candidate}")
        if re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b", line):
            report(path, number, "e-mail address")
        if path.name != "check-course.py":
            for pattern in secret_patterns:
                if re.search(pattern, line):
                    report(path, number, f"possible secret ({pattern})")
        for term in private_terms:
            if term.lower() in line.lower():
                report(path, number, "private term from PRIVATE_TERMS")
        if archived or path.name == "check-course.py":
            continue
        if FORMER_HOSTING in line:
            report(path, number, f"mention of {FORMER_HOSTING}: the site is hosted on Azure Static Web Apps")
        if path.suffix in {".html", ".md", ".js"}:
            for pattern in STALE_PATHS:
                if re.search(pattern, line):
                    report(path, number, f"old script path ({pattern}): show a course command instead")


def check_no_kit_files(files):
    """The lab kit lives in its own repository: no script, Go code, Dockerfile or Kubernetes file here."""
    for path in files:
        name = relative(path)
        is_yaml = path.suffix in {".yaml", ".yml"} and not name.startswith(".github/")
        if path.suffix in KIT_SUFFIXES or path.name == "Dockerfile" or is_yaml:
            errors.append(f"{name}: a file of the lab kit. It belongs in kubernetes-for-azure-labs")
    if (ROOT / ".nojekyll").exists():
        errors.append(f".nojekyll: a leftover of {FORMER_HOSTING}")


def check_hosting_terraform():
    """Every resource of infra/ carries tags = local.tags, or follows a "# untaggable:" comment, and never the course tag."""
    files = sorted((ROOT / "infra").glob("*.tf"))
    if not files:
        errors.append("infra: no Terraform file for the hosting of the website")
        return
    folder = "\n".join(tf.read_text(encoding="utf-8") for tf in files)
    if re.search(r'course\s*=\s*"aro-k8s"', folder):
        errors.append("infra: the hosting must not use the course tag aro-k8s, which the clean-up commands of the kit delete")
    if not re.search(r"^\s*tags\s*=\s*var\.tags\s*$", folder, re.MULTILINE):
        errors.append("infra: local.tags is not defined as var.tags")
    for path in files:
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            match = re.match(r'^resource\s+"(\w+)"\s+"(\w+)"\s*\{', line)
            if not match:
                continue
            block = []
            for following in lines[index + 1:]:
                if following.startswith("}"):
                    break
                block.append(following)
            has_tags = any(re.match(r"^\s{2}tags\s*=\s*local\.tags\s*$", entry) for entry in block)
            marked = any("# untaggable:" in previous for previous in lines[max(0, index - 3):index])
            if not has_tags and not marked:
                report(path, index + 1, f"resource {match.group(1)}.{match.group(2)} has no 'tags = local.tags' and no '# untaggable:' comment")


def check_search_index():
    spec = importlib.util.spec_from_file_location("build_search_index", ROOT / "scripts/build-search-index.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    expected = module.render(module.build_index())
    current = module.OUTPUT.read_text(encoding="utf-8") if module.OUTPUT.exists() else ""
    if current != expected:
        errors.append("assets/search-index.js is out of date: run python3 scripts/build-search-index.py")


def check_lab_sheets():
    """Every chapter has a lab sheet that matches what scripts/build-lab-sheets.py would write."""
    spec = importlib.util.spec_from_file_location("build_lab_sheets", ROOT / "scripts" / "build-lab-sheets.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    for page in module.chapter_pages():
        sheet = module.sheet_path(page)
        if not sheet.is_file() or sheet.read_text(encoding="utf-8") != module.render(page):
            errors.append(f"{relative(sheet)} is missing or out of date: run python3 scripts/build-lab-sheets.py")
        if 'href="lab-sheet.html"' not in page.read_text(encoding="utf-8"):
            errors.append(f"{relative(page)} does not link to its lab sheet")


def check_leftovers():
    """The course is HTML only: one Markdown file, the README, and diagrams as PNG exports."""
    for path in sorted(ROOT.rglob("*.md")):
        if any(part in SKIP_NAMES for part in path.relative_to(ROOT).parts) or path == ROOT / "README.md":
            continue
        errors.append(f"{relative(path)}: Markdown file. Pages are HTML, and README.md is the only Markdown file")
    for path in sorted((ROOT / "assets" / "diagrams").iterdir()):
        if path.suffix != ".png":
            errors.append(f"{relative(path)}: only PNG exports belong in assets/diagrams")


# ---------------------------------------------------------------------------
# Cross-checks against the lab kit
# ---------------------------------------------------------------------------


class Kit:
    """What the pages need to know about the lab kit."""

    def __init__(self, root):
        self.root = root
        course = (root / "course").read_text(encoding="utf-8")
        course_ps = (root / "course.ps1").read_text(encoding="utf-8")
        self.commands = {}
        for side in ("LAPTOP", "VM"):
            match = re.search(rf'^{side}_COMMANDS="([a-z -]+)"$', course, re.MULTILINE)
            self.commands[side] = set(match.group(1).split()) if match else set()
        accepted = re.search(r"\[ValidateSet\(([^)]*)\)\]", course_ps)
        self.ps_commands = set(re.findall(r"'([a-z-]+)'", accepted.group(1))) & self.commands["LAPTOP"] if accepted else set()
        self.ps_switches = {name.lower() for name in re.findall(r"\[switch\]\$(\w+)", course_ps)}
        scripts = [course] + [path.read_text(encoding="utf-8") for path in sorted(root.glob("lib/*.sh")) + sorted(root.glob("labs/*/*.sh"))]
        self.options = set()
        for text in scripts:
            self.options.update(re.findall(r"^\s*(?:[a-z|* -]*\| )?(--[a-z][a-z-]*)(?:=\*)?(?: \|[^)]*)?\)", text, re.MULTILINE))
        self.labs = {path.name[:2]: path for path in sorted(root.glob("labs/*")) if path.is_dir()}
        self.solutions = {path.name[:2] for path in sorted(root.glob("solutions/*")) if path.is_dir()}


def load_kit():
    if not (KIT / "course").is_file():
        errors.append(f"lab kit not found at {KIT}: clone kubernetes-for-azure-labs next to this folder, or set KIT_DIR")
        return None
    return Kit(KIT)


# A course command starts a line of code, or follows ;, &, | or (. "shellcheck -x course setup/*.sh" is not one.
COMMAND = re.compile(r"(?:^|[;&|(])[ \t]*(\./course|\.\\course\.ps1|course)[ \t]+([a-z]+(?:-[a-z]+)*)((?:[ \t]+(?:\d{2}|NN|-{1,2}[A-Za-z][A-Za-z-]*|N|\d))*)", re.MULTILINE)


def check_course_commands(path, page, kit):
    """Every course command shown on a page exists in the kit, with its lab and its options."""
    for line, text in page.code:
        for match in COMMAND.finditer(text):
            form, command, rest = match.group(1), match.group(2), match.group(3).split()
            shown = match.group(0).strip()
            if form == ".\\course.ps1":
                if command not in kit.ps_commands:
                    report(path, line, f"'{shown}': course.ps1 has no command {command}")
                for option in (word for word in rest if word.startswith("-")):
                    if option.lstrip("-").lower() not in kit.ps_switches:
                        report(path, line, f"'{shown}': course.ps1 has no parameter {option}")
                continue
            sides = kit.commands["LAPTOP"] if form == "./course" else kit.commands["LAPTOP"] | kit.commands["VM"]
            if command not in sides:
                report(path, line, f"'{shown}': the course command of the kit has no command {command}")
                continue
            for option in (word for word in rest if word.startswith("--")):
                if option not in kit.options:
                    report(path, line, f"'{shown}': the kit has no option {option}")
            numbers = [word for word in rest if re.fullmatch(r"\d{2}", word)]
            if command in {"start", "check", "break", "clean", "solution"} and numbers and form == "course":
                lab = numbers[0]
                if lab not in kit.labs:
                    report(path, line, f"'{shown}': the kit has no lab {lab}")
                elif command == "break" and not (kit.labs[lab] / "break.sh").is_file():
                    report(path, line, f"'{shown}': lab {lab} of the kit has no broken lab")
                elif command == "solution" and lab not in kit.solutions:
                    report(path, line, f"'{shown}': the kit has no reference solution for lab {lab}")


def check_kit_links(path, page, kit):
    for line, tag, value in page.kit_links:
        if tag != "a":
            report(path, line, f"data-kit on a {tag} element: use it on links only")
        target = (kit.root / value).resolve() if value not in {"", "."} else kit.root
        if not target.exists():
            report(path, line, f"data-kit path not found in the lab kit: {value}")
        elif value.endswith("/") != target.is_dir() and value not in {"", "."}:
            report(path, line, f"data-kit path {value}: end a folder with a slash, and a file without one")


def check_lab_pages(kit):
    """Each lab of the kit has a chapter page whose tasks match its validator stages."""
    pages = {path.parent.name: path for path in sorted(ROOT.glob("chapters/*/index.html"))}
    for number, lab in sorted(kit.labs.items()):
        page = pages.get(lab.name)
        if not page:
            errors.append(f"lab {lab.name} of the kit has no page chapters/{lab.name}/index.html")
            continue
        text = page.read_text(encoding="utf-8")
        validator = (lab / "validate.sh").read_text(encoding="utf-8") if (lab / "validate.sh").is_file() else ""
        titles = re.search(r"^STAGE_TITLES=\(\n(.*?)^\)", validator, re.S | re.M)
        count = len(re.findall(r'^\s+"', titles.group(1), re.M)) if titles else 0
        tasks = re.search(r'<h3 id="tasks">.*?<ol>(.*?)</ol>', text, re.S)
        listed = len(re.findall(r"<li>", tasks.group(1))) if tasks else 0
        if count != listed:
            errors.append(f"stages: the kit's labs/{lab.name}/validate.sh has {count} stages and {relative(page)} lists {listed} tasks")
        for option in ("--guided", "--deep"):
            if option not in text:
                errors.append(f"stages: {relative(page)} does not mention {option}")
        if (lab / "break.sh").is_file() and f"course break {number} --restore" not in text:
            errors.append(f"broken lab: {relative(page)} does not present course break {number} and its --restore option")
    for name, page in pages.items():
        if name[:2] not in kit.labs:
            errors.append(f"{relative(page)}: the kit has no folder labs/{name}")


def main():
    private_terms = [term.strip() for term in os.environ.get("PRIVATE_TERMS", "").split(",") if term.strip()]
    files = list(iter_files())
    pages = {path.resolve(): None for path in files if path.suffix == ".html" and not is_archived(path)}
    for path in list(pages):
        pages[path] = parse_page(path)

    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        check_text(path, text, private_terms)
        if is_archived(path):
            continue
        if path.suffix == ".html":
            check_html(path.resolve(), pages)
        if path.suffix == ".md":
            check_markdown(path, text)
    check_no_kit_files(files)
    check_nav_links(pages)
    check_hosting_terraform()
    check_search_index()
    check_lab_sheets()
    check_leftovers()

    kit = load_kit()
    if kit:
        for path, page in sorted(pages.items()):
            if page is not None and not is_archived(path):
                check_course_commands(path, page, kit)
                check_kit_links(path, page, kit)
        check_lab_pages(kit)

    for error in errors:
        print(f"[FAIL] {error}")
    print(f"\nChecked {len(files)} files ({len([p for p in files if p.suffix == '.html' and not is_archived(p)])} pages) "
          f"against the lab kit in {KIT}, {len(errors)} errors"
          + (f", with {len(private_terms)} private terms" if private_terms else ", without PRIVATE_TERMS") + ".")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
