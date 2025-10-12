param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

$proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
$getUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/getvar.csv')

$content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 10).Content
$lines = $content -split "`n"

# Deep search for selectors/sources/profiles related to SetP/RoomTempSetP
$pattern = '((SetP|RoomTempSetP).*(Sel|Select|Profile|Source|Active|Use))|((Sel|Select|Profile|Source|Active|Use).*(SetP|RoomTempSetP))|Profile|ActiveProfile|ProfileSelect|SetpointUse|CurrRoomTempSetP|RoomTempSetP'
$hits = $lines | Where-Object { $_ -match $pattern } | Select-Object -First 500

$hits | ForEach-Object { Write-Host $_ }