param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$Value = '25.0'
)

$ErrorActionPreference = 'Stop'
function Show([string]$m){ Write-Host $m }

$proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
$setUrlBase = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/setvar.csv')
$getUrlBase = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/getvar.csv')

function TryGetId([int]$id){
  $url = $getUrlBase + '&id=' + $id
  try { $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10; return [string]$r.Content }
  catch { return $null }
}

function ParseLineVal([string]$content, [int]$id){
  if(-not $content){ return $null }
  $line = ($content -split "`n" | Where-Object { $_ -match (','+$id+',') } | Select-Object -First 1)
  if(-not $line){ return $null }
  $parts = $line.Split(','); if($parts.Length -lt 1){ return $null }
  $raw = $parts[$parts.Length-1].Trim(); $raw = $raw.Trim('"'); if($raw){ return $raw.Replace(',', '.') }
  return $null
}

$valDot   = ([double]([string]$Value.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$valComma = $valDot.Replace('.', ',')

Show 'BEGIN GET-Write comfort'

foreach($v in @($valDot, $valComma)){
  $url = $setUrlBase + ('&id=9424&value=' + $v)
  try { $r = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $url -TimeoutSec 10; Show ('GET id=9424 value='+$v+' Status='+$r.StatusCode+' Len='+([string]$r.Content).Length) }
  catch { $resp=$_.Exception.Response; if($resp){ Show ('GET id=9424 ERR Status='+$resp.StatusCode) } else { Show ('GET id=9424 ERR '+$_.Exception.Message) } }
}

Start-Sleep -Milliseconds 800

$comfortCsv = TryGetId 9424
$comfortVal = ParseLineVal $comfortCsv 9424
$c1 = $comfortVal; if(-not $c1){ $c1 = 'null' }
Show ('Comfort read: ' + $c1)

$currCsv = TryGetId 5539
$currVal = ParseLineVal $currCsv 5539
$c2 = $currVal; if(-not $c2){ $c2 = 'null' }
Show ('CurrRoomTempSetP_Val: ' + $c2)

Show 'END GET-Write comfort'