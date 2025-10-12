param(
  [string]$Device = 'http://169.254.61.68',
  [switch]$NoProxy,
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$TargetValue = '25.0'
)

$ErrorActionPreference = 'Stop'

function MakeUri([string]$path, [string]$qs){
  $u = ($Device.TrimEnd('/') + '/commissioning/' + $path); if($qs){ $u += ('?' + $qs) }
  if($NoProxy){ return $u }
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return $proxy + [System.Uri]::EscapeDataString($u)
}
function GetLines() {
  $getUrl = MakeUri 'getvar.csv' ''
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 10).Content
  return ($content -split "`n")
}

function FindIdByRegex($lines, [string]$pattern) {
  $regex = [regex]$pattern
  foreach ($line in $lines) {
    if ($regex.IsMatch($line)) {
      $parts = $line -split ','
      if ($parts.Count -ge 2) {
        try { return [int]$parts[1] } catch { }
      }
    }
  }
  return $null
}

function PostVar($id, $value) {
  if ($id -eq $null) { return }
  $postUrl = MakeUri 'setvar.csv' ''
  $body = @{ id = $id; value = $value }
  $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $postUrl -Body $body -TimeoutSec 10
  Write-Host ("POST id={0} value={1} -> Status={2}" -f $id, $value, $resp.StatusCode)
}

function ReadVar($id, $name) {
  if ($id -eq $null) { return }
  $getUrl = MakeUri 'getvar.csv' ('id=' + $id)
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 10).Content
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content.Trim())
}

$lines = GetLines

# Unlock manufacturer level
$idManuf = FindIdByRegex $lines '"PwdManuf"'
if ($idManuf) { PostVar -id $idManuf -value '4189' }

# Locate RoomTempSetP controls
$idManAct = FindIdByRegex $lines '"UnitSetP\.RoomTempSetP\.ManAct"'
$idMan    = FindIdByRegex $lines '"UnitSetP\.RoomTempSetP\.Man"'
$idSource = FindIdByRegex $lines '"UnitSetP\.RoomTempSetP\.Source"'
$idLock1  = FindIdByRegex $lines '"UnitSetP\.RoomTempSetP\..*Lock"'
$idLock2  = FindIdByRegex $lines '"RoomTempSetP.*Lock"'
$idWrite1 = FindIdByRegex $lines '"UnitSetP\.RoomTempSetP\..*(Write|WrEn|WriteEnable)"'
$idWrite2 = FindIdByRegex $lines '"RoomTempSetP.*(Write|WrEn|WriteEnable)"'

Write-Host ("Found IDs => ManAct={0} Man={1} Source={2} Lock1={3} Lock2={4} Write1={5} Write2={6}" -f $idManAct, $idMan, $idSource, $idLock1, $idLock2, $idWrite1, $idWrite2)

# Try unlocking write/lock
if ($idLock1) { PostVar -id $idLock1 -value '0' }
if ($idLock2) { PostVar -id $idLock2 -value '0' }
if ($idWrite1) { PostVar -id $idWrite1 -value '1' }
if ($idWrite2) { PostVar -id $idWrite2 -value '1' }

# Prefer MANUAL source if present
if ($idSource) {
  PostVar -id $idSource -value '1'
}

# Enable manual and set manual value
if ($idManAct) { PostVar -id $idManAct -value '1' }
if ($idMan) {
  PostVar -id $idMan -value $TargetValue
  # Alternate decimal separator
  $valComma = $TargetValue -replace '\.',','
  PostVar -id $idMan -value $valComma
}

# Also attempt writing Comfort directly
$idComfort = FindIdByRegex $lines '"UnitSetP\.RoomTempSetP\.Comfort"'
if ($idComfort) {
  PostVar -id $idComfort -value $TargetValue
  $valComma = $TargetValue -replace '\.',','
  PostVar -id $idComfort -value $valComma
}

# Save if scheduler save exists
$idSave = FindIdByRegex $lines '"Scheduler_OnOffUnit\.Scheduler_1\.SaveData"'
if ($idSave) { PostVar -id $idSave -value '1' }

# Read back
$idCurr = FindIdByRegex $lines '"CurrRoomTempSetP_Val"'
ReadVar -id $idCurr -name 'CurrRoomTempSetP_Val'
ReadVar -id $idComfort -name 'UnitSetP.RoomTempSetP.Comfort'