param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$ComfortValue = '25.0'
)

$ErrorActionPreference = 'Stop'

function MakeProxy([string]$path){
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + $path)
}
function PostVar($id, $value){
  $url = MakeProxy('/commissioning/setvar.csv')
  $body = @{ id = $id; value = $value }
  $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -Body $body -TimeoutSec 10
  Write-Host ("POST id={0} value={1} -> Status={2}" -f $id, $value, $resp.StatusCode)
}
function ReadVar($id, $name){
  $url = MakeProxy('/commissioning/getvar.csv?id=' + $id)
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content.Trim())
}

# Known IDs from searches
$idManuf = 8098
$idKeybOnOff = 6897
$idSave = 8376
$idComfort = 9424
$idCurr = 5539

# Unlock manufacturer
PostVar -id $idManuf -value '4189'

# Enable keyboard/panel if applicable
PostVar -id $idKeybOnOff -value '1'
PostVar -id $idSave -value '1'
Start-Sleep -Milliseconds 600

# Write comfort setpoint and save
PostVar -id $idComfort -value $ComfortValue
PostVar -id $idSave -value '1'
Start-Sleep -Milliseconds 600

# Read back
ReadVar -id $idComfort -name 'UnitSetP.RoomTempSetP.Comfort'
ReadVar -id $idCurr -name 'CurrRoomTempSetP_Val'

Write-Host 'END apply_keyb_onoff_and_write'