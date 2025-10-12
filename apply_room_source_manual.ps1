param(
  [string]$DeviceHost = '169.254.61.68',
  [switch]$NoProxy,
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$TargetValue = '25.0'
)

$ErrorActionPreference = 'Stop'

$base = "http://$DeviceHost/commissioning"

function MakeUri([string]$path, [string]$qs){
  $u = "$base/$path"; if($qs){ $u += ('?' + $qs) }
  if($NoProxy){ return $u }
  $proxy = "http://${ProxyHost}:${ProxyPort}/proxy?url="
  return $proxy + [System.Uri]::EscapeDataString($u)
}
function TryPostForm([string]$path, [string]$body){
  $url = MakeUri $path ''
  try { return Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -ContentType 'application/x-www-form-urlencoded' -Body $body -TimeoutSec 10 } catch { return $_.Exception.Message }
}
function TryGet([string]$path, [string]$qs){
  $url = MakeUri $path $qs
  try { return Invoke-WebRequest -UseBasicParsing -Method Get -Uri $url -TimeoutSec 10 } catch { return $_.Exception.Message }
}
function Show([string]$title, $resp){ if($resp -is [string]){ Write-Host ("{0} -> {1}" -f $title, $resp) } else { Write-Host ("{0} -> Status={1}" -f $title, $resp.StatusCode) } }

function ReadVar([int]$id, [string]$name){
  $resp = TryGet 'getvar.csv' ('id=' + $id)
  $content = ''
  if($resp -is [string]){ $content = $resp } else { $content = ($resp.Content).Trim() }
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content)
}

function LoadAll(){
  $resp = TryGet 'getvar.csv' ''
  if($resp -is [string]){ return $resp }
  if($resp -and $resp.Content){ return ($resp.Content).ToString() }
  return ''
}
function ReadByName([string]$name){
  $all = LoadAll
  if(-not $all){ return }
  $lines = $all -split "`n"
  foreach($l in $lines){ if($l -match ('"' + [regex]::Escape($name) + '"')){ Write-Host $l } }
}

function WriteByName([string]$name, [string]$value){
  $n = [System.Uri]::EscapeDataString($name)
  $v = [System.Uri]::EscapeDataString($value)
  Show ('GET var=' + $name + ' val=' + $value) (TryGet 'setvar.csv' ('var=' + $n + '&val=' + $v))
  Show ('POST var=' + $name + ' val=' + $value) (TryPostForm 'setvar.csv' ('var=' + $n + '&val=' + $v))
}

Write-Host 'BEGIN apply_room_source_manual'

# Unlock manufacturer
Show 'POST PwdManuf=4189' (TryPostForm 'setvar.csv' 'id=8098&value=4189')

# Ensure unit on (redundant safety)
WriteByName 'UnitOnOff' '1'

# Try setting UnitMode by name (string value)
WriteByName 'UnitMode' 'comfort'

# Apply RoomTempSetP source to MANUAL and enable manual action
WriteByName 'UnitSetP.RoomTempSetP.Source' '1'
WriteByName 'RoomTempSetP.Source' '1'
WriteByName 'UnitSetP.RoomTempSetP.ManAct' '1'
WriteByName 'RoomTempSetP.ManAct' '1'

# Value formats (dot and comma)
$valDot = ([double]([string]$TargetValue.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$valComma = $valDot.Replace('.', ',')
WriteByName 'UnitSetP.RoomTempSetP.Man' $valDot
WriteByName 'UnitSetP.RoomTempSetP.Man' $valComma
WriteByName 'RoomTempSetP.Man' $valDot
WriteByName 'RoomTempSetP.Man' $valComma

# Also attempt writing Comfort directly
WriteByName 'UnitSetP.RoomTempSetP.Comfort' $valDot
WriteByName 'UnitSetP.RoomTempSetP.Comfort' $valComma

# Save data
Show 'POST SaveData=1' (TryPostForm 'setvar.csv' 'id=8376&value=1')

Start-Sleep -Milliseconds 800

# Read back
ReadVar 5539 'CurrRoomTempSetP_Val'
ReadVar 9424 'UnitSetP.RoomTempSetP.Comfort'
ReadByName 'UnitSetP.RoomTempSetP.Source'
ReadByName 'UnitSetP.RoomTempSetP.ManAct'
ReadByName 'UnitSetP.RoomTempSetP.Man'

Write-Host 'END apply_room_source_manual'