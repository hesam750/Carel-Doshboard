param(
  [string]$DeviceHost = '169.254.61.68'
)

$ErrorActionPreference = 'Stop'

$base = "http://$DeviceHost/commissioning"

function MakeUri([string]$path, [string]$qs){ $u = "$base/$path"; if($qs){ $u += ('?' + $qs) }; return $u }
function TryPostForm([string]$path, [string]$body){
  $url = MakeUri $path ''
  try { return (& curl.exe -s -X POST $url -H 'Content-Type: application/x-www-form-urlencoded' --data $body) | Out-String } catch { return $_.Exception.Message }
}
function TryGet([string]$path, [string]$qs){
  $url = MakeUri $path $qs
  try { return Invoke-WebRequest -UseBasicParsing -Method Get -Uri $url -TimeoutSec 10 } catch { return $_.Exception.Message }
}
function Show([string]$title, $resp){ if($resp -is [string]){ Write-Host ("{0} -> {1}" -f $title, $resp) } else { Write-Host ("{0} -> Status={1}" -f $title, $resp.StatusCode) } }

function GetLines(){
  $r = TryGet 'getvar.csv' ''
  if($r -is [string]){ return ($r -split "`n") }
  return ($r.Content -split "`n")
}

function FindIdByExact([string]$name, [string[]]$lines){
  $pat = '"' + [regex]::Escape($name) + '"\s*,\s*(\d+)\s*,'
  foreach($ln in $lines){ $m = [regex]::Match($ln, $pat); if($m.Success){ return [int]$m.Groups[1].Value } }
  return $null
}

function WriteByName([string]$name, [string]$value){
  $n = [System.Uri]::EscapeDataString($name)
  $v = [System.Uri]::EscapeDataString($value)
  Show ('GET var=' + $name + ' val=' + $value) (TryGet 'setvar.csv' ('var=' + $n + '&val=' + $v))
  Show ('POST var=' + $name + ' val=' + $value) (TryPostForm 'setvar.csv' ('var=' + $n + '&val=' + $v))
}

Write-Host '=== BEGIN force_on_candidates ==='

# Unlock manufacturer best-effort
Show 'POST PwdManuf=4189' (TryPostForm 'setvar.csv' 'id=8098&value=4189')

$lines = GetLines

# Candidate power/on-off names
$candidates = @(
  'UnitOnOff',
  'OnOff',
  'OnOffUnit',
  'UnitEnable',
  'Enable',
  'Power',
  'Start',
  'RemoteOnOff'
)

# Try to write each candidate to 1, then save and read CurrUnitStatus
foreach($name in $candidates){
  Write-Host ("-- Trying power candidate: " + $name)
  WriteByName $name '1'
  Show 'POST SaveData=1' (TryPostForm 'setvar.csv' 'id=8376&value=1')
  Start-Sleep -Milliseconds 500
  $resp = TryGet 'getvar.csv' 'id=5541'
  if($resp -is [string]){ Write-Host ("READ CurrUnitStatus => " + $resp.Trim()) }
  else { Write-Host ("READ CurrUnitStatus => " + ($resp.Content).Trim()) }
}

# Also read current setpoint to see any change
$resp2 = TryGet 'getvar.csv' 'id=5539'
if($resp2 -is [string]){ Write-Host ("READ CurrRoomTempSetP_Val => " + $resp2.Trim()) }
else { Write-Host ("READ CurrRoomTempSetP_Val => " + ($resp2.Content).Trim()) }

Write-Host '=== END force_on_candidates ==='