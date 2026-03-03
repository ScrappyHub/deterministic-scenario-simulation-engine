# DSSE

Deterministic Scenario / Simulation Engine (DSSE). Tier-0 standalone, offline.

DSSE generates reproducible simulation transcripts from a pinned scenario manifest, seals runs with SHA-256, and supports non-mutating replay verification.

Core artifacts
- Scenario manifest: dsse.scenario.manifest.v1 (seed_u64 stored as 0x + 16 hex chars)
- Transcript: transcript.ndjson (dsse.transcript.event.v1; canonical JSON per line; includes event_hash)
- Seal: seal.json (dsse.run.seal.v1: scenario_manifest_sha256 + transcript_sha256)
- Replay verify: recompute hashes and validate seal without editing files

Repo layout
- scripts/_dsse_runtime_v1.ps1    runtime library (run + seal + replay verify)
- scripts/_selftest_dsse_v1.ps1    deterministic selftest
- schemas/                        JSON schemas
- _out/                           local run outputs (ignored)
- scripts/_scratch/               patchers/temp (ignored)
- test_vectors/                   NEXT: golden vectors
- proofs/receipts/                NEXT: append-only receipts

Run selftest
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\dev\dsse\scripts\_selftest_dsse_v1.ps1 -RepoRoot C:\dev\dsse

Determinism invariants (Tier-0)
- Windows PowerShell 5.1; StrictMode Latest; ErrorActionPreference=Stop
- UTF-8 no BOM + LF for canonical artifacts
- Canonical JSON for all hashed objects; SHA-256 over canonical bytes
- Write to disk -> parse-gate ps1 -> run via child powershell.exe -File
