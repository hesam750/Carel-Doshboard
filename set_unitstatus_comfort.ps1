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

# Unlock
PostVar -id 8098 -value '4189'

# Try to force COMFORT via Scheduler daily events unit status (IDs from search)
PostVar -id 8369 -value '3'  # Event_Msk[2].UnitStatus -> COMFORT
PostVar -id 8371 -value '3'  # Event_Msk[3].UnitStatus -> COMFORT

# Save
PostVar -id 8376 -value '1'  # Scheduler_1.SaveData

# Read current setpoint
ReadVar -id 5539 -name 'CurrRoomTempSetP_Val'
ReadVar -id 9424 -name 'UnitSetP.RoomTempSetP.Comfort'