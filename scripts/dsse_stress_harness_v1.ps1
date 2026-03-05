param([Parameter(Mandatory=$true)][string]$RepoRoot,[int]$Runs=10)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Die([string]$m){ throw ("DSSE_STRESS_FAIL: " + $m) }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$rt = Join-Path (Join-Path $RepoRoot "scripts") "_dsse_runtime_v1.ps1"
if(-not (Test-Path -LiteralPath $rt -PathType Leaf)){ Die ("MISSING_RUNTIME: " + $rt) }
. $rt

if($Runs -lt 2){ Die "RUNS_MUST_BE_GE_2" }
$out = Join-Path $RepoRoot "_out"
EnsureDir $out
$base = Join-Path $out "stress_runs"
if(Test-Path -LiteralPath $base){ Remove-Item -LiteralPath $base -Recurse -Force }
EnsureDir $base

$manPath = Join-Path $base "scenario_manifest.json"
$m = DSSE-NewScenarioManifestV1 -Seed ([UInt64]0x0123456789abcdef) -DeviceCount 50 -Ticks 5 -PacketLossP 0.10 -CorruptDeviceIdx @(7,42)
Write-CanonJson -Path $manPath -Obj $m

$first = $null
for($i=1; $i -le $Runs; $i++){
  $rd = Join-Path $base ("run" + $i)
  EnsureDir $rd
  $r = DSSE-RunScenarioV1 -RunDir $rd -ScenarioManifestPath $manPath
  $h = [string]$r.seal.transcript_sha256
  if([string]::IsNullOrWhiteSpace($h)){ Die ("MISSING_TRANSCRIPT_SHA_AT_RUN_" + $i) }
  if($first -eq $null){ $first = $h } else { if($h -ne $first){ Die ("HASH_MISMATCH_AT_RUN_" + $i + ": " + $first + " vs " + $h) } }
  DSSE-ReplayVerifyV1 -RunDir $rd -ScenarioManifestPath $manPath | Out-Null
}

Write-Host ("DSSE_STRESS_OK: runs=" + $Runs + " transcript_sha256=" + $first) -ForegroundColor Green
