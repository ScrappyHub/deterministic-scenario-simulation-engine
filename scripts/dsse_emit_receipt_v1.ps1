param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$EventType,
  [Parameter(Mandatory=$true)]$Ok,
  [Parameter(Mandatory=$true)][string]$RunDir,
  [string]$Token = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Die([string]$m){ throw ("DSSE_RECEIPT_FAIL: " + $m) }
function Utf8NoBom(){ New-Object System.Text.UTF8Encoding($false) }
function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ return }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$Path,[string]$Text){ $dir=Split-Path -Parent $Path; EnsureDir $dir; $t=($Text -replace "`r`n","`n") -replace "`r","`n"; if(-not $t.EndsWith("`n")){ $t += "`n" }; [System.IO.File]::WriteAllText($Path,$t,(Utf8NoBom)) }
function Sha256HexFile([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("MISSING_HASH_FILE: " + $Path) }; $sha=[System.Security.Cryptography.SHA256]::Create(); try { $bytes=[System.IO.File]::ReadAllBytes($Path); $h=$sha.ComputeHash($bytes); (($h | ForEach-Object { $_.ToString("x2") }) -join "") } finally { $sha.Dispose() } }
function To-Bool($v){
  if($v -is [bool]){ return [bool]$v }
  if($v -is [byte] -or $v -is [int16] -or $v -is [int32] -or $v -is [int64]){ return ([int64]$v -ne 0) }
  $s = ([string]$v).Trim().ToLowerInvariant()
  if($s -in @("true","1","yes","y","ok","pass")){ return $true }
  if($s -in @("false","0","no","n","fail")){ return $false }
  Die ("BAD_OK_VALUE: " + [string]$v)
}
function To-CanonJson($obj){
  return ($obj | ConvertTo-Json -Compress -Depth 10)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$RunDir   = (Resolve-Path -LiteralPath $RunDir).Path
$OkBool   = To-Bool $Ok
$receiptsDir = Join-Path (Join-Path $RepoRoot "proofs") "receipts"
EnsureDir $receiptsDir
$receiptPath = Join-Path $receiptsDir "dsse.ndjson"
$stdoutPath = Join-Path $RunDir "stdout.txt"
$statusPath = Join-Path $RunDir "status.txt"
$obj = [ordered]@{
  schema = "dsse.receipt.v1"
  event_type = [string]$EventType
  ok = [bool]$OkBool
  token = [string]$Token
  run_dir = [string]$RunDir
  stdout_sha256 = $(if(Test-Path -LiteralPath $stdoutPath -PathType Leaf){ "sha256:" + (Sha256HexFile $stdoutPath) } else { $null })
  status_sha256 = $(if(Test-Path -LiteralPath $statusPath -PathType Leaf){ "sha256:" + (Sha256HexFile $statusPath) } else { $null })
}
$line = To-CanonJson $obj
Add-Content -LiteralPath $receiptPath -Value $line -Encoding utf8
Write-Host ("DSSE_RECEIPT_OK: " + $receiptPath) -ForegroundColor Green
