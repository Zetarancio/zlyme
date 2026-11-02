---
name: zlyme-documentation
description: Route edits and reconciliation of Zlyme documentation, including the README, the user guide, the changelog, release notes, and a technical document checked against the contract that owns the behavior.
---

# Zlyme documentation

Follow `AGENTS.md`. This skill does not replace `AGENTS.md` or `docs/WRITING.md`.

Before changing documentation:

1. Read `docs/WRITING.md`.
2. Read the document being changed.
3. When a sentence states behavior, read the technical document that owns that behavior. Do not copy that contract into the page being edited.
4. Keep the protected headings, anchors, references, and credit and license notices named in `docs/WRITING.md`.
5. Leave research history, failed tests, dates, SHAs, and superseded decisions where they are. A later dated note can point at the current document.
6. Keep a statement of current behavior separate from a historical experiment.
7. Do not move a contract to another document. `AGENTS.md` and `docs/WRITING.md` already say what may change and what has to stay.
8. Keep `docs/ROADMAP.md` a short, non-normative sequencing map. Do not paste a technical contract into it.
9. When an edit changes documentation, run `python3 scripts/tests/test_doc_links.py` and `python3 scripts/tests/test_doc_contracts.py`.
10. A host test is not Miyoo Flip acceptance. `AGENTS.md` keeps those results separate.
11. A firmware image, a release, or a dangerous device operation still needs the authorization `AGENTS.md` already requires.
12. Do not change an unrelated document in the same edit.
