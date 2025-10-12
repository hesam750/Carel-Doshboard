param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$Value = '25.0'
)

$ErrorActionPreference = 'Stop'

function Show([string]$m){ Write-Host $m }

$proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
$setUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/setvar.csv')
$getUrl = $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + '/commissioning/getvar.csv')

function TryPostId([int]$id, [string]$val){
  try { $r = Invoke-WebRequest -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri $setUrl -Body ("id=$id&value=$val") -TimeoutSec 10; Show ("POST id="+$id+" value="+$val+" Status="+$r.StatusCode+" Len="+([string]$r.Content).Length) }
  catch { $resp=$_.Exception.Response; if($resp){ Show ("POST id="+$id+" ERR Status="+$resp.StatusCode) } else { Show ("POST id="+$id+" ERR " + $_.Exception.Message) } }
}

function TryGetId([int]$id){
  $url = $getUrl + '&id=' + $id
  try { $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10; $content=[string]$r.Content; $line = ($content -split "`n" | Where-Object { $_ -match (','+$id+',') } | Select-Object -First 1); return $line }
  catch { return $null }
}

function ParseLastNumber([string]$line){
  if(-not $line){ return $null }
  $parts = $line.Split(',')
  if($parts.Length -ge 1){ $raw = $parts[$parts.Length-1].Trim(); $raw = $raw.Trim('"'); if($raw){ return $raw.Replace(',', '.') } }
  $m = [regex]::Match($line, '([0-9\-]+(?:[\.,][0-9]+)?)($|\s|,|\r|\n)')
  if($m.Success){ return $m.Groups[1].Value.Replace(',', '.') }
  return $null
}

Show 'BEGIN comfort write'

# Unlock service/user
TryPostId 8101 '0002'
TryPostId 8103 '0002'
TryPostId 8098 '4189'  # Manufacturer password (from getvar)

# Activate Comfort profile flags (if respected by application)
TryPostId 5563 '1'   # DIN_Comf.Enabled
TryPostId 5566 '0'   # DIN_Eco.Enabled
TryPostId 5575 '0'   # DIN_PreComf.Enabled

# Write Comfort setpoint (dot and comma locales)
$valDot   = ([double]([string]$Value.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$valComma = $valDot.Replace('.', ',')
TryPostId 9424 $valDot
TryPostId 9424 $valComma

# Try additional numeric formats
$valInt   = ([int]([double]$valDot)).ToString()
$valDot2  = ([double]$valDot).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
$valScaled= (([double]$valDot)*10).ToString('0', [System.Globalization.CultureInfo]::InvariantCulture)
$valScaledDot = (([double]$valDot)*10).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
TryPostId 9424 $valInt
TryPostId 9424 $valDot2
TryPostId 9424 $valScaled
TryPostId 9424 $valScaledDot

# Also test Economy setpoint change (+1.0) to observe mode effects
$ecoDot = (([double]$valDot) + 1).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$ecoComma = $ecoDot.Replace('.', ',')
TryPostId 9425 $ecoDot
TryPostId 9425 $ecoComma

Start-Sleep -Milliseconds 800

# Read back Comfort and current setpoint
$lineComfort = TryGetId 9424
Show ('Comfort line: ' + $lineComfort)
$comfortVal = ParseLastNumber $lineComfort
$cv = $comfortVal; if(-not $cv){ $cv = 'null' }
Show ('Comfort value: ' + $cv)

$lineCurr = TryGetId 5539
Show ('CurrRoomTempSetP_Val line: ' + $lineCurr)
$currVal = ParseLastNumber $lineCurr
$cv2 = $currVal; if(-not $cv2){ $cv2 = 'null' }
Show ('CurrRoomTempSetP_Val: ' + $cv2)

# Read Economy value
$lineEco = TryGetId 9425
Show ('Economy line: ' + $lineEco)
$ecoVal = ParseLastNumber $lineEco
$ev = $ecoVal; if(-not $ev){ $ev = 'null' }
Show ('Economy value: ' + $ev)

Show 'END comfort write'