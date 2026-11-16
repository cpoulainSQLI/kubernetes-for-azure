/* Kubernetes and Azure Red Hat OpenShift, hands-on: shared behaviour for every page.
   Plain JavaScript, no library, so the pages also work when opened from disk. */
(function () {
  "use strict";

  var COURSE_TITLE = "Kubernetes and Azure Red Hat OpenShift, hands-on";
  var PLATFORM_KEY = "aroK8sCourse.platform";
  var PLATFORMS = [
    { id: "windows", label: "Windows" },
    { id: "macos", label: "macOS" },
    { id: "linux", label: "Linux" }
  ];

  // Single source for the navigation of every page. Paths are relative to the course root.
  var NAV = [
    { title: "Home", href: "index.html" },
    { title: "About this course", href: "about.html" },
    { group: "Start here", items: [
      { title: "Introduction", href: "introduction.html" },
      { title: "Setup", href: "setup.html" }
    ] },
    { group: "Part 1, foundations", items: [
      { title: "1. Containers", href: "chapters/01-containers/index.html" },
      { title: "2. Kubernetes core", href: "chapters/02-kubernetes-core/index.html" }
    ] },
    { group: "Part 2, Kubernetes in practice", items: [
      { title: "3. Configuration, storage and exposure" },
      { title: "4. Access and security" },
      { title: "5. Helm and operators" }
    ] },
    { group: "Part 3, managed platforms", items: [
      { title: "6. Azure Kubernetes Service" },
      { title: "7. OpenShift on the Developer Sandbox" }
    ] },
    { group: "Part 4, Azure Red Hat OpenShift", items: [
      { title: "8. ARO architecture and first cluster" },
      { title: "9. Operating ARO" },
      { title: "10. ARO compared with AKS" }
    ] },
    { group: "Reference", items: [
      { title: "Sample app", href: "sample-app/index.html" },
      { title: "Reference solutions", href: "solutions/index.html" },
      { title: "Quotas, regions and providers", href: "azure-limits.html" },
      { title: "Resources", href: "resources.html" },
      { title: "Style guide for contributors", href: "style-guide.html" }
    ] }
  ];

  var body = document.body;
  var root = body.getAttribute("data-root") || "";
  var page = body.getAttribute("data-page") || "index.html";
  document.documentElement.classList.add("js");

  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (key) {
      if (key === "text") { node.textContent = attrs[key]; } else { node.setAttribute(key, attrs[key]); }
    });
    (children || []).forEach(function (child) { if (child) { node.appendChild(child); } });
    return node;
  }

  function storageGet(key) {
    try { return window.localStorage.getItem(key); } catch (e) { return null; }
  }
  function storageSet(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) { /* storage unavailable: keep the choice for this page only */ }
  }

  function detectPlatform() {
    var hint = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || navigator.userAgent || "";
    if (/win/i.test(hint)) { return "windows"; }
    if (/mac|iphone|ipad/i.test(hint)) { return "macos"; }
    return "linux";
  }

  var currentPlatform = storageGet(PLATFORM_KEY) || detectPlatform();

  // ---------- Header ----------
  function buildHeader() {
    var header = document.getElementById("site-header");
    if (!header) { return; }
    header.innerHTML = "";
    var menu = el("button", { type: "button", "class": "menu-button", "aria-controls": "site-nav", "aria-expanded": "false", text: "Menu" });
    menu.addEventListener("click", function () {
      var nav = document.getElementById("site-nav");
      var open = nav.classList.toggle("open");
      menu.setAttribute("aria-expanded", open ? "true" : "false");
    });
    var brand = el("a", { "class": "brand", href: root + "index.html" }, [
      el("span", { "class": "brand-mark", "aria-hidden": "true", text: "K8s" }),
      el("span", { "class": "brand-title", text: COURSE_TITLE })
    ]);
    var searchInput = el("input", { type: "search", id: "course-search", placeholder: "Search the course", "aria-label": "Search the course", autocomplete: "off" });
    var results = el("ul", { "class": "search-results", id: "search-results", hidden: "" });
    var search = el("div", { "class": "search", role: "search" }, [searchInput, results]);
    var select = el("select", { id: "platform-select", "aria-label": "Your computer" });
    PLATFORMS.forEach(function (platform) {
      var option = el("option", { value: platform.id, text: platform.label });
      if (platform.id === currentPlatform) { option.selected = true; }
      select.appendChild(option);
    });
    select.addEventListener("change", function () { setPlatform(select.value); });
    var picker = el("label", { "class": "platform-picker" }, [el("span", { "class": "picker-label", text: "Your computer" }), select]);
    header.appendChild(menu);
    header.appendChild(brand);
    header.appendChild(el("span", { "class": "header-spacer" }));
    header.appendChild(search);
    header.appendChild(picker);
    setUpSearch(searchInput, results);
  }

  // ---------- Navigation ----------
  function navLink(item) {
    if (!item.href) { return el("span", { "class": "planned", text: item.title }); }
    var attrs = { href: root + item.href, text: item.title };
    if (item.href === page) { attrs["aria-current"] = "page"; }
    return el("a", attrs);
  }

  function buildNav() {
    var nav = document.getElementById("site-nav");
    if (!nav) { return; }
    nav.innerHTML = "";
    var list = el("ul");
    NAV.forEach(function (entry) {
      if (entry.group) {
        list.appendChild(el("li", { "class": "nav-group", text: entry.group }));
        entry.items.forEach(function (item) { list.appendChild(el("li", {}, [navLink(item)])); });
      } else {
        list.appendChild(el("li", {}, [navLink(entry)]));
      }
    });
    nav.appendChild(list);
  }

  // ---------- On this page ----------
  function buildToc() {
    var toc = document.getElementById("page-toc");
    var main = document.getElementById("main");
    if (!toc || !main) { return; }
    var headings = main.querySelectorAll("h2[id], h3[id]");
    if (headings.length < 2) { toc.hidden = true; return; }
    toc.innerHTML = "";
    toc.appendChild(el("p", { "class": "toc-title", text: "On this page" }));
    var list = el("ul");
    var links = [];
    Array.prototype.forEach.call(headings, function (heading) {
      var link = el("a", { href: "#" + heading.id, text: heading.textContent });
      links.push({ link: link, heading: heading });
      list.appendChild(el("li", { "class": heading.tagName === "H3" ? "level-3" : "level-2" }, [link]));
    });
    toc.appendChild(list);
    if ("IntersectionObserver" in window) {
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            links.forEach(function (item) { item.link.classList.toggle("active", item.heading === entry.target); });
          }
        });
      }, { rootMargin: "-60px 0px -70% 0px" });
      links.forEach(function (item) { observer.observe(item.heading); });
    }
  }

  // ---------- Platform tabs ----------
  function panelMatches(panel, platform) {
    return (panel.getAttribute("data-os") || "").split(/\s+/).indexOf(platform) !== -1;
  }

  function showTabs(tabs, platform) {
    var panels = tabs.querySelectorAll(".tab-panel");
    var buttons = tabs.querySelectorAll(".tab-list button");
    var chosen = 0;
    Array.prototype.forEach.call(panels, function (panel, index) { if (panelMatches(panel, platform)) { chosen = index; } });
    Array.prototype.forEach.call(panels, function (panel, index) { panel.hidden = index !== chosen; });
    Array.prototype.forEach.call(buttons, function (button, index) {
      button.setAttribute("aria-selected", index === chosen ? "true" : "false");
      button.tabIndex = index === chosen ? 0 : -1;
    });
  }

  // Inline commands: <code data-ps="PowerShell form">bash form</code> follow the chosen platform.
  function showInlineCommands(platform) {
    Array.prototype.forEach.call(document.querySelectorAll("code[data-ps]"), function (code) {
      if (!code.hasAttribute("data-sh")) { code.setAttribute("data-sh", code.textContent); }
      code.textContent = platform === "windows" ? code.getAttribute("data-ps") : code.getAttribute("data-sh");
    });
  }

  function setPlatform(platform) {
    currentPlatform = platform;
    storageSet(PLATFORM_KEY, platform);
    Array.prototype.forEach.call(document.querySelectorAll(".tabs"), function (tabs) { showTabs(tabs, platform); });
    showInlineCommands(platform);
    var select = document.getElementById("platform-select");
    if (select) { select.value = platform; }
  }

  function buildTabs() {
    Array.prototype.forEach.call(document.querySelectorAll(".tabs"), function (tabs, setIndex) {
      var panels = tabs.querySelectorAll(".tab-panel");
      var list = el("div", { "class": "tab-list", role: "tablist", "aria-label": "Choose your computer" });
      Array.prototype.forEach.call(panels, function (panel, index) {
        var panelId = "tabs-" + setIndex + "-panel-" + index;
        var buttonId = "tabs-" + setIndex + "-tab-" + index;
        panel.id = panelId;
        panel.setAttribute("role", "tabpanel");
        panel.setAttribute("aria-labelledby", buttonId);
        var button = el("button", { type: "button", role: "tab", id: buttonId, "aria-controls": panelId, text: panel.getAttribute("data-label") });
        button.addEventListener("click", function () {
          var platforms = (panel.getAttribute("data-os") || "").split(/\s+/);
          setPlatform(platforms.indexOf(currentPlatform) !== -1 ? currentPlatform : platforms[0]);
          button.focus();
        });
        button.addEventListener("keydown", function (event) {
          var buttons = list.querySelectorAll("button");
          var step = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
          if (step) {
            var next = buttons[(index + step + buttons.length) % buttons.length];
            next.click();
            event.preventDefault();
          }
        });
        list.appendChild(button);
      });
      tabs.insertBefore(list, tabs.firstChild);
      showTabs(tabs, currentPlatform);
    });
  }

  // ---------- Copy buttons ----------
  function buildCopyButtons() {
    Array.prototype.forEach.call(document.querySelectorAll("pre"), function (pre) {
      var button = el("button", { type: "button", "class": "copy-button", text: "Copy" });
      button.addEventListener("click", function () {
        var text = pre.querySelector("code") ? pre.querySelector("code").textContent : pre.textContent;
        var done = function () {
          button.textContent = "Copied";
          setTimeout(function () { button.textContent = "Copy"; }, 1500);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, function () { button.textContent = "Select and copy"; });
        } else {
          button.textContent = "Select and copy";
        }
      });
      pre.classList.add("has-copy");
      pre.appendChild(button);
    });
  }

  // ---------- Knowledge check ----------
  function buildQuiz() {
    Array.prototype.forEach.call(document.querySelectorAll(".quiz > li"), function (question) {
      var answer = question.getAttribute("data-answer");
      var details = question.querySelector("details");
      var button = el("button", { type: "button", "class": "check-button", text: "Check my answer" });
      var verdict = el("span", { "class": "verdict", "aria-live": "polite" });
      button.addEventListener("click", function () {
        var picked = question.querySelector("input:checked");
        if (!picked) { verdict.textContent = "Pick an answer first."; verdict.className = "verdict"; return; }
        Array.prototype.forEach.call(question.querySelectorAll("label"), function (label) {
          var input = label.querySelector("input");
          label.classList.remove("correct", "incorrect");
          if (input.value === answer) { label.classList.add("correct"); }
          else if (input.checked) { label.classList.add("incorrect"); }
        });
        var right = picked.value === answer;
        verdict.textContent = right ? "Correct." : "Not quite. The right answer is highlighted.";
        verdict.className = "verdict " + (right ? "ok" : "bad");
        if (details) { details.open = true; }
      });
      var actions = el("p", {}, [button, verdict]);
      question.insertBefore(actions, details || null);
    });
  }

  // ---------- Search ----------
  function setUpSearch(input, results) {
    var index = window.COURSE_INDEX || [];
    function hide() { results.hidden = true; }
    function render(query) {
      var terms = query.toLowerCase().split(/\s+/).filter(Boolean);
      results.innerHTML = "";
      if (!terms.length) { hide(); return; }
      var matches = index.filter(function (entry) {
        var haystack = (entry.title + " " + entry.text + " " + entry.page).toLowerCase();
        return terms.every(function (term) { return haystack.indexOf(term) !== -1; });
      }).slice(0, 10);
      if (!matches.length) {
        results.appendChild(el("li", { "class": "empty", text: "No result." }));
      }
      matches.forEach(function (entry) {
        var position = entry.text.toLowerCase().indexOf(terms[0]);
        var start = Math.max(0, position - 40);
        var snippet = (start > 0 ? "..." : "") + entry.text.substr(start, 120) + "...";
        results.appendChild(el("li", {}, [el("a", { href: root + entry.url }, [
          el("span", { "class": "result-page", text: entry.page }),
          el("span", { text: entry.title }),
          el("span", { "class": "result-snippet", text: snippet })
        ])]));
      });
      results.hidden = false;
    }
    input.addEventListener("input", function () { render(input.value); });
    input.addEventListener("keydown", function (event) { if (event.key === "Escape") { input.value = ""; hide(); } });
    document.addEventListener("click", function (event) { if (!results.contains(event.target) && event.target !== input) { hide(); } });
  }

  // ---------- Links to the lab kit ----------
  // A link to a file of the kit carries data-kit="path/in/the/kit": a trailing slash for a folder, "." for the
  // whole kit. assets/kit.js names the GitHub account that hosts the kit. The deployment writes it, and it is
  // never committed. Without it, for example when a page is opened from disk, the links show <account> in
  // their address and the page says why. An element with data-kit-owner gets <account> replaced in its text.
  var KIT_REPOSITORY = "kubernetes-for-azure-labs";
  var KIT_BRANCH = "main";

  function kitUrl(owner, path) {
    var base = "https://github.com/" + owner + "/" + KIT_REPOSITORY;
    if (!path || path === ".") { return base; }
    return base + (/\/$/.test(path) ? "/tree/" : "/blob/") + KIT_BRANCH + "/" + path.replace(/\/$/, "");
  }

  function applyKitLinks() {
    var config = window.COURSE_KIT || {};
    var owner = /^[A-Za-z0-9-]+$/.test(config.owner || "") ? config.owner : "";
    var links = document.querySelectorAll("a[data-kit]");
    var filled = document.querySelectorAll("[data-kit-owner]");
    Array.prototype.forEach.call(links, function (link) {
      var path = link.getAttribute("data-kit");
      if (owner) {
        link.setAttribute("href", kitUrl(owner, path));
      } else {
        link.removeAttribute("href");
        link.setAttribute("title", kitUrl("<account>", path));
        link.classList.add("kit-offline");
      }
    });
    if (owner) {
      Array.prototype.forEach.call(filled, function (node) { node.textContent = node.textContent.split("<account>").join(owner); });
      return;
    }
    var heading = document.querySelector("#main h1");
    if ((links.length || filled.length) && heading) {
      heading.parentNode.insertBefore(el("p", { "class": "callout kit-note", text:
        "Links to the lab kit point to github.com/<account>/" + KIT_REPOSITORY + ". This copy of the site does not know " +
        "the account, so replace <account> with the GitHub account that publishes the course." }), heading.nextSibling);
    }
  }

  function loadKitConfig() {
    var script = document.createElement("script");
    script.src = root + "assets/kit.js";
    script.onload = applyKitLinks;
    script.onerror = applyKitLinks;
    document.head.appendChild(script);
  }

  // ---------- Footer ----------
  function buildFooter() {
    var footer = document.getElementById("site-footer");
    if (!footer) { return; }
    footer.innerHTML = "";
    footer.appendChild(el("p", {}, [
      document.createTextNode(COURSE_TITLE + ". Prices and product facts are checked against the sources listed on each page. "),
      el("a", { href: root + "style-guide.html", text: "Style guide for contributors" })
    ]));
  }

  buildHeader();
  buildNav();
  buildToc();
  buildTabs();
  showInlineCommands(currentPlatform);
  buildCopyButtons();
  buildQuiz();
  loadKitConfig();
  buildFooter();
})();
