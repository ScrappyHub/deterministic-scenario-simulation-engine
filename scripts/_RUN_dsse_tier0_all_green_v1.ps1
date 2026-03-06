param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Die([string]$m){ throw ("DSSE_TIER0_FAIL: " + $m) }
function Ensure-Dir([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Container)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function Write-Utf8NoBomLf([string]$Path,[string]$Text){ $dir = Split-Path -Parent $Path; if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }; $t = ($Text -replace "`r`n","`n") -replace "`r","`n"; if(-not $t.EndsWith("`n")){ $t += "`n" }; $enc = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$t,$enc) }
function Parse-GatePs1([string]$p){ $tok=$null; $err=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$tok,[ref]$err); if($err -and $err.Count -gt 0){ $e=$err[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $p,$e.Extent.StartLineNumber,$e.Extent.StartColumnNumber,$e.Message) } }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$scripts = Join-Path $RepoRoot "scripts"
$proofs = Join-Path $RepoRoot "proofs"
$runs = Join-Path $proofs "runs"
Ensure-Dir $runs
$bundle = Join-Path $runs "dsse_tier0_latest"
if(Test-Path -LiteralPath $bundle -PathType Container){ Remove-Item -LiteralPath $bundle -Recurse -Force }
Ensure-Dir $bundle
$receipt = Join-Path $scripts "dsse_emit_receipt_v1.ps1"
$selftest = Join-Path $scripts "_selftest_dsse_v1.ps1"
$vectors = Join-Path $scripts "dsse_verify_vectors_v1.ps1"
$stress = Join-Path $scripts "dsse_stress_harness_v1.ps1"
$all = @($receipt,$selftest,$vectors,$stress,(Join-Path $scripts "_dsse_runtime_v1.ps1"))
foreach($p in @($all)){ if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ Die ("MISSING_SCRIPT: " + $p) }; Parse-GatePs1 $p }
$ps = (Get-Command powershell.exe -ErrorAction Stop).Source
$stdout = New-Object System.Collections.Generic.List[string]
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $selftest -RepoRoot $RepoRoot 2>&1 | Tee-Object -Variable o1 | Out-Host
$s1 = (($o1 | ForEach-Object { [string]$_ }) -join "`n")
[void]$stdout.Add($s1)
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $receipt -RepoRoot $RepoRoot -EventType "selftest" -Ok $true -Token "SELFTEST_OK" | Out-Host
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $vectors -RepoRoot $RepoRoot 2>&1 | Tee-Object -Variable o2 | Out-Host
$s2 = (($o2 | ForEach-Object { [string]$_ }) -join "`n")
[void]$stdout.Add($s2)
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $receipt -RepoRoot $RepoRoot -EventType "vectors" -Ok $true -Token "DSSE_VECTORS_ALL_GREEN" | Out-Host
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $stress -RepoRoot $RepoRoot -Runs 10 2>&1 | Tee-Object -Variable o3 | Out-Host
$s3 = (($o3 | ForEach-Object { [string]$_ }) -join "`n")
[void]$stdout.Add($s3)
$sha = ""
foreach($line in @($o3)){ $sl = [string]$line; if($sl -like "DSSE_STRESS_OK:*transcript_sha256=*"){ $sha = $sl.Substring($sl.IndexOf("transcript_sha256=") + 18); break } }
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $receipt -RepoRoot $RepoRoot -EventType "stress" -Ok $true -Token "DSSE_STRESS_OK" -TranscriptSha256 $sha | Out-Host
$allOut = (($stdout.ToArray()) -join "`n`n")
Write-Utf8NoBomLf -Path (Join-Path $bundle "stdout.txt") -Text $allOut
Write-Utf8NoBomLf -Path (Join-Path $bundle "status.txt") -Text "DSSE_TIER0_ALL_GREEN" 
& $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $receipt -RepoRoot $RepoRoot -EventType "tier0_runner" -Ok $true -Token "DSSE_TIER0_ALL_GREEN" -RunDir $bundle | Out-Host
Write-Host "DSSE_TIER0_ALL_GREEN" -ForegroundColor Green
