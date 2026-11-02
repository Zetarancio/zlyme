---
name: zlyme-documentation
description: Route edits and reconciliation of Zlyme documentation, including the README, the user guide, the changelog, release notes, and a technical document checked against the contract that owns the behavior.
---

# Zlyme documentation

Follow `AGENTS.md`. This skill does not replace `AGENTS.md` or `docs/WRITING.md`.

Before changing documentation:

1. Read `docs/WRITING.md`.
2. Read the document being changed.
3. When a sentence states behavior, read the technical document that owns that behavior. Link to that contract instead of copying its description. A user-facing page may state a necessary fact the evidence supports. When an exact value is repeated, keep it consistent with the existing contract test. Do not change technical meaning without the review that change requires.
4. Keep the protected headings, anchors, references, and credit and license notices named in `docs/WRITING.md`. Change one only when the maintainer explicitly authorizes a change that `docs/WRITING.md` permits. Do not remove a heading silently.
5. Leave research history, failed tests, dates, SHAs, and superseded decisions where they are. A later dated note can point at the current document.
6. Keep a statement of current behavior separate from a historical experiment.
7. Do not relocate an authoritative contract unless the maintainer explicitly authorizes the move and the preservation, reference, and validation requirements in the Phase 17 plan, `docs/research/phase-17-plan.md`, are satisfied. An authorization to relocate a contract does not authorize changing its meaning.
8. Keep `docs/ROADMAP.md` a short, non-normative sequencing map. Do not paste a technical contract into it.
9. When an edit changes documentation, run `python3 scripts/tests/test_doc_links.py` and `python3 scripts/tests/test_doc_contracts.py`.
10. A host test is not Miyoo Flip acceptance. `AGENTS.md` keeps those results separate.
11. A firmware image, a release, or a dangerous device operation still needs the authorization `AGENTS.md` already requires.
12. Do not change an unrelated document in the same edit.
