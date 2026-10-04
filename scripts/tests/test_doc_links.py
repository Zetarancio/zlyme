#!/usr/bin/env python3
"""Relative links and repo paths in the canonical maintainer docs."""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOCS = (
    "AGENTS.md",
    "README.md",
    "docs/MAINTENANCE.md",
    "docs/ARCHITECTURE.md",
    "docs/DEVICE_PORTING.md",
    "docs/DEVELOPMENT.md",
    "docs/OPERATIONS.md",
    "docs/UPSTREAMS.md",
    "docs/ROADMAP.md",
    "docs/LOGBOOK.md",
    "docs/ENGINEERING_PRINCIPLES.md",
    "docs/USER_GUIDE.md",
    "docs/WRITING.md",
    "CONTRIBUTING.md",
    "CHANGELOG.md",
    "docs/decisions/0006-root-image-lifecycle.md",
    "docs/research/README.md",
    "docs/research/documentation-audit-phase10.md",
)
# Logbook, roadmap, and the audit record name old paths, file:line
# citations, and the hardware wiki. Link targets in this repository are
# still checked. Backtick paths are checked only in the current-contract
# documents.
PATH_DOCS = set(DOCS) - {
    "docs/ROADMAP.md",
    "docs/LOGBOOK.md",
    "docs/research/documentation-audit-phase10.md",
}
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
TICK = re.compile(r"`([^`\n]+)`")
REPO_PREFIXES = (
    "docs/",
    "board/",
    "package/",
    "scripts/",
    ".github/",
    ".cursor/",
    "configs/",
)


def exists(path):
    return os.path.exists(os.path.join(ROOT, path))


def anchors(path):
    """GitHub heading slugs for a Markdown file, outside code fences."""
    found = set()
    fenced = False
    for line in open(os.path.join(ROOT, path), encoding="utf-8"):
        if line.startswith("```"):
            fenced = not fenced
            continue
        match = None if fenced else re.match(r"#{1,6} +(.+?) *#* *$", line)
        if match:
            slug = re.sub(r"[^\w\- ]", "", match.group(1).strip().lower())
            found.add(slug.replace(" ", "-"))
    return found


def main():
    bad = []
    for rel in DOCS:
        full = os.path.join(ROOT, rel)
        text = open(full, encoding="utf-8").read()
        base = os.path.dirname(rel)
        for target in LINK.findall(text):
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            path, _, fragment = target.partition("#")
            resolved = os.path.normpath(os.path.join(base, path)) if path else rel
            if not exists(resolved):
                bad.append("%s -> %s" % (rel, target))
                continue
            if fragment and resolved.endswith(".md") and fragment not in anchors(resolved):
                bad.append("%s -> %s (no such heading)" % (rel, target))
        if rel not in PATH_DOCS:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if re.search(r"\bdo not\b", line, re.IGNORECASE):
                continue
            for raw in TICK.findall(line):
                token = raw.strip()
                if not token.startswith(REPO_PREFIXES) and token not in (
                    "AGENTS.md",
                    "README.md",
                    "ZLYME_VERSION",
                ):
                    continue
                if any(ch in token for ch in "*$?<>|"):
                    continue
                path = token.split()[0].rstrip(".,:;")
                if not exists(path):
                    bad.append("%s:%s `%s`" % (rel, lineno, token))
    if bad:
        print("\n".join(bad), file=sys.stderr)
        return 1
    print("doc links ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
