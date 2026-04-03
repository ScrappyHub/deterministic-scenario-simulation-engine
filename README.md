# DSSE

Deterministic Scenario / Simulation Engine (DSSE)

DSSE enables reproducible scenario execution using canonical transcripts, SHA-256 sealing, and deterministic replay verification.

Runs are fully deterministic: the same inputs always produce identical outputs.

---

## Overview

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
