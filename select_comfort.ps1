param(
  [string]$Device = 'http://169.254.61.68',
  [switch]$NoProxy,
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'
function Show([string]$m){ Write-Host $m }

function MakeUri([string]$path, [string]$query = $null){
  $inner = if($query){ ($Device.TrimEnd('/') + '/' + $path + '?' + $query) } else { ($Device.TrimEnd('/') + '/' + $path) }
  if($NoProxy){ return $inner }
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return ($proxy + [System.Uri]::EscapeDataString($inner))
}

function TryGetUrl([string]$url){
  try { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content }
  catch { return $null }
}

function TryGetAll(){ return (TryGetUrl (MakeUri 'commissioning/getvar.csv')) }

function ParseCandidates([string]$csv){
  if(-not $csv){ return @() }
  $lines = $csv -split "`n"
  $pattern = 'RoomTemp.*SetP.*(Sel|Select|Mode|Profile|Active)'
  $cands = @()
  foreach($ln in $lines){ if($ln -match $pattern){ $parts = $ln.Split(','); if($parts.Length -ge 6){ $name=$parts[0].Trim('"'); $id=[int]$parts[1]; $type=$parts[3]; $acc=$parts[4]; $val=$parts[5].Trim('"'); $cands += [pscustomobject]@{ Name=$name; Id=$id; Type=$type; Acc=$acc; Val=$val; Line=$ln } } } }
  return $cands
}

function TryPostId([int]$id, [string]$val){
  $url = (MakeUri 'commissioning/setvar.csv')
  $body = ("id="+$id+"&value="+$val)
  try { $r = Invoke-WebRequest -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri $url -Body $body -TimeoutSec 10; Show ("POST id="+$id+" value="+$val+" Status="+$r.StatusCode+" Len="+([string]$r.Content).Length) }
  catch { $resp=$_.Exception.Response; if($resp){ Show ("POST id="+$id+" ERR Status="+$resp.StatusCode) } else { Show ("POST id="+$id+" ERR " + $_.Exception.Message) } }
}

function ReadLine([int]$id){
  $content = TryGetAll
  if(-not $content){ return $null }
  return ($content -split "`n" | Where-Object { $_ -match (','+$id+',') } | Select-Object -First 1)
}

function ParseLastNumber([string]$line){
  if(-not $line){ return $null }
  $parts = $line.Split(',')
  if($parts.Length -ge 1){ $raw = $parts[$parts.Length-1].Trim(); $raw = $raw.Trim('"'); if($raw){ return $raw.Replace(',', '.') } }
  return $null
}

Show 'BEGIN select comfort'

# Unlock (manufacturer / service / user, try common codes)
foreach($pair in @(@{ id=8098; val='4189' }, @{ id=8101; val='0002' }, @{ id=8103; val='0002' })){
  TryPostId $pair.id $pair.val
}

# Unlock
TryPostId 8101 '0002'
TryPostId 8103 '0002'
TryPostId 8098 '4189'

$all = TryGetAll
$cands = ParseCandidates $all
Show ('Candidates found: ' + $cands.Count)
foreach($c in $cands){ Show ($c.Line) }

# Prefer RW small integer types
$sel = ($cands | Where-Object { $_.Acc -eq 'RW' -and $_.Type -match 'S?U?S?INT|UINT|USINT' } | Select-Object -First 1)
if(-not $sel){ $sel = ($cands | Select-Object -First 1) }
if($sel){ Show ('Selected candidate: ' + $sel.Name + ' id=' + $sel.Id + ' type=' + $sel.Type + ' acc=' + $sel.Acc) } else { Show 'No selection candidate found'; Show 'END select comfort'; exit 0 }

# Try setting Comfort selection; common mapping: 1=Comfort, 2=Economy, 0=Standby, 3=PreComfort
foreach($v in @('1','3','2','0')){
  TryPostId $sel.Id $v
  Start-Sleep -Milliseconds 800
  $currLine = ReadLine 5539
  $currVal = ParseLastNumber $currLine
  $cv = $currVal; if(-not $cv){ $cv = 'null' }
  Show ('After set v='+$v+' CurrRoomTempSetP_Val: ' + $cv)
}

# Report Comfort/Economy values
$lineComfort = ReadLine 9424; Show ('Comfort line: ' + $lineComfort)
$lineEco = ReadLine 9425; Show ('Economy line: ' + $lineEco)

Show 'END select comfort'