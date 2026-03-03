# DSSE Tier-0 WBS and Definition of Done

What this project is (to spec)
- Tier-0 standalone deterministic scenario/simulation engine
- Input: pinned scenario manifest
- Output: transcript.ndjson + seal.json
- Verification: non-mutating replay verify (recompute + compare; never edits)
- Offline only; no external services; not a truth oracle

Instrument environment (locked)
- Windows PowerShell 5.1
- Set-StrictMode Latest
- ErrorActionPreference=Stop
- Deterministic workflow: write to disk UTF-8 no BOM LF -> parse-gate ps1 -> child powershell.exe -File

WBS status
- DSSE-01 Repo and discipline (git + LF + ignores) : GREEN
- DSSE-02 Runtime and selftest (run + seal + replay verify) : GREEN
- DSSE-03 Docs (README + this WBS/DoD) : YELLOW
- DSSE-04 Golden vectors (>=1 positive, >=3 negative) : RED
- DSSE-05 Receipt layer (append-only proofs/receipts) : RED
- DSSE-06 Stress harness (rerun stability + evidence) : RED
- DSSE-07 Full-green runner (one command; prints DSSE_TIER0_ALL_GREEN only on success) : RED
- DSSE-08 Release freeze (re-tag Tier-0 only after DSSE-07 GREEN) : RED

Definition of Done (Tier-0)
1) Identical manifest yields byte-identical transcript and seal across reruns/machines
2) Canonical hashing stable (UTF-8 no BOM LF; no float/scientific drift)
3) Replay verification validates without mutating artifacts
4) Golden vectors exist (>=1 positive, >=3 negative) with deterministic PASS/FAIL tokens
5) Append-only receipts exist and are deterministic for vectors/selftests
6) Stress harness proves stability and emits deterministic evidence
7) One runner is GREEN on a clean machine and prints DSSE_TIER0_ALL_GREEN
