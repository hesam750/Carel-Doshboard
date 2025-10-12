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

# Unlock manufacturer
PostVar -id 8098 -value '4189'

# Enable manual system status and set to COMFORT
PostVar -id 9376 -value '1'  # SystemStatus.ManAct = 1 (active)
PostVar -id 9375 -value '3'  # SystemStatus.Man = 3 (COMFORT)

# Save if applicable
PostVar -id 8376 -value '1'  # Scheduler_1.SaveData

# Read back
ReadVar -id 5539 -name 'CurrRoomTempSetP_Val'
ReadVar -id 9424 -name 'UnitSetP.RoomTempSetP.Comfort'
ReadVar -id 9375 -name 'SystemStatus.Man'
ReadVar -id 9376 -name 'SystemStatus.ManAct'