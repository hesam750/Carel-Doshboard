param(
  [string]$Device = 'http://169.254.61.68',
  [string]$Target = '25.0'
)

$ErrorActionPreference = 'Stop'

function GetAll(){ (Invoke-WebRequest -UseBasicParsing -Uri ($Device.TrimEnd('/') + '/commissioning/getvar.csv') -TimeoutSec 10).Content }
function FindIdByPattern([string]$pattern){
  try {
    $lines = GetAll -split "`n"
    $hit = ($lines | Where-Object { $_ -match $pattern } | Select-Object -First 1)
    if(-not $hit){ return $null }
    $parts = $hit.Split(','); if($parts.Length -ge 2){ return [int]$parts[1] }
  } catch { return $null }
}

function PostById([int]$id, [string]$val){
  if(-not $id){ return }
  try { curl.exe -s -X POST ($Device.TrimEnd('/') + '/commissioning/setvar.csv') -H 'Content-Type: application/x-www-form-urlencoded' --data ('id='+$id+'&value='+$val) | Out-Null; Write-Host ('POST id='+$id+' v='+$val) }
  catch { Write-Host ('POST id='+$id+' ERR '+ $_.Exception.Message) }
}
function PostByName([string]$name, [string]$val){
  try { $n=[System.Uri]::EscapeDataString($name); $v=[System.Uri]::EscapeDataString($val); curl.exe -s -X POST ($Device.TrimEnd('/') + '/commissioning/setvar.csv') -H 'Content-Type: application/x-www-form-urlencoded' --data ('var='+$n+'&val='+$v) | Out-Null; Write-Host ('POST var='+$name+' v='+$val) }
  catch { Write-Host ('POST var='+$name+' ERR '+ $_.Exception.Message) }
}
function ReadId([int]$id, [string]$label){
  try { $c = (Invoke-WebRequest -UseBasicParsing -Uri ($Device.TrimEnd('/') + '/commissioning/getvar.csv?id='+$id) -TimeoutSec 10).Content; Write-Host ('READ '+$label+' ('+$id+') => '+$c.Trim()) }
  catch { Write-Host ('READ '+$label+' ERR ' + $_.Exception.Message) }
}

Write-Host '=== BEGIN set_settyp_comfort ===' -ForegroundColor Cyan

# Unlock manufacturer (best-effort)
$idManuf = FindIdByPattern '"PwdManuf"'
if($idManuf){ PostById $idManuf '4189' }

# Locate SetTyp variables
$idSetTyp   = FindIdByPattern '"UnitSetP\.RoomTempSetP\.SetTyp"'
$idSetTypT  = FindIdByPattern '"UnitSetP\.RoomTempSetP\.SetTyp_THTN"'
Write-Host ('IDs SetTyp=' + $idSetTyp + ' SetTyp_THTN=' + $idSetTypT)

# Force Comfort type (3)
if($idSetTyp){ PostById $idSetTyp '3' }
if($idSetTypT){ PostById $idSetTypT '3' }

# Enable manual path if present
$idSource   = FindIdByPattern '"UnitSetP\.RoomTempSetP\.Source"'
$idManAct   = FindIdByPattern '"UnitSetP\.RoomTempSetP\.ManAct"'
if($idSource){ PostById $idSource '1' }
if($idManAct){ PostById $idManAct '1' }

# Write Comfort target
$dot   = ([double]([string]$Target.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$comma = $dot.Replace('.', ',')
PostByName 'UnitSetP.RoomTempSetP.Comfort' $dot
Start-Sleep -Milliseconds 250
PostByName 'UnitSetP.RoomTempSetP.Comfort' $comma

# Save if available
$idSave = FindIdByPattern '"Scheduler_OnOffUnit\.Scheduler_1\.SaveData"'
if($idSave){ PostById $idSave '1' }
Start-Sleep -Milliseconds 800

# Verify
ReadId 9424 'UnitSetP.RoomTempSetP.Comfort'
ReadId 5539 'CurrRoomTempSetP_Val'

Write-Host '=== END set_settyp_comfort ===' -ForegroundColor Green