param(
  [string]$DeviceHost = '169.254.61.68',
  [string]$TargetComfort = '25.0'
)

$ErrorActionPreference = 'Stop'

$base = "http://$DeviceHost/commissioning"

function MakeUri([string]$path, [string]$qs){
  $u = "$base/$path"; if($qs){ $u += ('?' + $qs) }
  return $u
}
function PostForm([string]$path, [string]$body){
  $u = MakeUri $path ''
  try { return Invoke-WebRequest -UseBasicParsing -Method Post -Uri $u -ContentType 'application/x-www-form-urlencoded' -Body $body -TimeoutSec 10 } catch { return $_.Exception.Message }
}
function GetVar([int]$id){
  $u = MakeUri 'getvar.csv' ('id=' + $id)
  try { return (Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 10).Content.Trim() } catch { return $_.Exception.Message }
}
function Show([string]$m){ Write-Host $m }

Write-Host 'BEGIN apply_carousel_tempselect'

# Unlock manufacturer
Show ('Unlock manufacturer: ' + (PostForm 'setvar.csv' 'id=8098&value=4189').StatusCode)

# Selector candidate by name
$selName = 'MB_Devices.BigAreaCfg_THTN_1.CarouselCfg.TempSetP'

foreach($sv in @('1','3')){
  Show ('Set selector ' + $selName + ' = ' + $sv)
  $resp = PostForm 'setvar.csv' ('var=' + [System.Uri]::EscapeDataString($selName) + '&val=' + $sv)
  if($resp -is [string]){ Show ('POST selector -> ' + $resp) } else { Show ('POST selector Status=' + $resp.StatusCode) }

  # Write comfort target
  $dot   = ([double]([string]$TargetComfort.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
  $comma = $dot.Replace('.', ',')
  Show ('Write Comfort=' + $dot)
  PostForm 'setvar.csv' ('id=9424&value=' + $dot) | Out-Null
  Start-Sleep -Milliseconds 250
  PostForm 'setvar.csv' ('id=9424&value=' + $comma) | Out-Null

  # Save
  PostForm 'setvar.csv' 'id=8376&value=1' | Out-Null
  Start-Sleep -Milliseconds 600

  # Read back
  $c = GetVar 9424
  $v = GetVar 5539
  Show ('After selector ' + $sv + ' Comfort => ' + $c)
  Show ('After selector ' + $sv + ' CurrRoomTempSetP_Val => ' + $v)
}

Write-Host 'END apply_carousel_tempselect'