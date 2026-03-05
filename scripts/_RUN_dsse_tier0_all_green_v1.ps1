param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Die([string]$m){ throw ("DSSE_TIER0_FAIL: " + $m) }
function ParseGatePs1([string]$p){ $tok=$null; $err=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$tok,[ref]$err); if($err -and $err.Count -gt 0){ $e=$err[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $p,$e.Extent.StartLineNumber,$e.Extent.StartColumnNumber,$e.Message) } }

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$scripts = Join-Path $RepoRoot "scripts"
$ps = (Get-Command powershell.exe -ErrorAction Stop).Source

$all = @(
  (Join-Path $scripts "_dsse_runtime_v1.ps1"),
  (Join-Path $scripts "_selftest_dsse_v1.ps1"),
  (Join-Path $scripts "dsse_verify_vectors_v1.ps1"),
  (Join-Path $scripts "dsse_stress_harness_v1.ps1")
)
foreach($p in @($all)){ if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ Die ("MISSING_SCRIPT: " + $p) }; ParseGatePs1 $p }

& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $scripts "_selftest_dsse_v1.ps1") -RepoRoot $RepoRoot | Out-Host
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $scripts "dsse_verify_vectors_v1.ps1") -RepoRoot $RepoRoot | Out-Host
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $scripts "dsse_stress_harness_v1.ps1") -RepoRoot $RepoRoot -Runs 10 | Out-Host

Write-Host "DSSE_TIER0_ALL_GREEN" -ForegroundColor Green
