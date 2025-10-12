param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

function Show([string]$m){ Write-Host $m }

$proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
$getUrl = $proxy + [System.Uri]::EscapeDataString($Device + '/commissioning/getvar.csv')

try {
  $r = Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 8
  $content = [string]$r.Content
  $line = ($content -split "`n" | Where-Object { $_ -match '"UnitSetP\.RoomTempSetP\.Comfort"' } | Select-Object -First 1)
  Show ('Line=' + $line)
  if($line){
    $m = [regex]::Match($line, '([0-9\-]+(?:[\.,][0-9]+)?)')
    if($m.Success){ Show ('Comfort=' + $m.Groups[1].Value.Replace(',', '.')) } else { Show 'Comfort=unknown' }
  } else {
    Show 'Comfort line not found'
  }
} catch {
  $resp = $_.Exception.Response
  if($resp){ Show ('ERR Status=' + $resp.StatusCode) } else { Show ('ERR ' + $_.Exception.Message) }
}