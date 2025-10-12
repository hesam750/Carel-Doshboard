param(
  [string]$DeviceHost = '169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

function GetLines(){ Get-Content -LiteralPath (Join-Path $PSScriptRoot 'getvar.csv') -Encoding UTF8 }

function ShowHits([string]$title, [object[]]$hits){
  Write-Host ("`n=== {0} ({1}) ===" -f $title, ($hits.Count))
  $hits | Select-Object -First 200 | ForEach-Object { $_ }
}

$lines = GetLines

$patterns = @(
  '"UnitOnOff"',
  'OnOff(?!Unit)',
  'Unit(On|Off)\b',
  'Power\b',
  'Enable\b',
  'Start\b',
  'Stop\b',
  'UnitMode\b',
  'CurrUnitStatus\b'
)

foreach($p in $patterns){
  $hits = $lines | Where-Object { $_ -match $p }
  ShowHits $p $hits
}