Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Die([string]$m){ throw $m }
function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "EnsureDir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$Path,[string]$Text){ if([string]::IsNullOrWhiteSpace($Path)){ Die "Write-Utf8NoBomLf: empty Path" }; $t=($Text -replace "`r`n","`n") -replace "`r","`n"; if(-not $t.EndsWith("`n")){ $t+="`n" }; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$t,$enc) }
function Sha256HexBytes([byte[]]$Bytes){ if($null -eq $Bytes){ $Bytes=@() }; $sha=[System.Security.Cryptography.SHA256]::Create(); try { $h=$sha.ComputeHash($Bytes); (($h | ForEach-Object { $_.ToString("x2") }) -join "") } finally { $sha.Dispose() } }
function Sha256HexFile([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("Sha256HexFile: missing: " + $Path) }; Sha256HexBytes ([System.IO.File]::ReadAllBytes($Path)) }
function _JsonEscape([string]$s){ if($null -eq $s){ return "null" }; $sb=New-Object System.Text.StringBuilder; [void]$sb.Append('"'); for($i=0;$i -lt $s.Length;$i++){ $c=[int][char]$s[$i]; switch($c){ 34{[void]$sb.Append('\\"');continue};92{[void]$sb.Append('\\\\');continue};8{[void]$sb.Append('\\b');continue};9{[void]$sb.Append('\\t');continue};10{[void]$sb.Append('\\n');continue};12{[void]$sb.Append('\\f');continue};13{[void]$sb.Append('\\r');continue};default{ if($c -lt 32){[void]$sb.Append(('\\u'+$c.ToString('x4')));continue}; [void]$sb.Append([char]$c) } } }; [void]$sb.Append('"'); $sb.ToString() }
function To-CanonJson($obj){ if($null -eq $obj){ return "null" }; if($obj -is [bool]){ return ($(if($obj){"true"}else{"false"})) }; if($obj -is [string]){ return (_JsonEscape $obj) }; if($obj -is [char]){ return (_JsonEscape ([string]$obj)) }; if($obj -is [int] -or $obj -is [long] -or $obj -is [int64]){ return ([string]$obj) }; if($obj -is [decimal]){ return ($obj.ToString([System.Globalization.CultureInfo]::InvariantCulture)) }; if($obj -is [double] -or $obj -is [single]){ return ($obj.ToString("R",[System.Globalization.CultureInfo]::InvariantCulture)) }; $id=$obj -as [System.Collections.IDictionary]; if($null -ne $id){ $keys=@(@($id.Keys) | ForEach-Object { [string]$_ } | Sort-Object); $parts=New-Object "System.Collections.Generic.List[string]"; foreach($k in $keys){ $v=$id[$k]; [void]$parts.Add((_JsonEscape $k)+":"+ (To-CanonJson $v)) }; return "{"+(($parts.ToArray()) -join ",")+"}" }; if($obj -is [System.Collections.IEnumerable]){ $parts=New-Object "System.Collections.Generic.List[string]"; foreach($it in $obj){ [void]$parts.Add((To-CanonJson $it)) }; return "["+(($parts.ToArray()) -join ",")+"]" }; $props=$obj.PSObject.Properties | ForEach-Object { $_.Name }; if($null -ne $props){ $h=@{}; foreach($p in $props){ $h[$p]=$obj.$p }; return (To-CanonJson $h) }; return (_JsonEscape ([string]$obj)) }
function Write-CanonJson([string]$Path,$Obj){ Write-Utf8NoBomLf -Path $Path -Text (To-CanonJson $Obj) }
function New-Rng([UInt64]$Seed){ if($Seed -eq 0){ $Seed = 88172645463325252 } ; return @{ s = [UInt64]$Seed } }
function Rng-NextU64([hashtable]$R){
  $x = [UInt64]$R.s
  $x = $x -bxor ($x -shr 12)
  $x = $x -bxor ($x -shl 25)
  $x = $x -bxor ($x -shr 27)
  $R.s = [UInt64]$x
  # xorshift64* multiply must wrap mod 2^64 (avoid float/scientific notation paths)
  $mod = [System.Numerics.BigInteger]1 -shl 64
  $mul = ([System.Numerics.BigInteger]$x) * ([System.Numerics.BigInteger]2685821657736338717)
  $mul = $mul % $mod
  return [UInt64]$mul
}
function Rng-Next01([hashtable]$R){ $u = Rng-NextU64 $R; $v = [double]($u -shr 11); return ($v / [double]9007199254740992.0) }
function DSSE-NewScenarioManifestV1([UInt64]$Seed,[int]$DeviceCount,[int]$Ticks,[double]$PacketLossP,[int[]]$CorruptDeviceIdx){ $cd=@(@($CorruptDeviceIdx) | Sort-Object); @{ schema="dsse.scenario.manifest.v1"; seed_u64=("0x"+$Seed.ToString("x16")); world=@{ device_count=$DeviceCount; ticks=$Ticks }; models=@{ packet_loss=@{ kind="bernoulli.v1"; p=$PacketLossP }; timing=@{ kind="tick.v1"; dt_ms=1000 }; adversary=@{ kind="static_set.v1"; corrupt_device_idx=$cd } }; output=@{ transcript="transcript.ndjson"; seal="seal.json" } } }
function DSSE-RunScenarioV1([string]$RunDir,[string]$ScenarioManifestPath){ if(-not (Test-Path -LiteralPath $ScenarioManifestPath -PathType Leaf)){ Die ("SCENARIO_MANIFEST_MISSING: " + $ScenarioManifestPath) }; EnsureDir $RunDir; $manRaw=Get-Content -Raw -LiteralPath $ScenarioManifestPath -Encoding UTF8; $man=$manRaw | ConvertFrom-Json -ErrorAction Stop; if([string]$man.schema -ne "dsse.scenario.manifest.v1"){ Die ("SCENARIO_SCHEMA_UNSUPPORTED: " + [string]$man.schema) }; $seedHex=[string]$man.seed_u64; if(-not $seedHex.StartsWith("0x")){ Die "SEED_FORMAT: expected 0x..." }; $seed=[UInt64]::Parse($seedHex.Substring(2), [System.Globalization.NumberStyles]::HexNumber); $rng=New-Rng $seed; $n=[int]$man.world.device_count; $ticks=[int]$man.world.ticks; $pLoss=[double]$man.models.packet_loss.p; $corrupt=@(@($man.models.adversary.corrupt_device_idx)); $transcriptPath=Join-Path $RunDir "transcript.ndjson"; $enc=New-Object System.Text.UTF8Encoding($false); $fs=New-Object System.IO.FileStream($transcriptPath,[System.IO.FileMode]::Create,[System.IO.FileAccess]::Write,[System.IO.FileShare]::Read); $sw=New-Object System.IO.StreamWriter($fs,$enc); try { $prev=New-Object "System.Collections.Generic.Dictionary[int,string]"; for($i=0;$i -lt $n;$i++){ $prev[$i]="sha256:" + ("0"*64) }; for($t=0;$t -lt $ticks;$t++){ for($i=0;$i -lt $n;$i++){ $r=Rng-Next01 $rng; $dropped=($r -lt $pLoss); $ev=@{ schema="dsse.transcript.event.v1"; tick=$t; device_idx=$i; kind="heartbeat.v1"; dropped=$dropped; prev_hash=$prev[$i] }; $isCorrupt=($corrupt -contains $i); if($isCorrupt -and $t -eq 1){ $ev.kind="heartbeat.corrupt.v1"; $ev.prev_hash="sha256:" + ("f"*64); $ev.fault=@{ key="FORK_INJECTED"; proof="prev_hash_rewritten" } }; $ev2=@{}; foreach($k in @(@($ev.Keys) | Sort-Object)){ $ev2[$k]=$ev[$k] }; $canon=To-CanonJson $ev2; $b=$enc.GetBytes($canon); $h="sha256:" + (Sha256HexBytes $b); $ev2.event_hash=$h; $sw.WriteLine((To-CanonJson $ev2)); if(-not $dropped){ $prev[$i]=$h } } } } finally { $sw.Flush(); $sw.Dispose(); $fs.Dispose() }; $manHex=Sha256HexFile $ScenarioManifestPath; $trHex=Sha256HexFile $transcriptPath; $seal=@{ schema="dsse.run.seal.v1"; scenario_manifest_sha256=("sha256:"+$manHex); transcript_sha256=("sha256:"+$trHex) }; Write-CanonJson -Path (Join-Path $RunDir "seal.json") -Obj $seal; @{ run_dir=$RunDir; seal=$seal } }
function DSSE-ReplayVerifyV1([string]$RunDir,[string]$ScenarioManifestPath){ $transcriptPath=Join-Path $RunDir "transcript.ndjson"; $sealPath=Join-Path $RunDir "seal.json"; if(-not (Test-Path -LiteralPath $transcriptPath -PathType Leaf)){ Die "TRANSCRIPT_MISSING" }; if(-not (Test-Path -LiteralPath $sealPath -PathType Leaf)){ Die "SEAL_MISSING" }; $seal=(Get-Content -Raw -LiteralPath $sealPath -Encoding UTF8) | ConvertFrom-Json -ErrorAction Stop; $manHex="sha256:" + (Sha256HexFile $ScenarioManifestPath); $trHex="sha256:" + (Sha256HexFile $transcriptPath); if([string]$seal.scenario_manifest_sha256 -ne $manHex){ Die "REPLAY_FAIL: MANIFEST_HASH_MISMATCH" }; if([string]$seal.transcript_sha256 -ne $trHex){ Die "REPLAY_FAIL: TRANSCRIPT_HASH_MISMATCH" }; @{ ok=$true; scenario_manifest_sha256=$manHex; transcript_sha256=$trHex } }

# =========================================================
# DSSE PATCH v2: seed coercion + manifest seed hex string
# Appended overrides; last definition wins.
# =========================================================

function DSSE-CoerceSeedU64($Seed){
  function _Die([string]$m){ throw $m }
  if($null -eq $Seed){ _Die "SEED_NULL" }
  if($Seed -is [UInt64]){ $u=[UInt64]$Seed; if($u -eq 0){ return [UInt64]88172645463325252 }; return $u }
  if($Seed -is [int] -or $Seed -is [long] -or $Seed -is [int64]){ if([long]$Seed -lt 0){ _Die "SEED_NEGATIVE" }; $u=[UInt64][long]$Seed; if($u -eq 0){ return [UInt64]88172645463325252 }; return $u }
  if($Seed -is [string]){
    $s=[string]$Seed
    if($s.StartsWith("0x")){ $u=[UInt64]::Parse($s.Substring(2),[System.Globalization.NumberStyles]::HexNumber) } else { $u=[UInt64]::Parse($s,[System.Globalization.CultureInfo]::InvariantCulture) }
    if($u -eq 0){ return [UInt64]88172645463325252 }; return [UInt64]$u
  }
  if($Seed -is [double] -or $Seed -is [single] -or $Seed -is [decimal]){ _Die ("SEED_FLOAT_UNSUPPORTED: " + [string]$Seed) }
  _Die ("SEED_TYPE_UNSUPPORTED: " + $Seed.GetType().FullName)
}

function DSSE-NewScenarioManifestV1($Seed,[int]$DeviceCount,[int]$Ticks,[double]$PacketLossP,[int[]]$CorruptDeviceIdx){
  $u = DSSE-CoerceSeedU64 $Seed
  $cd = @(@($CorruptDeviceIdx) | Sort-Object)
  return @{ schema="dsse.scenario.manifest.v1"; seed_u64=("0x" + $u.ToString("x16")); world=@{ device_count=$DeviceCount; ticks=$Ticks }; models=@{ packet_loss=@{ kind="bernoulli.v1"; p=$PacketLossP }; timing=@{ kind="tick.v1"; dt_ms=1000 }; adversary=@{ kind="static_set.v1"; corrupt_device_idx=$cd } }; output=@{ transcript="transcript.ndjson"; seal="seal.json" } }
}

function DSSE-RunScenarioV1([string]$RunDir,[string]$ScenarioManifestPath){
  if(-not (Test-Path -LiteralPath $ScenarioManifestPath -PathType Leaf)){ throw ("SCENARIO_MANIFEST_MISSING: " + $ScenarioManifestPath) }
  EnsureDir $RunDir
  $manRaw = Get-Content -Raw -LiteralPath $ScenarioManifestPath -Encoding UTF8
  $man = $manRaw | ConvertFrom-Json -ErrorAction Stop
  if([string]$man.schema -ne "dsse.scenario.manifest.v1"){ throw ("SCENARIO_SCHEMA_UNSUPPORTED: " + [string]$man.schema) }
  $seed = DSSE-CoerceSeedU64 ([string]$man.seed_u64)
  $rng = New-Rng $seed
  $n=[int]$man.world.device_count; $ticks=[int]$man.world.ticks; $pLoss=[double]$man.models.packet_loss.p
  $corrupt = @(@($man.models.adversary.corrupt_device_idx))
  $transcriptPath = Join-Path $RunDir "transcript.ndjson"
  $enc=New-Object System.Text.UTF8Encoding($false)
  $fs=New-Object System.IO.FileStream($transcriptPath,[System.IO.FileMode]::Create,[System.IO.FileAccess]::Write,[System.IO.FileShare]::Read)
  $sw=New-Object System.IO.StreamWriter($fs,$enc)
  try {
    $prev = New-Object "System.Collections.Generic.Dictionary[int,string]"
    for($i=0;$i -lt $n;$i++){ $prev[$i] = "sha256:" + ("0"*64) }
    for($t=0;$t -lt $ticks;$t++){
      for($i=0;$i -lt $n;$i++){
        $r=Rng-Next01 $rng; $dropped=($r -lt $pLoss)
        $ev=@{ schema="dsse.transcript.event.v1"; tick=$t; device_idx=$i; kind="heartbeat.v1"; dropped=$dropped; prev_hash=$prev[$i] }
        $isCorrupt = ($corrupt -contains $i)
        if($isCorrupt -and $t -eq 1){ $ev.kind="heartbeat.corrupt.v1"; $ev.prev_hash="sha256:" + ("f"*64); $ev.fault=@{ key="FORK_INJECTED"; proof="prev_hash_rewritten" } }
        $ev2=@{}; foreach($k in @(@($ev.Keys) | Sort-Object)){ $ev2[$k]=$ev[$k] }
        $canon = To-CanonJson $ev2
        $b=$enc.GetBytes($canon); $h="sha256:" + (Sha256HexBytes $b)
        $ev2.event_hash=$h
        $sw.WriteLine((To-CanonJson $ev2))
        if(-not $dropped){ $prev[$i]=$h }
      }
    }
  } finally { $sw.Flush(); $sw.Dispose(); $fs.Dispose() }
  $manHex = Sha256HexFile $ScenarioManifestPath; $trHex = Sha256HexFile $transcriptPath
  $seal=@{ schema="dsse.run.seal.v1"; scenario_manifest_sha256=("sha256:" + $manHex); transcript_sha256=("sha256:" + $trHex) }
  Write-CanonJson -Path (Join-Path $RunDir "seal.json") -Obj $seal
  return @{ run_dir=$RunDir; seal=$seal }
}

