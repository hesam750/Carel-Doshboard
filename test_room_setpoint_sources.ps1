param(
  [string]$Device = 'http://169.254.61.68',
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005
)

$ErrorActionPreference = 'Stop'

function MakeProxy([string]$path){
  $proxy = "http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort
  return $proxy + [System.Uri]::EscapeDataString($Device.TrimEnd('/') + $path)
}

function PostVar($id, $value){
  $url = MakeProxy('/commissioning/setvar.csv')
  $body = @{ id = $id; value = $value }
  $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -Body $body -TimeoutSec 10
  Write-Host ("POST id={0} value={1} -> Status={2}" -f $id, $value, $resp.StatusCode)
}

function ReadVar($id, $name){
  $url = MakeProxy('/commissioning/getvar.csv?id=' + $id)
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content.Trim())
}

function GetContentLines(){
  $url = MakeProxy('/commissioning/getvar.csv')
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content
  return $content -split "`n"
}

function FindId([string]$name, $lines){
  $pat = '"' + [regex]::Escape($name) + '",(\d+),' 
  $m = [regex]::Match(($lines -join "`n"), $pat)
  if($m.Success){ return [int]$m.Groups[1].Value }
  return $null
}

# 1) Load IDs
$lines = GetContentLines
$idManuf   = FindId 'PwdManuf' $lines
$idSave    = FindId 'Scheduler_OnOffUnit.Scheduler_1.SaveData' $lines
$idComfort = FindId 'UnitSetP.RoomTempSetP.Comfort' $lines
$idEconomy = FindId 'UnitSetP.RoomTempSetP.Economy' $lines
$idPreComf = FindId 'UnitSetP.RoomTempSetP.PreComfort' $lines
$idCurrSet = FindId 'CurrRoomTempSetP_Val' $lines

Write-Host ("IDs => Manuf={0} Save={1} Comfort={2} Economy={3} PreComfort={4} Curr={5}" -f $idManuf, $idSave, $idComfort, $idEconomy, $idPreComf, $idCurrSet)

# 2) Unlock manufacturer
if($idManuf){ PostVar -id $idManuf -value '4189' }

# 3) Read before
if($idComfort){ ReadVar -id $idComfort -name 'UnitSetP.RoomTempSetP.Comfort' }
if($idEconomy){ ReadVar -id $idEconomy -name 'UnitSetP.RoomTempSetP.Economy' }
if($idPreComf){ ReadVar -id $idPreComf -name 'UnitSetP.RoomTempSetP.PreComfort' }
if($idCurrSet){ ReadVar -id $idCurrSet -name 'CurrRoomTempSetP_Val' }

# 4) Write distinct test values
if($idComfort){ PostVar -id $idComfort -value '26.0' }
if($idEconomy){ PostVar -id $idEconomy -value '21.0' }
if($idPreComf){ PostVar -id $idPreComf -value '23.0' }

# 5) Save if available
if($idSave){ PostVar -id $idSave -value '1' }

Start-Sleep -Milliseconds 800

# 6) Read after
if($idComfort){ ReadVar -id $idComfort -name 'UnitSetP.RoomTempSetP.Comfort' }
if($idEconomy){ ReadVar -id $idEconomy -name 'UnitSetP.RoomTempSetP.Economy' }
if($idPreComf){ ReadVar -id $idPreComf -name 'UnitSetP.RoomTempSetP.PreComfort' }
if($idCurrSet){ ReadVar -id $idCurrSet -name 'CurrRoomTempSetP_Val' }

Write-Host 'END test_room_setpoint_sources'