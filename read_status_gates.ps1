param()
$ErrorActionPreference = 'Stop'

function GetDeviceBase(){
  $cfgPath = Join-Path $PSScriptRoot 'assets/data/dashboard.config.json'
  try {
    if(Test-Path $cfgPath){
      $cfg = Get-Content -Path $cfgPath -Raw | ConvertFrom-Json
      if($cfg -and $cfg.deviceUrl){
        $uri = [System.Uri]$cfg.deviceUrl
        $port = if($uri.IsDefaultPort) { '' } else { ':' + $uri.Port }
        return ($uri.Scheme + '://' + $uri.Host + $port + '/')
      }
    }
  } catch {}
  return 'http://localhost:8005/'
}

function MakeUri([string]$path, [string]$qs){
  $base = GetDeviceBase
  $u = ($base.TrimEnd('/') + '/' + $path.TrimStart('/'))
  if([string]::IsNullOrWhiteSpace($qs)){ return $u }
  return ($u + '?' + $qs)
}

function TryGet([string]$url){
  try { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10) } catch { return $null }
}

function GetVarIds(){
  $map = @{}
  $file = Join-Path $PSScriptRoot 'vars_extracted_all.csv'
  if(-not (Test-Path $file)){ return $map }
  Get-Content -Path $file | ForEach-Object {
    # Expecting lines like: "Name",ID,"Desc",Type,Access,Value
    if($_ -match '^\s*"(?<name>[^"]+)"\s*,\s*(?<id>\d+)\s*,'){ $map[$matches['name']] = [int]$matches['id'] }
  }
  return $map
}

function ReadById([int]$id, [string]$label){
  if($id -le 0){ Write-Host ("READ {0} (id=?) => NotFound" -f $label) ; return }
  $url = MakeUri 'commissioning/getvar.csv' ("id="+$id)
  $resp = TryGet $url
  if($resp -and $resp.StatusCode -eq 200){
    $val = ($resp.Content).Trim()
    Write-Host ("READ {0} ({1}) => {2}" -f $label, $id, $val)
  } else {
    Write-Host ("READ {0} ({1}) => ERR" -f $label, $id)
  }
}

Write-Host '=== BEGIN read_status_gates ===' -ForegroundColor Cyan
$ids = GetVarIds
# Fallback ID map for key variables
$fallback = @{ 
  'SystemStatus.Enabled' = 9373; 
  'SystemStatus.ManAct' = 9376; 
  'SystemStatus.Man' = 9375; 
  'KeybOnOff' = 6897; 
  'CurrUnitStatus' = 5541; 
  'CurrRoomTempSetP_Val' = 5539; 
  'UnitSetP.RoomTempSetP.Comfort' = 9424 
}
foreach($k in $fallback.Keys){ if(-not $ids.ContainsKey($k)) { $ids[$k] = $fallback[$k] } }

$names = @(
  'SystemStatus.Enabled',
  'SystemStatus.ManAct',
  'SystemStatus.Man',
  'KeybOnOff',
  'CurrUnitStatus',
  'CurrRoomTempSetP_Val',
  'UnitSetP.RoomTempSetP.Comfort'
)

# Log resolved IDs for debugging
Write-Host 'Using IDs:' -ForegroundColor Yellow
foreach($n in $names){
  $v = if($ids.ContainsKey($n)) { $ids[$n] } else { 0 }
  Write-Host ("ID {0} => {1}" -f $n, $v)
}

foreach($n in $names){
  $id = if($ids.ContainsKey($n)) { $ids[$n] } else { 0 }
  ReadById $id $n
}

Write-Host '=== END read_status_gates ===' -ForegroundColor Cyan