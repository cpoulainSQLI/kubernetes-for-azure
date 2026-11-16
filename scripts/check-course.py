#!/usr/bin/env python3
"""Course checks that linters do not cover. Run from anywhere:

    python3 scripts/check-course.py

Checks:
  1. Writing rules in the text of every page: no em or en dash, no semicolon,
     no bold, no "eg" in brackets, no filler words, sentence-case headings.
  2. Page template, internal links and anchors (including the navigation in
     assets/course.js), alternative text of images, and platform tabs.
  3. Every Azure resource in Bicep carries the course and chapter tags, or is
     marked with an "// untaggable:" comment, and scripts tag what they create.
  4. No subscription or tenant ID (any GUID except built-in role IDs), public IP
     address, e-mail address or secret in any file.
  5. The pinned kind and kubectl versions agree across files.
  6. The search index is up to date.
  7. The bash and PowerShell versions of each laptop script have the same
     "# check:" and "# step:" IDs, and PowerShell files are plain ASCII.

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
ARCHIVED = ("archive/lessons/", "archive/reference/", "archive/assets/", "archive/tools/")
# Names the checks leave alone: tool folders, and what Git ignores on the author's machine. These are the local
# notes, the agent instructions and .claude, where a coding agent keeps its settings and its working copies.
SKIP_NAMES = {".git", "node_modules", "handoff", "CLAUDE.md", "CLAUDE.local.md", ".claude"}
TEXT_SUFFIXES = {".md", ".html", ".sh", ".ps1", ".psd1", ".bicep", ".yaml", ".yml", ".go", ".mod", ".py", ".css", ".js", ".json", ""}
PLATFORMS = {"windows", "macos", "linux"}

# IDs of Azure built-in roles: identical in every tenant, so they are not personal data.
ALLOWED_GUIDS = {
    "b24988ac-6180-42a0-ab88-20f7382dd24c",  # Contributor
    "8311e382-0749-4cb8-b61a-304f252e45ec",  # AcrPush
}
FILLER_WORDS = ["robust", "seamless", "seamlessly", "tailored", "foster", "fostering", "genuinely", "leverage", "delve", "crucial"]
PROPER_PHRASES = [
    "Azure Red Hat OpenShift", "Azure Container Registry", "Azure Kubernetes Service", "Azure Bastion",
    "Red Hat", "Microsoft Learn", "Microsoft Entra ID", "Docker Hub", "Docker Engine", "Visual Studio",
    "Developer Sandbox", "Open Container Initiative", "Network Watcher", "Git Bash", "Windows PowerShell",
]
PROPER_WORDS = {
    "Azure", "Kubernetes", "OpenShift", "Docker", "Dockerfile", "Microsoft", "Bicep", "Ubuntu", "Go", "Git",
    "Bash", "PowerShell", "Podman", "Entra", "Linux", "Windows", "macOS", "Mermaid", "AKS", "ARO", "ACR", "Helm",
    "NodePort", "ClusterIP", "LoadBalancer", "ReplicaSet", "ReplicaSets", "Deployment", "Deployments",
    "Service", "Services", "Pod", "Pods", "EndpointSlice", "EndpointSlices", "Namespace", "Namespaces",
}
LAPTOP_SCRIPT_PAIRS = [
    ("chapters/00-lab-setup/lab/setup.sh", "chapters/00-lab-setup/lab/setup.ps1"),
    ("chapters/00-lab-setup/lab/validate.sh", "chapters/00-lab-setup/lab/validate.ps1"),
    ("chapters/00-lab-setup/lab/teardown.sh", "chapters/00-lab-setup/lab/teardown.ps1"),
    ("scripts/lab-vm.sh", "scripts/lab-vm.ps1"),
]

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
        if path.suffix in TEXT_SUFFIXES or path.name == "Dockerfile":
            yield path


# ---------------------------------------------------------------------------
# HTML pages
# ---------------------------------------------------------------------------


class PageParser(HTMLParser):
    """Collects the prose, headings, links, ids, images and tabs of a page."""

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
        self.html_lang = None
        self.body = {}
        self.landmarks = []
        self._heading = None
        self._tab_depth = []

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


def check_dashes(path, text):
    for number, line in enumerate(text.splitlines(), start=1):
        if chr(0x2014) in line or chr(0x2013) in line:
            report(path, number, "em or en dash")


def check_personal_data(path, text, private_terms):
    secret_patterns = [
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
        r"AccountKey=",
        r"SharedAccessSignature",
        r"\beyJ[A-Za-z0-9_-]{15,}\.",
        r"ssh-(ed25519|rsa) AAAA[0-9A-Za-z+/]{20,}",
        r"(?i)\bpassword\s*[:=]\s*\S+",
        r"(?i)client_secret\s*[:=]\s*\S+",
    ]
    for number, line in enumerate(text.splitlines(), start=1):
        for guid in re.findall(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b", line):
            if guid.lower() not in ALLOWED_GUIDS:
                report(path, number, "GUID (possible subscription or tenant ID)")
        for candidate in re.findall(r"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])", line):
            if "contentVersion" in line:
                continue
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


def check_bicep_tags(path, text):
    lines = text.splitlines()
    receives_tags = re.search(r"^param tags object", text, re.MULTILINE)
    if "resource " in text and not receives_tags:
        if not re.search(r"course:\s*'aro-k8s'", text):
            report(path, 1, "no tags variable with course: 'aro-k8s'")
        if not re.search(r"chapter:\s*chapter", text):
            report(path, 1, "no chapter tag")
    if re.search(r"^module ", text, re.MULTILINE) and not re.search(r"^\s+tags:\s*tags$", text, re.MULTILINE):
        report(path, 1, "a module does not receive the tags")
    for index, line in enumerate(lines):
        match = re.match(r"^resource\s+(\w+)\s+'([^']+)'\s*(existing)?", line)
        if not match or match.group(3):
            continue
        block = []
        for following in lines[index + 1:]:
            if following.startswith("}"):
                break
            block.append(following)
        has_tags = any(re.match(r"^\s{2}tags:\s*tags\b", entry) for entry in block)
        marked = any("// untaggable:" in previous for previous in lines[max(0, index - 3):index])
        if not has_tags and not marked:
            report(path, index + 1, f"resource '{match.group(1)}' has no 'tags: tags' and no '// untaggable:' comment")


def check_script_tags(path, text):
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if path.suffix == ".sh":
            create = re.search(r"\baz\s+([a-z-]+(?:\s+[a-z-]+)*)\s+create\b", stripped)
            if create and not create.group(1).startswith(("deployment", "role assignment")) and "--tags" not in stripped:
                report(path, number, f"'az {create.group(1)} create' without --tags")
        elif "'create'" in stripped and "'deployment'" not in stripped and "'--tags'" not in stripped:
            report(path, number, "az create call without '--tags'")


def check_version_pins():
    lib = (ROOT / "scripts/lib.sh").read_text(encoding="utf-8")
    lib_ps = (ROOT / "scripts/lib.ps1").read_text(encoding="utf-8")
    cloud_init = (ROOT / "chapters/00-lab-setup/lab/infra/cloud-init.yaml").read_text(encoding="utf-8")
    kind_file = (ROOT / "chapters/02-kubernetes-core/lab/kind-cluster.yaml").read_text(encoding="utf-8")
    pins = {
        "lib.sh kind": re.search(r'PINNED_KIND_VERSION="([^"]+)"', lib),
        "lib.ps1 kind": re.search(r"\$PinnedKindVersion = '([^']+)'", lib_ps),
        "cloud-init kind": re.search(r'KIND_VERSION="([^"]+)"', cloud_init),
        "lib.sh kubectl": re.search(r'PINNED_KUBECTL_MINOR="([^"]+)"', lib),
        "lib.ps1 kubectl": re.search(r"\$PinnedKubectlMinor = '([^']+)'", lib_ps),
        "cloud-init kubectl": re.search(r'KUBECTL_MINOR="([^"]+)"', cloud_init),
    }
    missing = [name for name, match in pins.items() if not match]
    if missing:
        errors.append(f"version pins: not found in {missing}")
        return
    kind_versions = {pins[name].group(1) for name in pins if name.endswith("kind")}
    kubectl_versions = {pins[name].group(1) for name in pins if name.endswith("kubectl")}
    if len(kind_versions) != 1:
        errors.append(f"version pins: kind versions differ {sorted(kind_versions)}")
    if len(kubectl_versions) != 1:
        errors.append(f"version pins: kubectl versions differ {sorted(kubectl_versions)}")
    if next(iter(kind_versions)) not in kind_file:
        errors.append("version pins: kind-cluster.yaml does not mention the pinned kind version")
    node_versions = set(re.findall(r"kindest/node:(v\d+\.\d+)\.\d+@sha256:[0-9a-f]{64}", kind_file))
    if node_versions != kubectl_versions:
        errors.append(f"version pins: kind node images {sorted(node_versions)} do not match kubectl {sorted(kubectl_versions)}")


def check_search_index():
    spec = importlib.util.spec_from_file_location("build_search_index", ROOT / "scripts/build-search-index.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    expected = module.render(module.build_index())
    current = module.OUTPUT.read_text(encoding="utf-8") if module.OUTPUT.exists() else ""
    if current != expected:
        errors.append("assets/search-index.js is out of date: run python3 scripts/build-search-index.py")


def check_parity():
    for bash_file, ps_file in LAPTOP_SCRIPT_PAIRS:
        ids = []
        for name in (bash_file, ps_file):
            text = (ROOT / name).read_text(encoding="utf-8")
            ids.append(set(re.findall(r"^\s*# (check|step): ([a-z0-9-]+)", text, re.MULTILINE)))
        if ids[0] != ids[1]:
            only_bash = sorted(f"{kind}: {name}" for kind, name in ids[0] - ids[1])
            only_ps = sorted(f"{kind}: {name}" for kind, name in ids[1] - ids[0])
            errors.append(f"parity: {bash_file} and {ps_file} differ. Only in bash: {only_bash}. Only in PowerShell: {only_ps}")
        elif not ids[0]:
            errors.append(f"parity: {bash_file} has no check or step IDs")


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


def check_break_scripts():
    """A broken lab script has a symptom, an injection and an explanation for each fault, and its page presents it."""
    for script in sorted(ROOT.glob("chapters/*/lab/break.sh")):
        text = script.read_text(encoding="utf-8")
        name = relative(script)
        scenarios = re.search(r"^SCENARIOS=\((.*?)\)", text, re.M)
        names = scenarios.group(1).split() if scenarios else []
        if not names:
            errors.append(f"broken lab: {name} defines no SCENARIOS")
        for scenario in names:
            for prefix in ("symptom", "inject", "explain"):
                if not re.search(rf"^{prefix}_{scenario}\(\) {{", text, re.M):
                    errors.append(f"broken lab: {name} has no function {prefix}_{scenario}")
        causes = re.search(r"^CAUSES=\(\n(.*?)^\)", text, re.S | re.M)
        if not causes or len(re.findall(r'^\s+"', causes.group(1), re.M)) <= len(names):
            errors.append(f"broken lab: {name} needs one cause per fault, plus at least one that is never the answer")
        for function in ("lab_is_finished", "restore_lab"):
            if not re.search(rf"^{function}\(\) {{", text, re.M):
                errors.append(f"broken lab: {name} has no function {function}")
        page = script.parent.parent / "index.html"
        if "break.sh --restore" not in page.read_text(encoding="utf-8"):
            errors.append(f"broken lab: {relative(page)} does not present break.sh and its --restore option")


def check_leftovers():
    """The course is HTML only: one Markdown file, the README, and diagrams as PNG exports."""
    for path in sorted(ROOT.rglob("*.md")):
        if any(part in SKIP_NAMES for part in path.relative_to(ROOT).parts) or path == ROOT / "README.md":
            continue
        errors.append(f"{relative(path)}: Markdown file. Pages are HTML, and README.md is the only Markdown file")
    for path in sorted((ROOT / "assets" / "diagrams").iterdir()):
        if path.suffix != ".png":
            errors.append(f"{relative(path)}: only PNG exports belong in assets/diagrams")


def check_validator_stages():
    """A staged validator has one check function and one task text per stage, and the chapter page lists one task per stage."""
    for script in sorted(ROOT.glob("chapters/*/lab/validate.sh")):
        text = script.read_text(encoding="utf-8")
        if "lib-validate.sh" not in text:
            continue
        name = relative(script)
        titles = re.search(r"^STAGE_TITLES=\(\n(.*?)^\)", text, re.S | re.M)
        count = len(re.findall(r'^\s+"', titles.group(1), re.M)) if titles else 0
        if count == 0:
            errors.append(f"stages: {name} defines no STAGE_TITLES")
            continue
        for number in range(1, count + 1):
            for function in (f"stage_{number}", f"stage_{number}_task"):
                if not re.search(rf"^{function}\(\) {{", text, re.M):
                    errors.append(f"stages: {name} has no function {function}")
        if re.search(rf"^stage_{count + 1}\(\) {{", text, re.M):
            errors.append(f"stages: {name} has more stage functions than titles")
        page = script.parent.parent / "index.html"
        tasks = re.search(r'<h3 id="tasks">.*?<ol>(.*?)</ol>', page.read_text(encoding="utf-8"), re.S)
        listed = len(re.findall(r"<li>", tasks.group(1))) if tasks else 0
        if listed != count:
            errors.append(f"stages: {name} has {count} stages and {relative(page)} lists {listed} tasks")
        for option in ("--guided", "--deep"):
            if option not in page.read_text(encoding="utf-8"):
                errors.append(f"stages: {relative(page)} does not mention {option}")


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
        check_personal_data(path, text, private_terms)
        if is_archived(path):
            continue
        check_dashes(path, text)
        if path.suffix == ".html":
            check_html(path.resolve(), pages)
        if path.suffix == ".md":
            check_markdown(path, text)
        if path.suffix == ".bicep":
            check_bicep_tags(path, text)
        if path.suffix in {".sh", ".ps1"}:
            check_script_tags(path, text)
        if path.suffix in {".ps1", ".psd1"} and not text.isascii():
            # Windows PowerShell 5.1 reads files without a byte order mark as ANSI, not UTF-8.
            report(path, 1, "non-ASCII character in a PowerShell file")
    check_nav_links(pages)
    check_version_pins()
    check_search_index()
    check_parity()
    check_validator_stages()
    check_lab_sheets()
    check_break_scripts()
    check_leftovers()

    for error in errors:
        print(f"[FAIL] {error}")
    print(f"\nChecked {len(files)} files ({len([p for p in files if p.suffix == '.html' and not is_archived(p)])} pages), {len(errors)} errors"
          + (f", with {len(private_terms)} private terms" if private_terms else ", without PRIVATE_TERMS") + ".")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
