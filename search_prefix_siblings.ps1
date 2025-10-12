param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string[]]$Prefixes = @('UnitSetP.RoomTempSetP','RoomTempSetP')
)

$ErrorActionPreference = 'Stop'

function GetLines(){
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  $getUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/getvar.csv')
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 15).Content
  return ($content -split "`n")
}

function ParseEntry([string]$line){
  # Lightweight parse: only extract name and id
  $parts = $line -split ','
  if($parts.Count -lt 2){ return $null }
  $name = $parts[0].Trim('"')
  $id   = $parts[1]
  return [PSCustomObject]@{ name=$name; id=$id }
}

Write-Host 'BEGIN search_prefix_siblings'

$lines = GetLines
$entries = $lines | ForEach-Object { ParseEntry $_ } | Where-Object { $_ -ne $null }

foreach($prefix in $Prefixes){
  $hits = $entries | Where-Object { $_.name -like ($prefix + '.*') -or $_.name -eq $prefix }
  Write-Host ("-- Prefix: {0} (count={1})" -f $prefix, ($hits | Measure-Object).Count)
  $hits | Sort-Object { [int]($_.id) } | ForEach-Object {
    Write-Host ('"' + $_.name + '"' + ',' + $_.id)
  }
}

Write-Host 'END search_prefix_siblings'