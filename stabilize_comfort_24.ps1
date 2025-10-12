param(
  [string]$DeviceHost = '169.254.61.68',
  [string]$TargetComfort = '24.0',
  [switch]$NoProxy
)

$ErrorActionPreference = 'Stop'

function MakeBaseUris([string]$devHost){
  $base = "http://$devHost/commissioning"
  if($NoProxy){
    return @{ set = "$base/setvar.csv"; get = "$base/getvar.csv" }
  } else {
    $proxy = 'http://localhost:8005/proxy?url='
    return @{ set = $proxy + [System.Uri]::EscapeDataString("$base/setvar.csv"); get = $proxy + [System.Uri]::EscapeDataString("$base/getvar.csv") }
  }
}

$uris = MakeBaseUris $DeviceHost

function PostId([int]$id, [string]$val){
  $body = 'id=' + $id + '&value=' + [System.Uri]::EscapeDataString($val)
  return Invoke-WebRequest -UseBasicParsing -Method Post -Uri $uris.set -ContentType 'application/x-www-form-urlencoded' -Body $body -TimeoutSec 12
}
function PostVar([string]$name, [string]$val){
  $body = 'var=' + [System.Uri]::EscapeDataString($name) + '&val=' + [System.Uri]::EscapeDataString($val)
  return Invoke-WebRequest -UseBasicParsing -Method Post -Uri $uris.set -ContentType 'application/x-www-form-urlencoded' -Body $body -TimeoutSec 12
}
function GetId([int]$id){
  $u = $uris.get + '?id=' + $id
  return (Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 12).Content.Trim()
}
function Show([string]$m){ Write-Host $m }

Write-Host 'BEGIN stabilize_comfort_24'

# Unlock manufacturer
PostId 8098 '4189' | Out-Null

# Disable all schedulers and daily events
$disable = @(
  'Scheduler_OnOffUnit.Scheduler_1.Today.Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.SpecDay.Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.Holiday.Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.VacationsSched[0].Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.VacationsSched[1].Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.VacationsSched[2].Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.Event_Msk[0].Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.Event_Msk[1].Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.Event_Msk[2].Enabled',
  'Scheduler_OnOffUnit.Scheduler_1.Event_Msk[3].Enabled'
)
foreach($v in $disable){ PostVar $v '0' | Out-Null }

# Stabilize manual source and Comfort mode
PostVar 'UnitSetP.RoomTempSetP.Source' '1' | Out-Null
PostVar 'UnitSetP.RoomTempSetP.ManAct' '1' | Out-Null
PostVar 'SystemStatus.Man' '3' | Out-Null
PostVar 'SystemStatus.ManAct' '1' | Out-Null
PostVar 'SetTyp' '3' | Out-Null
PostVar 'SetTyp_THTN' '3' | Out-Null

# Write Comfort setpoint
$dot   = ([double]([string]$TargetComfort.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$comma = $dot.Replace('.', ',')
PostId 9424 $dot   | Out-Null
Start-Sleep -Milliseconds 250
PostId 9424 $comma | Out-Null

# Save
PostId 8376 '1' | Out-Null
Start-Sleep -Milliseconds 600

# Read back
$c = GetId 9424
$v = GetId 5539
Show ('Comfort (9424) => ' + $c)
Show ('CurrRoomTempSetP_Val (5539) => ' + $v)

Write-Host 'END stabilize_comfort_24'