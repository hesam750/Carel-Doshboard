param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

function MakeProxyUri([string]$path){
  $base = $Device.TrimEnd('/') + '/commissioning/' + $path
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return $proxy + [System.Uri]::EscapeDataString($base)
}

function GetLines(){
  $u = MakeProxyUri 'getvar.csv'
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 12).Content
  return ($content -split "`n")
}

function ExtractEntry($lines, [string]$name){
  $pattern = '^"' + [regex]::Escape($name) + '",' 
  $line = $lines | Where-Object { $_ -match $pattern } | Select-Object -First 1
  if(-not $line){ return $null }
  $parts = $line.Split(',')
  if($parts.Count -lt 6){ return $null }
  return [pscustomobject]@{
    Name = $parts[0].Trim('"')
    Id   = [int]$parts[1]
    Type = $parts[3]
    Acc  = $parts[4]
    Val  = $parts[5].Trim('"')
    Line = $line
  }
}

Write-Host '=== BEGIN extract_ids_proxy ===' -ForegroundColor Cyan
$lines = GetLines

$targets = @(
  'UnitOnOff',
  'CurrUnitStatus',
  'CurrRoomTempSetP_Val',
  'UnitSetP.RoomTempSetP.Comfort',
  'UnitSetP.RoomTempSetP.SetTyp',
  'UnitSetP.RoomTempSetP.SetTyp_THTN',
  'UnitSetP.RoomTempSetP.Source',
  'UnitSetP.RoomTempSetP.ManAct',
  'PwdManuf',
  'Scheduler_OnOffUnit.Scheduler_1.SaveData'
)

foreach($t in $targets){
  $e = ExtractEntry $lines $t
  if($e){
    Write-Host ("{0}: id={1} type={2} acc={3} val={4}" -f $e.Name, $e.Id, $e.Type, $e.Acc, $e.Val)
  } else {
    Write-Host ($t + ': NOT_FOUND')
  }
}

Write-Host '=== END extract_ids_proxy ===' -ForegroundColor Cyan