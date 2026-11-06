# Studio environment implementation plan

> **For agentic workers:** Use superpowers:executing-plans for the local setup and superpowers:verification-before-completion before pushing.

**Goal:** Create and open a blank BrickToads development place, establish a reproducible source-to-place build, verify it, and push the setup to GitHub as requested.

**Architecture:** Extend the existing Python/XML build approach. Keep the existing lifecycle module server-only and the contract harness separate from the development place. The scene is a baseplate and one spawn, with server, client and shared source folders.

**Tech stack:** Roblox Studio, Luau 0.745 CLI, Python 3 standard library, Git.

**Spec:** User request: create an empty Studio project, configure the basic environment, and git push.

## Global constraints

- Preserve the existing lifecycle logic and tests.
- Do not include contract tests or expose the lifecycle module to clients in the development place.
- Keep local tools and temporary files outside version control.
- Save a local development place; publishing a Roblox experience is outside this request.

## Review focus

- Source changes must appear in the next build without manual copy and paste.
- Server-only files must never be mapped into replicated containers.
- Missing source files and duplicate Studio names must fail the build.
- Generated places must actually open in Studio, not merely parse as XML.
- CI must run on the repository's current main branch.

## Task 1: Reproducible blank development place

- [ ] Add build tests covering source mapping, scene spawn geometry, deterministic output, missing source and duplicate names.
- [ ] Run the tests before implementation and confirm the missing-builder failure.
- [ ] Add `tools/build_bricktoads_place.py`, named server/client entry points and `BrickToadsConfig`.
- [ ] Build `places/BrickToads.rbxlx` and run all existing and new checks.
- [ ] Open the generated place and verify server/client startup in Studio through MCP.

## Task 2: Handoff and push

- [ ] Document build/open/check commands and source mapping in README.
- [ ] Update CI to run on main and verify both place builders.
- [ ] Record actual Studio and CLI results; review the changes.
- [ ] Commit and push to origin/main, then verify the remote commit and clean status.
