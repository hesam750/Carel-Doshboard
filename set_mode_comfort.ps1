param(
  [string]$DeviceHost = '169.254.61.68',
  [switch]$NoProxy,
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [int]$ModeValue = 3,
  [string]$ComfortTarget = '25.0'
)

$ErrorActionPreference = 'Stop'

$base = "http://$DeviceHost/commissioning"
function MakeUri([string]$path, [string]$qs){
  $u = "$base/$path"; if($qs){ $u += ('?' + $qs) }
  if($NoProxy){ return $u }
  $proxy = "http://${ProxyHost}:${ProxyPort}/proxy?url="
  return $proxy + [System.Uri]::EscapeDataString($u)
}
function Invoke-Get([int]$id) {
  $u = MakeUri 'getvar.csv' ('id=' + $id)
  try {
    (Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 10).Content
  } catch {
    Write-Host "GET $id failed: $($_.Exception.Message)"
    return ""
  }
}
function Invoke-Post([int]$id, [string]$val) {
  $u = MakeUri 'setvar.csv' ''
  try {
    $resp = Invoke-WebRequest -Method Post -UseBasicParsing -Uri $u -Body @{ id = $id; value = $val } -TimeoutSec 10
    Write-Host ("POST {0}={1} Status={2}" -f $id, $val, $resp.StatusCode)
  } catch {
    Write-Host "POST $id=$val failed: $($_.Exception.Message)"
  }
}

Write-Host "Unlock manufacturer access"
Invoke-Post -id 8098 -val 1

Write-Host "Set current mode (SetTyp/SetTyp_THTN) to $ModeValue"
Invoke-Post -id 8434 -val $ModeValue
Invoke-Post -id 8436 -val $ModeValue

Write-Host "Save data"
Invoke-Post -id 8376 -val 1

Write-Host "Write Comfort target"
$dot = ([double]([string]$ComfortTarget.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$comma = $dot.Replace('.', ',')
Invoke-Post -id 9424 -val $dot
Start-Sleep -Milliseconds 250
Invoke-Post -id 9424 -val $comma
Invoke-Post -id 8376 -val 1

Write-Host "\nRead-back values:"
Write-Host "CurrUnitStatus (5541):"
Invoke-Get -id 5541
Write-Host "SetTyp (8434):"
Invoke-Get -id 8434
Write-Host "SetTyp_THTN (8436):"
Invoke-Get -id 8436
Write-Host "CurrRoomTempSetP_Val (5539):"
Invoke-Get -id 5539
Write-Host "Comfort (9424):"
Invoke-Get -id 9424
Write-Host "Economy (9425):"
Invoke-Get -id 9425
Write-Host "PreComfort (9426):"
Invoke-Get -id 9426