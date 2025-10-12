param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

$proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
$getUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/getvar.csv')
$content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 15).Content
$lines = $content -split "`n"

Write-Host 'BEGIN search_temp_setp_selectors'

# Look for any TempSetP-related selector, profile, source, use
$patterns = @(
  'TempSetP.*Select',
  'TempSetP.*Profile',
  'TempSetP.*Active',
  'TempSetP.*Source',
  'TempSetP.*Use'
)

$matches = @()
foreach($p in $patterns){
  $m = $lines | Select-String -Pattern $p
  if($m){ $matches += $m }
}

if($matches.Count -eq 0){
  Write-Host 'No TempSetP selector/profile/source/use entries found.'
} else {
  $matches | ForEach-Object { $_.Line } | Sort-Object | ForEach-Object { Write-Host $_ }
}

Write-Host 'END search_temp_setp_selectors'