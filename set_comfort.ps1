param(
  [string]$Value = '25.0',
  [switch]$NoProxy,
  [int]$ProxyPort = 8001,
  [string]$ProxyHost = 'localhost'
)

$ErrorActionPreference = 'Stop'

# Device/proxy settings
$device = 'http://169.254.61.68'
$proxy  = ("http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort)
function MakeUri([string]$path, [string]$query = $null) {
  $inner = if ($query) { "$device/$path?$query" } else { "$device/$path" }
  if ($NoProxy) { return $inner }
  return ($proxy + [System.Uri]::EscapeDataString($inner))
}

function Show([string]$label, $resp) {
  try {
    if($null -ne $resp){ Write-Host ("${label}: Status=" + $resp.StatusCode + " Length=" + ([string]$resp.Content).Length) }
    else { Write-Host ("${label}: no response") }
  } catch { Write-Host ("${label}: error") }
}
function TryGet([string]$url){ try { return Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8 } catch { return $_.Exception.Response } }
function TryPostForm([string]$url, [string]$body){ try { return Invoke-WebRequest -Uri $url -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Body $body -TimeoutSec 8 } catch { return $_.Exception.Response } }

$ids = @{ 'PwdService' = 8101; 'PwdUser' = 8103; 'DIN_Comf.Enabled' = 5563; 'DIN_Eco.Enabled' = 5566; 'DIN_PreComf.Enabled' = 5575; 'UnitSetP.RoomTempSetP.Comfort' = 9424; 'CurrRoomTempSetP_Val' = 5539 }

function ParseNum($content){
  if(-not $content) { return $null }
  $m = [regex]::Match($content, '([0-9\-]+(?:[\.,][0-9]+)?)($|\s|,|\r|\n)')
  if($m.Success){ return $m.Groups[1].Value.Replace(',', '.') }
  return $null
}
function ReadById([int]$id){
  $r = TryGet((MakeUri 'commissioning/getvar.csv' ("id=$id")))
  Show ("READ id=" + $id) $r
  if($r -and $r.Content){ $v = ParseNum $r.Content; if($v){ return $v } }
  $r2 = TryGet((MakeUri 'commissioning/getvar.csv'))
  Show 'READ all getvar.csv' $r2
  if($r2 -and $r2.Content){
    $script:allVars = $r2.Content
    $pat = '"[^"]+",' + $id + ',.*?,(?:REAL|D?INT|US?INT),\w+,([0-9\-]+(?:[\.,][0-9]+)?)'
    $m2 = [regex]::Match($r2.Content, $pat)
    if($m2.Success){ return $m2.Groups[1].Value.Replace(',', '.') }
  }
  return $null
}

function LoadAllVars(){
  if(-not $script:allVars){
    $r2 = TryGet((MakeUri 'commissioning/getvar.csv'))
    Show 'LOAD all getvar.csv' $r2
    if($r2 -and $r2.Content){ $script:allVars = $r2.Content }
  }
  return $script:allVars
}
function FindIdByName([string]$name){
  $content = LoadAllVars
  if(-not $content){ return $null }
  $pat = '"' + [regex]::Escape($name) + '",(\d+),'
  $m = [regex]::Match($content, $pat)
  if($m.Success){ return [int]$m.Groups[1].Value }
  return $null
}
function ReadByName([string]$name){
  $content = LoadAllVars
  if(-not $content){ return $null }
  $pat = '"' + [regex]::Escape($name) + '",(\d+),[^\r\n]*?,(?:REAL|D?INT|US?INT),\w+,([0-9\-]+(?:[\.,][0-9]+)?)'
  $m = [regex]::Match($content, $pat)
  if($m.Success){ return @{ id = [int]$m.Groups[1].Value; value = $m.Groups[2].Value.Replace(',', '.') } }
  return $null
}
function DumpMatches([string]$substr){
  $content = LoadAllVars
  if(-not $content){ return }
  $lines = $content -split "`n"
  $cnt = 0
  Write-Host ("-- Candidates containing '" + $substr + "' --")
  foreach($l in $lines){
    if($l -match [regex]::Escape($substr)){
      Write-Host $l
      $cnt++
      if($cnt -ge 12){ break }
    }
  }
  if($cnt -eq 0){ Write-Host '(no matches)' }
}

function TrySetVar([string]$name, [int]$id, [string]$value){
  $attempts = @(
    @{ kind='GET';  qs=("name="+[System.Uri]::EscapeDataString($name)+"&value="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='GET';  qs=("name="+[System.Uri]::EscapeDataString($name)+"&val="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='GET';  qs=("id="+$id+"&value="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='GET';  qs=("id="+$id+"&val="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='GET';  qs=("var="+[System.Uri]::EscapeDataString($name)+"&val="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='POST'; body=("name="+[System.Uri]::EscapeDataString($name)+"&value="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='POST'; body=("name="+[System.Uri]::EscapeDataString($name)+"&val="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='POST'; body=("id="+$id+"&value="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='POST'; body=("id="+$id+"&val="+[System.Uri]::EscapeDataString($value)) },
    @{ kind='POST'; body=("var="+[System.Uri]::EscapeDataString($name)+"&val="+[System.Uri]::EscapeDataString($value)) }
  )
  foreach($a in $attempts){
    if($a.kind -eq 'GET'){
      $url = MakeUri 'commissioning/setvar.csv' $a.qs
      $resp = TryGet $url
    } else {
      $url = MakeUri 'commissioning/setvar.csv'
      $resp = TryPostForm $url $a.body
    }
    Show ("WRITE " + $name + "=" + $value + " (" + $a.kind + ")") $resp
    Start-Sleep -Milliseconds 450
  }
}

function Unlock(){
  $codes = @('0002','1489','1234')
  $vars  = @('PwdService','PwdUser')
  foreach($v in $vars){
    $id = $ids[$v]
    foreach($c in $codes){ TrySetVar $v $id $c; Start-Sleep -Milliseconds 500 }
  }
}
function Relock(){
  foreach($v in @('PwdService','PwdUser')){ TrySetVar $v $ids[$v] '0'; Start-Sleep -Milliseconds 400 }
}

function ActivateComfortProfile(){
  TrySetVar 'DIN_Comf.Enabled' $ids['DIN_Comf.Enabled'] '1'
  TrySetVar 'DIN_Eco.Enabled'  $ids['DIN_Eco.Enabled']  '0'
  TrySetVar 'DIN_PreComf.Enabled' $ids['DIN_PreComf.Enabled'] '0'
}

Write-Host 'BEGIN: Set Comfort'

Unlock
Start-Sleep -Milliseconds 600
ActivateComfortProfile
Start-Sleep -Milliseconds 600

# Load and resolve Comfort variable id dynamically if needed
$null = LoadAllVars
$resolvedId = FindIdByName 'UnitSetP.RoomTempSetP.Comfort'
if(-not $resolvedId){
  foreach($alt in @('RoomTempSetP.Comfort','RoomTempSetP_Confort','ComfortSetP','SetP.Comfort','RoomTempSetP','Comfort')){
    $resolvedId = FindIdByName $alt
    if($resolvedId){ break }
  }
}
if($resolvedId){
  $ids['UnitSetP.RoomTempSetP.Comfort'] = $resolvedId
  Write-Host ("Resolved Comfort id=" + $resolvedId)
} else {
  Write-Host 'Comfort id not found by exact name, showing candidates:'
  DumpMatches 'Comfort'
  DumpMatches 'SetP'
}

# Prepare desired formats
$desiredDot   = ([double]([string]$Value.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
$desiredComma = $desiredDot.Replace('.', ',')

# Write Comfort with multiple fallbacks (GET+POST, name/id/var, value/val)
TrySetVar 'UnitSetP.RoomTempSetP.Comfort' $ids['UnitSetP.RoomTempSetP.Comfort'] $desiredDot
TrySetVar 'UnitSetP.RoomTempSetP.Comfort' $ids['UnitSetP.RoomTempSetP.Comfort'] $desiredComma

# Read back Comfort and current setpoint
$comfort = ReadById $ids['UnitSetP.RoomTempSetP.Comfort']
if(-not $comfort){
  $rb = ReadByName 'UnitSetP.RoomTempSetP.Comfort'
  if($rb){ $comfort = $rb.value; Write-Host ("Comfort readback(name,id=" + $rb.id + ")=" + $comfort) }
}
if($comfort){ Write-Host ("Comfort readback=" + $comfort) } else { Write-Host 'Comfort readback=null' }

$curr = ReadById $ids['CurrRoomTempSetP_Val']
if(-not $curr){
  $rbc = ReadByName 'CurrRoomTempSetP_Val'
  if($rbc){ $curr = $rbc.value; Write-Host ("CurrRoomTempSetP_Val(name,id=" + $rbc.id + ")=" + $curr) }
}
if($curr){ Write-Host ("CurrRoomTempSetP_Val=" + $curr) } else { Write-Host 'CurrRoomTempSetP_Val=null' }

Relock
Write-Host 'END'