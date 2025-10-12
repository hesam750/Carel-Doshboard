param(
  [string]$Device = 'http://169.254.61.68',
  [string]$TargetValue = '25.0'
)

$ErrorActionPreference = 'Stop'

function PostId([int]$id, [string]$val){
  try { $r = curl.exe -s -X POST ($Device.TrimEnd('/') + '/commissioning/setvar.csv') -H 'Content-Type: application/x-www-form-urlencoded' --data ('id='+$id+'&value='+$val); Write-Host ('POST id='+$id+' val='+$val) }
  catch { Write-Host ('POST id='+$id+' ERR '+ $_.Exception.Message) }
}
function PostName([string]$name, [string]$val){
  $n = [System.Uri]::EscapeDataString($name)
  try { $r = curl.exe -s -X POST ($Device.TrimEnd('/') + '/commissioning/setvar.csv') -H 'Content-Type: application/x-www-form-urlencoded' --data ('var='+$n+'&val='+$val); Write-Host ('POST var='+$name+' val='+$val) }
  catch { Write-Host ('POST var='+$name+' ERR '+ $_.Exception.Message) }
}
function ReadId([int]$id, [string]$label){
  try { $c = (Invoke-WebRequest -UseBasicParsing -Uri ($Device.TrimEnd('/') + '/commissioning/getvar.csv?id='+$id) -TimeoutSec 10).Content; Write-Host ('READ '+$label+' ('+$id+') = '+$c.Trim()) }
  catch { Write-Host ('READ '+$label+' ERR ' + $_.Exception.Message) }
}
function GetAll(){ (Invoke-WebRequest -UseBasicParsing -Uri ($Device.TrimEnd('/') + '/commissioning/getvar.csv') -TimeoutSec 10).Content }
function FindIdByRegex([string]$regex){ $lines = GetAll -split "`n"; $ln = ($lines | Where-Object { $_ -match $regex } | Select-Object -First 1); if(-not $ln){ return $null } $parts = $ln.Split(','); if($parts.Length -ge 2){ return [int]$parts[1] } return $null }

Write-Host '=== BEGIN force_comfort ===' -ForegroundColor Cyan

# Unlock manufacturer
PostName 'PwdManuf' '4189'

# Disable schedulers if present
$idToday = FindIdByRegex '"Scheduler_OnOffUnit\.Scheduler_1\.Today\.Enabled"'
$idSpec  = FindIdByRegex '"Scheduler_OnOffUnit\.Scheduler_1\.SpecDay\.Enabled"'
$idHol   = FindIdByRegex '"Scheduler_OnOffUnit\.Scheduler_1\.Holiday\.Enabled"'
$idVac   = FindIdByRegex '"Scheduler_OnOffUnit\.Scheduler_1\.VacationsSched\.Enabled"'
foreach($sid in @($idToday,$idSpec,$idHol,$idVac)){ if($sid){ PostId $sid '0' } }

# Source/write/lock enable if present (CtrlRoomTemp)
$idSourceSel   = FindIdByRegex '"SourceControl\.CtrlRoomTemp\.Source\.Select"'
$idWriteEnable = FindIdByRegex '"SourceControl\.CtrlRoomTemp\.WriteEnable"'
$idLock        = FindIdByRegex '"SourceControl\.CtrlRoomTemp\.Lock"'
if($idSourceSel){ PostId $idSourceSel '1' }
if($idWriteEnable){ PostId $idWriteEnable '1' }
if($idLock){ PostId $idLock '1' }

# Prefer RoomTempSetP source/manact
PostName 'UnitSetP.RoomTempSetP.Source' '1'
PostName 'RoomTempSetP.Source' '1'
PostName 'UnitSetP.RoomTempSetP.ManAct' '1'
PostName 'RoomTempSetP.ManAct' '1'

# Select Comfort if a selection variable exists
$idSel = FindIdByRegex 'RoomTemp.*SetP.*(Sel|Select|Mode|Profile|Active)'
if($idSel){ PostId $idSel '1' }

# Write Comfort value in both decimal formats
$dot   = ([double]([string]$TargetValue.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$comma = $dot.Replace('.', ',')
PostName 'UnitSetP.RoomTempSetP.Comfort' $dot
Start-Sleep -Milliseconds 250
PostName 'UnitSetP.RoomTempSetP.Comfort' $comma

# Also set Manual value to match
PostName 'UnitSetP.RoomTempSetP.Man' $dot
Start-Sleep -Milliseconds 250
PostName 'UnitSetP.RoomTempSetP.Man' $comma

# Save
PostName 'SaveData' '1'
Start-Sleep -Milliseconds 800

# Verify
ReadId 9424 'UnitSetP.RoomTempSetP.Comfort'
ReadId 5539 'CurrRoomTempSetP_Val'

Write-Host '=== END force_comfort ===' -ForegroundColor Green