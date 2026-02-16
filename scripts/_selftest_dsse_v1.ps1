param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $RepoRoot "scripts\_dsse_runtime_v1.ps1")
$out = Join-Path $RepoRoot "_out"; EnsureDir $out
$manPath = Join-Path $out "scenario.json"
$m = DSSE-NewScenarioManifestV1 -Seed "0x0123456789abcdef" -DeviceCount 100 -Ticks 5 -PacketLossP 0.10 -CorruptDeviceIdx @(7,42)
Write-CanonJson -Path $manPath -Obj $m
$run1 = Join-Path $out "run1"; if(Test-Path -LiteralPath $run1){ Remove-Item -LiteralPath $run1 -Recurse -Force }; EnsureDir $run1
$run2 = Join-Path $out "run2"; if(Test-Path -LiteralPath $run2){ Remove-Item -LiteralPath $run2 -Recurse -Force }; EnsureDir $run2
$r1 = DSSE-RunScenarioV1 -RunDir $run1 -ScenarioManifestPath $manPath
$r2 = DSSE-RunScenarioV1 -RunDir $run2 -ScenarioManifestPath $manPath
if([string]$r1.seal.transcript_sha256 -ne [string]$r2.seal.transcript_sha256){ throw ("DSSE_DETERMINISM_FAIL: " + $r1.seal.transcript_sha256 + " vs " + $r2.seal.transcript_sha256) }
DSSE-ReplayVerifyV1 -RunDir $run1 -ScenarioManifestPath $manPath | Out-Null
Write-Host "SELFTEST_OK: DSSE v1 deterministic run+seal+replay PASS" -ForegroundColor Green
Write-Host ("transcript_sha256=" + [string]$r1.seal.transcript_sha256) -ForegroundColor Gray
