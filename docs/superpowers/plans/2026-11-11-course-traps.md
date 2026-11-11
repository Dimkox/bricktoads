# Remaining course prop implementation

**Goal:** Replace all 28 remaining course primitive presentations and verify them through Studio MCP.

**Design:** ../specs/2026-11-11-course-traps-design.md

**Execution:** Three independent workers own pinned references, generated assets, and packaging/native fixture. Root owns production runtime, client visibility, MCP import/testing, review and delivery.

- [x] Decode and document source references, separating direct evidence from authored interpretation.
- [x] Generate 28 closed textured flat templates, inspect previews and freeze geometry/provenance.
- [x] Add runtime fitting, bounded animation and lifecycle with failing then passing behavioral tests.
- [x] Extend the client loading gate with an independent prop contract and regression coverage.
- [x] Upload/import using MCP, export actual resources and pass strict packaging tests.
- [ ] Verify all 28 kinds and actual course states in native Studio, then client resource readiness and campaign integration.
- [ ] Restore exact production sources, remove owned QA, run relevant regressions and independent review.
- [ ] Commit/push, check exact-head CI and synchronize factual Jira results.
