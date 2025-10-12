param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

function GetContentLines() {
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  $getUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/getvar.csv')
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 10).Content
  return ($content -split "`n")
}

function FindIdByPattern($lines, [string]$pattern) {
  $regex = [regex]$pattern
  foreach ($line in $lines) {
    if ($regex.IsMatch($line)) {
      $parts = $line -split ','
      if ($parts.Count -ge 2) { return [int]$parts[1] }
    }
  }
  return $null
}

function PostVar($id, $value) {
  if ($id -eq $null) { Write-Host ("SKIP: missing id for value={0}" -f $value); return }
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  $postUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/setvar.csv')
  $body = @{ id = $id; value = $value }
  $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $postUrl -Body $body -TimeoutSec 10
  Write-Host ("POST id={0} value={1} -> Status={2}" -f $id, $value, $resp.StatusCode)
}

function ReadVar($id, $name) {
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  $getUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/getvar.csv?id=' + $id)
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $getUrl -TimeoutSec 10).Content
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content.Trim())
}

$lines = GetContentLines

# Unlock manufacturer level
PostVar -id (FindIdByPattern $lines '"PwdManuf"') -value '4189'

$today = Get-Date
$day = [int]$today.Day
$month = [int]$today.Month

$base = 'Scheduler_OnOffUnit\.Scheduler_1\.SpecDaysSched\[0\]'
$idEnabled   = FindIdByPattern $lines ('\"' + $base + '\.Enabled\"')
$idStartDay  = FindIdByPattern $lines ('\"' + $base + '\.StartDay\"')
$idStartMonth= FindIdByPattern $lines ('\"' + $base + '\.StartMonth\"')
$idUnitStat  = FindIdByPattern $lines ('\"' + $base + '\.UnitStatus\"')

Write-Host ("SpecDaysSched[0] ids: Enabled={0} StartDay={1} StartMonth={2} UnitStatus={3}" -f $idEnabled, $idStartDay, $idStartMonth, $idUnitStat)

if ($idEnabled -ne $null)    { PostVar -id $idEnabled -value '1' }
if ($idStartDay -ne $null)   { PostVar -id $idStartDay -value $day }
if ($idStartMonth -ne $null) { PostVar -id $idStartMonth -value $month }
if ($idUnitStat -ne $null)   { PostVar -id $idUnitStat -value '3' } # COMFORT

# Save
$idSave = FindIdByPattern $lines '"Scheduler_OnOffUnit\.Scheduler_1\.SaveData"'
if ($idSave -ne $null) { PostVar -id $idSave -value '1' }

# Read back setpoints
ReadVar -id (FindIdByPattern $lines '"CurrRoomTempSetP_Val"') -name 'CurrRoomTempSetP_Val'
ReadVar -id (FindIdByPattern $lines '"UnitSetP\.RoomTempSetP\.Comfort"') -name 'UnitSetP.RoomTempSetP.Comfort'