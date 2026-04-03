\# DSSE



Deterministic Scenario / Simulation Engine (DSSE)



DSSE produces reproducible simulation transcripts from a pinned scenario manifest.  

Runs are sealed with SHA-256, enabling independent replay verification without modifying original artifacts.



\---



\## Overview



DSSE is designed for deterministic execution:



\- Same inputs → identical outputs

\- Canonical serialization → stable hashing

\- Replay verification → trust without mutation



\---



\## Core artifacts



\### Scenario manifest



`dsse.scenario.manifest.v1`



Defines simulation inputs.



\- `seed\_u64`: `0x` + 16 hex characters



\---



\### Transcript



`transcript.ndjson`



\- One canonical JSON object per line  

\- Schema: `dsse.transcript.event.v1`  

\- Each event includes `event\_hash`



\---



\### Run seal



`seal.json`



Schema: `dsse.run.seal.v1`



Contains:



\- `scenario\_manifest\_sha256`

\- `transcript\_sha256`



This binds the transcript to the exact inputs used.



\---



\### Replay verification



Verification recomputes:



\- manifest hash

\- transcript hash



Then compares against the seal.



Verification is \*\*non-mutating\*\*.



\---



\## Repository layout





scripts/

\_dsse\_runtime\_v1.ps1 runtime library (run, seal, replay verify)

\_selftest\_dsse\_v1.ps1 deterministic selftest



schemas/

JSON schemas



test\_vectors/

simulation test scenarios



proofs/

receipts and execution evidence



\_out/

local outputs (ignored)



scripts/\_scratch/

temporary scripts (ignored)





\---



\## Run the self-test



```powershell

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `

&#x20; -File C:\\dev\\dsse\\scripts\\\_selftest\_dsse\_v1.ps1 `

&#x20; -RepoRoot C:\\dev\\dsse

Determinism guarantees



DSSE enforces strict reproducibility:



Windows PowerShell 5.1

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

UTF-8 (no BOM) + LF line endings

Canonical JSON for all hashed data

SHA-256 over canonical bytes



Execution model:



write → parse → execute (child powershell.exe)



These constraints ensure identical results across independent environments.

