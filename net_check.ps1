param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8000
)

$ErrorActionPreference = 'Stop'

function Show([string]$m){ Write-Host $m }
function TryGet([string]$u){ try { return Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 8 } catch { return $_.Exception.Response } }

$proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort

# Ping device
try {
  $ip = ([System.Uri]$Device).Host
  Show ("PING " + $ip)
  $ok = Test-Connection -Count 2 -Quiet $ip
  Show ("Ping=" + $ok)
} catch { Show ("Ping error " + $_.Exception.Message) }

# Build URLs
$rootUrl = $proxy + [System.Uri]::EscapeDataString($Device + '/')
$getvar  = $proxy + [System.Uri]::EscapeDataString($Device + '/commissioning/getvar.csv')

foreach($u in @($rootUrl, $getvar)){
  Show ("TEST " + $u)
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 8
    Show ("OK Status=" + $resp.StatusCode + " Len=" + ([string]$resp.Content).Length)
  } catch {
    $errResp = $_.Exception.Response
    if($errResp){
      $status = $errResp.StatusCode
      $bodySample = $null
      try {
        $sr = New-Object IO.StreamReader($errResp.GetResponseStream())
        $txt = $sr.ReadToEnd()
        if($txt){ $bodySample = $txt.Substring(0, [Math]::Min(160, $txt.Length)) }
      } catch {}
      if($bodySample){ Show ("ERR Status=" + $status + " Body: " + $bodySample) } else { Show ("ERR Status=" + $status) }
    } else {
      Show ("ERR " + $_.Exception.Message)
    }
  }
}