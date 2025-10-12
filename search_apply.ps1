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

$pattern = 'Apply|Save|Commit|Confirm|EnableWrite|Unlock|LockSetP|WriteEnable|Write En|Write-En'
$hits = $lines | Where-Object { $_ -match $pattern } | Select-Object -First 200

$hits | ForEach-Object { Write-Host $_ }