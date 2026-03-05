param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
function Die([string]$m){ throw ("DSSE_VECTORS_FAIL: "+$m) }
$rt = Join-Path (Join-Path $RepoRoot "scripts") "_dsse_runtime_v1.ps1"
if(-not (Test-Path -LiteralPath $rt -PathType Leaf)){ Die "MISSING_RUNTIME" }
. $rt
$tv = Join-Path $RepoRoot "test_vectors\v1"
$out = Join-Path $RepoRoot "_out"
EnsureDir $out
$runBase = Join-Path $out "vector_runs"
EnsureDir $runBase
function ReadMeta([string]$p){ (Get-Content -Raw -LiteralPath $p -Encoding UTF8) | ConvertFrom-Json -ErrorAction Stop }
function ExpectFailToken([string]$token,[ScriptBlock]$action){ try{ & $action | Out-Null; Die ("EXPECTED_FAIL_TOKEN_NOT_THROWN: "+$token) } catch { $m=[string]$_.Exception.Message; if($m -notmatch [regex]::Escape($token)){ Die ("FAIL_TOKEN_MISMATCH: expected="+$token+" got="+$m) } } }
$vecDirs = @()
$vecDirs += Get-ChildItem -LiteralPath (Join-Path $tv "positive") -Directory -ErrorAction SilentlyContinue
$vecDirs += Get-ChildItem -LiteralPath (Join-Path $tv "negative") -Directory -ErrorAction SilentlyContinue
if(-not $vecDirs -or $vecDirs.Count -lt 1){ Die "NO_VECTORS_FOUND" }
foreach($d in $vecDirs){
  $metaPath = Join-Path $d.FullName "vector_meta.json"
  $meta = ReadMeta $metaPath
  $kind = [string]$meta.kind
  $id = [string]$meta.vector_id
  $man = Join-Path $d.FullName "scenario_manifest.json"
  if($kind -eq "positive"){
    $runDir = Join-Path $runBase ($id + "_run")
    if(Test-Path -LiteralPath $runDir){ Remove-Item -LiteralPath $runDir -Recurse -Force }
    EnsureDir $runDir
    $r = DSSE-RunScenarioV1 -RunDir $runDir -ScenarioManifestPath $man
    if([string]$r.seal.transcript_sha256 -ne [string]$meta.expected.transcript_sha256){ Die ("POS_TRANSCRIPT_SHA_MISMATCH: "+$id) }
    if([string]$r.seal.scenario_manifest_sha256 -ne [string]$meta.expected.scenario_manifest_sha256){ Die ("POS_MANIFEST_SHA_MISMATCH: "+$id) }
    DSSE-ReplayVerifyV1 -RunDir $runDir -ScenarioManifestPath $man | Out-Null
    Write-Host ("VECTOR_OK: "+$id) -ForegroundColor Green
  } elseif($kind -eq "negative"){
    $exp = Join-Path $d.FullName "expected"
    $runDir = Join-Path $runBase ($id + "_expected_copy")
    if(Test-Path -LiteralPath $runDir){ Remove-Item -LiteralPath $runDir -Recurse -Force }
    EnsureDir $runDir
    Copy-Item -LiteralPath (Join-Path $exp "transcript.ndjson") -Destination (Join-Path $runDir "transcript.ndjson") -Force
    Copy-Item -LiteralPath (Join-Path $exp "seal.json") -Destination (Join-Path $runDir "seal.json") -Force
    $tok = [string]$meta.expected_fail_token
    ExpectFailToken $tok { DSSE-ReplayVerifyV1 -RunDir $runDir -ScenarioManifestPath $man }
    Write-Host ("VECTOR_NEG_OK: "+$id) -ForegroundColor Green
  } else { Die ("UNKNOWN_KIND: "+$kind) }
}
Write-Host "DSSE_VECTORS_ALL_GREEN" -ForegroundColor Green
