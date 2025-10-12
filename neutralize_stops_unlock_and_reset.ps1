param(
  [string]$DeviceHost = '169.254.61.68'
)

$ErrorActionPreference = 'Stop'

$base = "http://$DeviceHost/commissioning"

function MakeUri([string]$path, [string]$qs){ $u = "$base/$path"; if($qs){ $u += ('?' + $qs) }; return $u }
function TryPostForm([string]$path, $body){
  $url = MakeUri $path ''
  try {
    $pairs = @(); foreach($kv in $body.GetEnumerator()){ $pairs += ([System.Uri]::EscapeDataString($kv.Key) + '=' + [System.Uri]::EscapeDataString([string]$kv.Value)) }
    $data = ($pairs -join '&')
    return (& curl.exe -s -X POST $url -H 'Content-Type: application/x-www-form-urlencoded' --data $data) | Out-String
  } catch { return $_.Exception.Message }
}
function TryGet([string]$path, [string]$qs){
  $url = MakeUri $path $qs
  try { return Invoke-WebRequest -UseBasicParsing -Method Get -Uri $url -TimeoutSec 12 } catch { return $_.Exception.Message }
}
function Show([string]$title, $resp){ if($resp -is [string]){ Write-Host ("{0} -> {1}" -f $title, $resp) } else { Write-Host ("{0} -> Status={1}" -f $title, $resp.StatusCode) } }

function GetLines(){ $r = TryGet 'getvar.csv' ''; if($r -is [string]){ return ($r -split "`n") } return ($r.Content -split "`n") }
function FindIdByRegex([string]$regex, [string[]]$lines){
  $ln = ($lines | Where-Object { $_ -match $regex } | Select-Object -First 1)
  if(-not $ln){ return $null }
  $parts = $ln.Split(','); if($parts.Length -ge 2){ return [int]$parts[1] }
  return $null
}

Write-Host '=== BEGIN neutralize_stops_unlock_and_reset ==='

# Unlock manufacturer
Show 'POST PwdManuf=4189' (TryPostForm 'setvar.csv' @{ id = 8098; value = '4189' })

$lines = GetLines

# Candidates to clear: Stop/Inhibit/Lock (BOOL RW), Keyboard/Keyb locks, RemoteOff
$patternsClear = @(
  'Lock(?!ed)\b',
  '\bInhibit\b',
  '\bStop\b',
  '\bRemoteOff\b',
  '\bKeyb\w*Lock\b',
  '\bKeyboard\w*Lock\b'
)

foreach($pat in $patternsClear){
  $hits = $lines | Where-Object { $_ -match $pat -and $_ -match ',BOOL,RW,' } | Select-Object -First 50
  foreach($h in $hits){
    $parts = $h.Split(','); if($parts.Length -ge 2){ $id = [int]$parts[1]; Show ('CLEAR '+$parts[0]+' id='+$id+' -> 0') (TryPostForm 'setvar.csv' @{ id = $id; value = '0' }) }
  }
}

# Enable power candidates explicitly
foreach($name in @('UnitOnOff','OnOffUnit','RemoteOnOff')){
  $enc = [System.Uri]::EscapeDataString($name); Show ('SET '+$name+'=1 (GET)') (TryGet 'setvar.csv' ('var='+$enc+'&val=1'))
  Show ('SET '+$name+'=1 (POST)') (TryPostForm 'setvar.csv' ('var='+$enc+'&val=1'))
}

# Reset alarm triggers if present (BOOL RW with .Trigger suffix)
$alarmHits = $lines | Where-Object { $_ -match '\.Trigger"\s*,\s*\d+\s*,[^\r\n]*,BOOL,RW,' } | Select-Object -First 120
foreach($h in $alarmHits){ $parts = $h.Split(','); if($parts.Length -ge 2){ $id = [int]$parts[1]; Show ('RESET ALARM id='+$id+' -> 0') (TryPostForm 'setvar.csv' @{ id = $id; value = '0' }) } }

# Global alarm reset variables if any
foreach($name in @('ResetAlarm','AlarmReset','AlReset')){
  $enc = [System.Uri]::EscapeDataString($name); Show ('TRY '+$name+'=1') (TryPostForm 'setvar.csv' ('var='+$enc+'&val=1'))
}

# Save
Show 'POST SaveData=1' (TryPostForm 'setvar.csv' @{ id = 8376; value = '1' })
Start-Sleep -Milliseconds 800

# Read back unit status and current setpoint
$r1 = TryGet 'getvar.csv' 'id=5541'
if($r1 -is [string]){ Write-Host ('READ CurrUnitStatus => ' + $r1.Trim()) } else { Write-Host ('READ CurrUnitStatus => ' + ($r1.Content).Trim()) }
$r2 = TryGet 'getvar.csv' 'id=5539'
if($r2 -is [string]){ Write-Host ('READ CurrRoomTempSetP_Val => ' + $r2.Trim()) } else { Write-Host ('READ CurrRoomTempSetP_Val => ' + ($r2.Content).Trim()) }

Write-Host '=== END neutralize_stops_unlock_and_reset ==='