# Sparrow-Cluster session rules

## Purpose and baseline

Milestone-scoped four-core cache-coherent system using Sparrow-V without changing its architectural behavior. Frozen baseline: four cores; private 2 KiB, 2-way, 16-byte L1I/L1D; blocking L1D write-back/write-allocate snoopy MSI; one round-robin shared bus and transaction; shared SRAM/no L2; block-granularity minimal LR.W/SC.W; strong ordering. Do not begin a later milestone early.

Authoritative documents: `docs/architecture.md`, `docs/interface_audit.md`, `docs/cache_architecture.md`, `docs/coherence_protocol.md`, `docs/bus_protocol.md`, `docs/memory_map.md`, and `docs/build_roadmap.md`. Read affected interfaces before changing them. Preserve documented Sparrow-V behavior; stop and document a blocker rather than silently changing architecture.

## Working rules

- Before/after changes run `make check`, `make docs-check`, and relevant focused tests.
- Inspect trees then targeted paths with `rg`/ranges; do not dump or reopen large files. Keep compact findings; inspect only relevant sibling repositories.
- Keep changes milestone-scoped, update tests and canonical docs, and avoid unrelated refactors.
- Do not commit generated artifacts without explicit approval; do not claim correctness/performance without evidence. Label planned targets separately from measured results.
- No interface change without audit and documentation. Do not vendor full Sparrow-V/SparrowML.
- The active work item is `milestones/current.md`. Read it before changes, implement only that milestone, and never begin the next one automatically.
- Maintain `reports/current_milestone_report.md` during a runner-driven milestone using the completion-report fields below and the exact active milestone heading. Stop only with `STATUS: COMPLETE` after the listed gate passes or `STATUS: BLOCKED` with a genuine documented blocker.

## Layout

`rtl/` synthesizable future sources; `tb/` simulation; `sw/` runtime/tests/workloads; `docs/` decisions; `scripts/` deterministic checks; `reports/` ignored outputs.

## Milestone workflow

The user loads one complete specification into `milestones/current.md`, then runs:

```sh
$EDITOR milestones/current.md
make milestone-check
make milestone-run
make milestone-status
```

`make milestone-run` uses a bounded local Codex loop. Set `MILESTONE_MAX_ITERATIONS=8` or pass `--max-iterations 8` to change its default of five iterations. Logs and rotated stale reports stay in ignored `.codex_runs/`. The runner succeeds only when the matching local report says `STATUS: COMPLETE`; it stops unsuccessfully for `STATUS: BLOCKED`, two consecutive no-progress iterations, or its iteration limit. It never commits, pushes, loads the next milestone, or changes sibling repositories. Review the completion report and diff before manually moving the completed specification to `milestones/completed/` and loading another one.

## Completion report

`STATUS: ...`  
`MILESTONE: ...`  
`SUMMARY: ...`  
`IMPLEMENTED: ...`  
`VERIFICATION: ...`  
`RESULTS: ...`  
`FILES CHANGED: ...`  
`LIMITATIONS / OPEN ISSUES: ...`  
`NEXT RECOMMENDED MILESTONE: ...`
