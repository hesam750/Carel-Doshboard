param(
  [string]$DeviceHost = '169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$OnOffValue = '1'
)

$ErrorActionPreference = 'Stop'

$base = "http://$DeviceHost/commissioning"

function GetLines(){ Get-Content -LiteralPath (Join-Path $PSScriptRoot 'getvar.csv') -Encoding UTF8 }
function MakeUri([string]$path, [string]$qs){ $u = "$base/$path"; if($qs){ $u += ('?' + $qs) }; return $u }

function TryPostForm([string]$path, [string]$body){
  $url = MakeUri $path ''
  try { $out = (& curl.exe -s -X POST $url -H 'Content-Type: application/x-www-form-urlencoded' --data $body) | Out-String; return $out } catch { return $_.Exception.Message }
}
function TryGet([string]$path, [string]$qs){
  $url = MakeUri $path $qs
  try { $resp = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $url -TimeoutSec 10; return $resp } catch { return $_.Exception.Message }
}

function Show([string]$title, $resp){
  if($resp -is [string]){ Write-Host ("{0} -> {1}" -f $title, $resp) }
  else{ Write-Host ("{0} -> Status={1}" -f $title, $resp.StatusCode) }
}

function ReadVar([int]$id, [string]$name){
  $resp = TryGet 'getvar.csv' ('id=' + $id)
  $content = ''
  if($resp -is [string]){ $content = $resp }
  else { $content = ($resp.Content).Trim() }
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content)
}

Write-Host 'Unlock manufacturer'
Show 'POST PwdManuf=4189' (TryPostForm 'setvar.csv' ('id=8098&value=4189'))

$lines = GetLines
$idUnitOnOff = ($lines | ForEach-Object {
  if($_ -match '^\s*"UnitOnOff"\s*,\s*(\d+)\s*,'){ [int]$matches[1] }
}) | Select-Object -First 1

if($idUnitOnOff){
  Show ("POST id={0} value={1}" -f $idUnitOnOff, $OnOffValue) (TryPostForm 'setvar.csv' ("id=$idUnitOnOff&value=$OnOffValue"))
} else {
  Write-Host 'UnitOnOff id not found; trying name-based writes'
  Show 'GET var=UnitOnOff' (TryGet 'setvar.csv' ('var=' + [System.Uri]::EscapeDataString('UnitOnOff') + '&val=' + [System.Uri]::EscapeDataString($OnOffValue)))
  Show 'POST var=UnitOnOff' (TryPostForm 'setvar.csv' ('var=' + [System.Uri]::EscapeDataString('UnitOnOff') + '&val=' + [System.Uri]::EscapeDataString($OnOffValue)))
}

Show 'POST SaveData=1' (TryPostForm 'setvar.csv' 'id=8376&value=1')

ReadVar 5541 'CurrUnitStatus'
ReadVar 5539 'CurrRoomTempSetP_Val'

Write-Host 'END set_unit_onoff'