param(
  [string]$Device = 'http://169.254.61.68',
  [switch]$NoProxy,
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string]$TargetComfort = '25.0'
)

$ErrorActionPreference = 'Stop'

function MakeUri([string]$path, [string]$qs){
  $u = $Device.TrimEnd('/') + $path
  if($qs){ $u += ('?' + $qs) }
  if($NoProxy){ return $u }
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return $proxy + [System.Uri]::EscapeDataString($u)
}
function PostVar($id, $value){
  $url = MakeUri('/commissioning/setvar.csv','')
  $body = @{ id = $id; value = $value }
  $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -Body $body -TimeoutSec 10
  Write-Host ("POST id={0} value={1} -> Status={2}" -f $id, $value, $resp.StatusCode)
}
function ReadVar($id, $name){
  $url = MakeUri('/commissioning/getvar.csv', 'id=' + $id)
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content.Trim())
}
function GetLines(){
  $url = MakeUri('/commissioning/getvar.csv','')
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content
  return $content -split "`n"
}
function ExtractEntries($lines){
  return $lines | ForEach-Object {
    $m = [regex]::Match($_, '^"(?<name>[^"]+)",(?<id>\d+),"(?<desc>[^"]*)",(?<type>[^,]+),(?<acc>[^,]+),(?<val>.*)$')
    if($m.Success){ [PSCustomObject]@{ name=$m.Groups['name'].Value; id=[int]$m.Groups['id'].Value; desc=$m.Groups['desc'].Value; type=$m.Groups['type'].Value; acc=$m.Groups['acc'].Value; val=$m.Groups['val'].Value } }
  } | Where-Object { $_ }
}

$lines = GetLines
$entries = ExtractEntries $lines

# Known IDs
$idManuf   = ($entries | Where-Object { $_.name -eq 'PwdManuf' }).id
$idSave    = ($entries | Where-Object { $_.name -eq 'Scheduler_OnOffUnit.Scheduler_1.SaveData' }).id
$idComfort = ($entries | Where-Object { $_.name -eq 'UnitSetP.RoomTempSetP.Comfort' }).id
$idCurr    = ($entries | Where-Object { $_.name -eq 'CurrRoomTempSetP_Val' }).id

Write-Host ("IDs => Manuf={0} Save={1} Comfort={2} Curr={3}" -f $idManuf, $idSave, $idComfort, $idCurr)
if($idManuf){ PostVar -id $idManuf -value '4189' }

# Candidate selectors: any var containing SetP/RoomTempSetP together with Sel/Select/Profile/Source/Active/Use
$selRegex = '(SetP|RoomTempSetP).*(Sel|Select|Profile|Source|Active|Use)|(Sel|Select|Profile|Source|Active|Use).*(SetP|RoomTempSetP)'
$candidates = $entries | Where-Object { $_.name -match $selRegex }
Write-Host ("Found selector candidates: " + ($candidates | Select-Object -ExpandProperty name | Out-String))

# Try selector values and write comfort
foreach($c in $candidates){
  Write-Host ("-- Trying selector: " + $c.name + " (id=" + $c.id + ")")
  foreach($v in @('0','1','2','3')){
    PostVar -id $c.id -value $v
    if($idSave){ PostVar -id $idSave -value '1' }
    Start-Sleep -Milliseconds 600
    if($idComfort){ PostVar -id $idComfort -value $TargetComfort }
    if($idSave){ PostVar -id $idSave -value '1' }
    Start-Sleep -Milliseconds 600
    if($idComfort){ ReadVar -id $idComfort -name 'UnitSetP.RoomTempSetP.Comfort' }
    if($idCurr){ ReadVar -id $idCurr -name 'CurrRoomTempSetP_Val' }
  }
}

Write-Host 'END try_selectors_apply_comfort'