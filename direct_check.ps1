param(
  [string]$Device = 'http://169.254.61.68'
)

$ErrorActionPreference = 'Stop'

function Show([string]$m){ Write-Host $m }
function TryGet([string]$u){ try { return Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 8 } catch { return $_.Exception.Response } }

try {
  $ip = ([System.Uri]$Device).Host
  Show ("PING " + $ip)
  $ok = Test-Connection -Count 2 -Quiet $ip
  Show ("Ping=" + $ok)
} catch { Show ("Ping error " + $_.Exception.Message) }

foreach($path in @('/', '/commissioning/getvar.csv')){
  $u = $Device.TrimEnd('/') + $path
  Show ("TEST " + $u)
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 8
    Show ("OK Status=" + $r.StatusCode + " Len=" + ([string]$r.Content).Length)
  } catch {
    $resp = $_.Exception.Response
    if($resp){
      Show ("ERR Status=" + $resp.StatusCode)
      try {
        $sr = New-Object IO.StreamReader($resp.GetResponseStream())
        $txt = $sr.ReadToEnd()
        if($txt){ Show ("Body sample: " + $txt.Substring(0, [Math]::Min(160, $txt.Length))) }
      } catch {}
    } else {
      Show ("ERR " + $_.Exception.Message)
    }
  }
}