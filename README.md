## DSSE

---

DSSE generates simulation transcripts from a pinned scenario manifest, seals the results with cryptographic hashes, and allows independent verification without modifying artifacts.

Key capabilities:

- Deterministic execution from fixed inputs
- Canonical JSON transcripts
- SHA-256 sealing of runs
- Non-mutating replay verification
- Golden test vectors
- Deterministic receipt generation
- Freeze manifests for release integrity

---

## Core artifacts

### Scenario manifest

`dsse.scenario.manifest.v1`

Defines simulation inputs.


seed_u64 = 0x + 16 hex characters


---

### Transcript

`transcript.ndjson`

Each line is canonical JSON:


dsse.transcript.event.v1


Each event includes a deterministic `event_hash`.

---

### Run seal

`seal.json`


dsse.run.seal.v1


Contains:


scenario_manifest_sha256
transcript_sha256


---

### Replay verification

Verification recomputes hashes and validates the seal.

This process is **non-mutating** — no files are modified.

---

## Repository layout


scripts/
_dsse_runtime_v1.ps1 runtime (run + seal + replay verify)
_selftest_dsse_v1.ps1 deterministic self-test

schemas/
JSON schemas

test_vectors/
deterministic validation scenarios

proofs/
receipts, runs, and verification artifacts

_out/
local outputs (ignored)

scripts/_scratch/
temporary patch scripts (ignored)


---

## Run the self-test

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File C:\dev\dsse\scripts\_selftest_dsse_v1.ps1 `
  -RepoRoot C:\dev\dsse
Determinism guarantees

DSSE enforces strict reproducibility:

Windows PowerShell 5.1
Set-StrictMode Latest
$ErrorActionPreference = Stop
UTF-8 (no BOM) + LF line endings
Canonical JSON encoding
SHA-256 hashing over canonical bytes

Execution model:

write → parse-gate → execute via child powershell.exe -File
Status

Stable deterministic engine with:

replay verification
vector validation
stress harness
receipt generation
freeze manifest support

---
