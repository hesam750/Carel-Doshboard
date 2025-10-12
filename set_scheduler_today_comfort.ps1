param(
  [string]$Device = 'http://169.254.61.68',
  [switch]$NoProxy,
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

function MakeUri([string]$path, [string]$qs){
  $u = $Device.TrimEnd('/') + $path
  if($qs){ $u += ('?' + $qs) }
  if($NoProxy){ return $u }
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return $proxy + [System.Uri]::EscapeDataString($u)
}
function GetContentLines() {
  $getUrl = MakeUri '/commissioning/getvar.csv' ''
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 10).Content
  return ($content -split "`n")
}

function FindIdByPattern($lines, [string]$pattern) {
  $regex = [regex]$pattern
  foreach ($line in $lines) {
    if ($regex.IsMatch($line)) {
      # naive CSV split: id is second field
      $parts = $line -split ','
      if ($parts.Count -ge 2) { return [int]$parts[1] }
    }
  }
  return $null
}

function PostVar($id, $value) {
  if ($id -eq $null) { Write-Host ("SKIP: missing id for value={0}" -f $value); return }
  $postUrl = MakeUri '/commissioning/setvar.csv' ''
  $body = @{ id = $id; value = $value }
  $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $postUrl -Body $body -TimeoutSec 10
  Write-Host ("POST id={0} value={1} -> Status={2}" -f $id, $value, $resp.StatusCode)
}

function ReadVar($id, $name) {
  $getUrl = MakeUri '/commissioning/getvar.csv' ('id=' + $id)
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 10).Content
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content.Trim())
}

$lines = GetContentLines

# Unlock manufacturer level
PostVar -id (FindIdByPattern $lines '"PwdManuf"') -value '4189'

$now = Get-Date
$hour = [int]$now.Hour
$minute = [int]$now.Minute

for ($i=0; $i -le 3; $i++) {
  $base = "Scheduler_OnOffUnit\.Scheduler_1\.Event_Msk\[$i\]"
  $patEnabled  = '\"' + $base + '\.Enabled\"'
  $patHour     = '\"' + $base + '\.Hour\"'
  $patMinute   = '\"' + $base + '\.Minute\"'
  $patUnitStat = '\"' + $base + '\.UnitStatus\"'
  $idEnabled   = FindIdByPattern $lines $patEnabled
  $idHour      = FindIdByPattern $lines $patHour
  $idMinute    = FindIdByPattern $lines $patMinute
  $idUnitStat  = FindIdByPattern $lines $patUnitStat

  Write-Host ("Event_Msk[{0}] ids: Enabled={1} Hour={2} Minute={3} UnitStatus={4}" -f $i, $idEnabled, $idHour, $idMinute, $idUnitStat)

  if ($idEnabled -ne $null) { PostVar -id $idEnabled -value '1' }
  if ($idHour -ne $null)    { PostVar -id $idHour -value $hour }
  if ($idMinute -ne $null)  { PostVar -id $idMinute -value $minute }
  if ($idUnitStat -ne $null){ PostVar -id $idUnitStat -value '3' } # COMFORT
}

# Save scheduler data if available
$idSave = FindIdByPattern $lines '"Scheduler_OnOffUnit\.Scheduler_1\.SaveData"'
if ($idSave -ne $null) { PostVar -id $idSave -value '1' }

# Read back setpoints
ReadVar -id (FindIdByPattern $lines '"CurrRoomTempSetP_Val"') -name 'CurrRoomTempSetP_Val'
ReadVar -id (FindIdByPattern $lines '"UnitSetP\.RoomTempSetP\.Comfort"') -name 'UnitSetP.RoomTempSetP.Comfort'