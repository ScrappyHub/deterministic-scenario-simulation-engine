param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$EventType,
  [Parameter(Mandatory=$true)][bool]$Ok,
  [string]$Token = "",
  [string]$TranscriptSha256 = "",
  [string]$ManifestSha256 = "",
  [string]$VectorId = "",
  [string]$RunDir = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Write-Utf8NoBomLf {
  param([string]$Path,[string]$Text)
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}
$receiptPath = Join-Path (Join-Path (Join-Path $RepoRoot "proofs") "receipts") "dsse.ndjson"
$obj = [ordered]@{}
$obj.schema = "dsse.receipt.v1"
$obj.event_type = $EventType
$obj.ok = [bool]$Ok
$obj.token = $Token
$obj.repo_root = $RepoRoot
$obj.run_dir = $RunDir
$obj.vector_id = $VectorId
$obj.transcript_sha256 = $TranscriptSha256
$obj.manifest_sha256 = $ManifestSha256
$line = ($obj | ConvertTo-Json -Compress)
if(Test-Path -LiteralPath $receiptPath -PathType Leaf){
  $prev = Get-Content -Raw -LiteralPath $receiptPath -Encoding UTF8
  Write-Utf8NoBomLf -Path $receiptPath -Text ($prev + $line + "`n")
} else {
  Write-Utf8NoBomLf -Path $receiptPath -Text ($line + "`n")
}
Write-Host ("DSSE_RECEIPT_OK: " + $EventType) -ForegroundColor Green
