param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$OnOff = '1',
  [double]$Temp = 25.0
)

$ErrorActionPreference = 'Stop'

function MakeProxyUri([string]$path){
  $inner = $Device.TrimEnd('/') + '/commissioning/' + $path
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return $proxy + [System.Uri]::EscapeDataString($inner)
}

function PostId([int]$id, [string]$val){
  $url = MakeProxyUri 'setvar.csv'
  try {
    Invoke-WebRequest -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri $url -Body ("id="+$id+"&value="+$val) -TimeoutSec 10 | Out-Null
    Write-Host ("POST id="+$id+" value="+$val)
  } catch {
    Write-Host ("POST id="+$id+" ERR " + $_.Exception.Message)
  }
}

function ReadId([int]$id, [string]$name){
  $url = MakeProxyUri ('getvar.csv?id=' + $id)
  try {
    $c = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content
    Write-Host ("READ " + $name + " (" + $id + ") => " + ($c.Trim()))
  } catch {
    Write-Host ("READ " + $name + " ERR " + $_.Exception.Message)
  }
}

Write-Host '=== BEGIN apply_via_proxy ===' -ForegroundColor Cyan

# Unlock manufacturer
PostId 8098 '4189'
Start-Sleep -Milliseconds 200

# Set Comfort temperature
$dot = $Temp.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$comma = $dot.Replace('.', ',')
PostId 9424 $dot
Start-Sleep -Milliseconds 200
PostId 9424 $comma
Start-Sleep -Milliseconds 200
PostId 8376 '1'   # SaveData
Start-Sleep -Milliseconds 400
ReadId 9424 'UnitSetP.RoomTempSetP.Comfort'
ReadId 5539 'CurrRoomTempSetP_Val'

# Turn ON via KeybOnOff
PostId 6897 $OnOff
Start-Sleep -Milliseconds 200
PostId 8376 '1'
Start-Sleep -Milliseconds 400
ReadId 5541 'CurrUnitStatus'

# If still OFF, try forcing scheduler masks to COMFORT
$try = (Invoke-WebRequest -UseBasicParsing -Uri (MakeProxyUri 'getvar.csv?id=5541') -TimeoutSec 10).Content
if($try.Trim() -eq '0'){
  Write-Host 'CurrUnitStatus still OFF; trying scheduler masks COMFORT'
  PostId 8369 '3'
  PostId 8371 '3'
  Start-Sleep -Milliseconds 200
  PostId 8376 '1'
  Start-Sleep -Milliseconds 400
  ReadId 5541 'CurrUnitStatus'
}

Write-Host '=== END apply_via_proxy ===' -ForegroundColor Cyan