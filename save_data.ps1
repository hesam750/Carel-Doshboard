param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

function PostVar($id, $value) {
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

# Unlock with manufacturer password (from getvar.csv: id=8098 value=4189)
PostVar -id 8098 -value '4189'

# Trigger SaveData on Scheduler 1 (id=8376) to commit pending writes, if applicable
PostVar -id 8376 -value '1'

# Read back Comfort and current setpoint
ReadVar -id 9424 -name 'UnitSetP.RoomTempSetP.Comfort'
ReadVar -id 5539 -name 'CurrRoomTempSetP_Val'