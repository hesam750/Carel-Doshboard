param(
  [string]$DeviceHost = '169.254.61.68',
  [string]$EconomyTarget = '25.0',
  [string]$PreComfortTarget = '25.0',
  [string]$ComfortTarget = '25.0'
)

$ErrorActionPreference = 'Stop'

$base = "http://$DeviceHost/commissioning"

function MakeUri([string]$path, [string]$qs){
  $u = "$base/$path"; if($qs){ $u += ('?' + $qs) }
  return $u
}

function TryPostForm([string]$path, $body){
  $url = MakeUri $path ''
  try {
    $pairs = @()
    foreach($kv in $body.GetEnumerator()){
      $pairs += ([System.Uri]::EscapeDataString($kv.Key) + '=' + [System.Uri]::EscapeDataString([string]$kv.Value))
    }
    $data = ($pairs -join '&')
    return (& curl.exe -s -X POST $url -H 'Content-Type: application/x-www-form-urlencoded' --data $data) | Out-String
  } catch { return $_.Exception.Message }
}

function TryGet([string]$path, [string]$qs){
  $url = MakeUri $path $qs
  try { return Invoke-WebRequest -UseBasicParsing -Method Get -Uri $url -TimeoutSec 12 } catch { return $_.Exception.Message }
}

function Show([string]$title, $resp){
  if($resp -is [string]){ Write-Host ("{0} -> {1}" -f $title, $resp) }
  else { Write-Host ("{0} -> Status={1}" -f $title, $resp.StatusCode) }
}

function GetContentLines(){
  $resp = TryGet 'getvar.csv' ''
  if($resp -is [string]){ return ($resp -split "`n") }
  return ($resp.Content -split "`n")
}

function FindId([string]$name, $lines){
  $pat = '"' + [regex]::Escape($name) + '",([0-9]+),'
  $m = [regex]::Match(($lines -join "`n"), $pat)
  if($m.Success){ return [int]$m.Groups[1].Value }
  return $null
}

function PostVar([int]$id, [string]$value){
  if($id -eq $null){ Write-Host ("SKIP POST: missing id for value={0}" -f $value); return }
  $resp = TryPostForm 'setvar.csv' @{ id = $id; value = $value }
  Show ("POST id="+$id+" value="+$value) $resp
}

function ReadVar([int]$id, [string]$name){
  if($id -eq $null){ Write-Host ("SKIP READ: {0} (missing id)" -f $name); return }
  $resp = TryGet 'getvar.csv' ('id=' + $id)
  $content = ''
  if($resp -is [string]){ $content = $resp }
  else { $content = ($resp.Content).Trim() }
  Write-Host ("READ {0} ({1}) => {2}" -f $name, $id, $content)
}

Write-Host 'BEGIN apply_economy_precomfort'

$lines = GetContentLines

# Resolve IDs by names
$idPwdManuf  = FindId 'PwdManuf' $lines
$idSave      = FindId 'Scheduler_OnOffUnit.Scheduler_1.SaveData' $lines
$idDINComf   = FindId 'DIN_Comf.Enabled' $lines
$idDINEco    = FindId 'DIN_Eco.Enabled' $lines
$idDINPre    = FindId 'DIN_PreComf.Enabled' $lines
$idManAct    = FindId 'SystemStatus.ManAct' $lines
$idMan       = FindId 'SystemStatus.Man' $lines
$idSetTyp    = FindId 'SetTyp' $lines
$idSetTypT   = FindId 'SetTyp_THTN' $lines
$idCurrSet   = FindId 'CurrRoomTempSetP_Val' $lines
$idComfort   = FindId 'UnitSetP.RoomTempSetP.Comfort' $lines
$idEconomy   = FindId 'UnitSetP.RoomTempSetP.Economy' $lines
$idPreComf   = FindId 'UnitSetP.RoomTempSetP.PreComfort' $lines

Write-Host ("IDs => PwdManuf="+$idPwdManuf+" Save="+$idSave+" DIN_Comf="+$idDINComf+" DIN_Eco="+$idDINEco+" DIN_PreComf="+$idDINPre+" ManAct="+$idManAct+" Man="+$idMan+" SetTyp="+$idSetTyp+" SetTyp_THTN="+$idSetTypT+" CurrSet="+$idCurrSet+" Comfort="+$idComfort+" Economy="+$idEconomy+" PreComfort="+$idPreComf)

# Unlock manufacturer
if($idPwdManuf){ PostVar $idPwdManuf '4189' }

# ---------- Economy path ----------
Write-Host 'Activate Economy profile and manual system status'
if($idDINEco){ PostVar $idDINEco '1' }
if($idDINComf){ PostVar $idDINComf '0' }
if($idDINPre){ PostVar $idDINPre '0' }
if($idManAct){ PostVar $idManAct '1' }
if($idMan){ PostVar $idMan '1' } # Economy manual selection
if($idSetTyp){ PostVar $idSetTyp '1' }
if($idSetTypT){ PostVar $idSetTypT '1' }

Start-Sleep -Milliseconds 400

Write-Host ('Write Economy target: ' + $EconomyTarget)
if($idEconomy){
  $dot   = ([double]([string]$EconomyTarget.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
  $comma = $dot.Replace('.', ',')
  PostVar $idEconomy $dot
  Start-Sleep -Milliseconds 250
  PostVar $idEconomy $comma
}

if($idSave){ PostVar $idSave '1' }
Start-Sleep -Milliseconds 700
ReadVar $idEconomy 'UnitSetP.RoomTempSetP.Economy'
ReadVar $idCurrSet 'CurrRoomTempSetP_Val'

# ---------- PreComfort path ----------
Write-Host 'Activate PreComfort profile and manual system status'
if($idDINEco){ PostVar $idDINEco '0' }
if($idDINComf){ PostVar $idDINComf '0' }
if($idDINPre){ PostVar $idDINPre '1' }
if($idManAct){ PostVar $idManAct '1' }
if($idMan){ PostVar $idMan '2' } # PreComfort manual selection
if($idSetTyp){ PostVar $idSetTyp '2' }
if($idSetTypT){ PostVar $idSetTypT '2' }

Start-Sleep -Milliseconds 400

Write-Host ('Write PreComfort target: ' + $PreComfortTarget)
if($idPreComf){
  $dot2   = ([double]([string]$PreComfortTarget.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
  $comma2 = $dot2.Replace('.', ',')
  PostVar $idPreComf $dot2
  Start-Sleep -Milliseconds 250
  PostVar $idPreComf $comma2
}

if($idSave){ PostVar $idSave '1' }
Start-Sleep -Milliseconds 700
ReadVar $idPreComf 'UnitSetP.RoomTempSetP.PreComfort'
ReadVar $idCurrSet 'CurrRoomTempSetP_Val'

# ---------- Restore Comfort ----------
Write-Host 'Restore Comfort profile and mode'
if($idDINEco){ PostVar $idDINEco '0' }
if($idDINPre){ PostVar $idDINPre '0' }
if($idDINComf){ PostVar $idDINComf '1' }
if($idManAct){ PostVar $idManAct '1' }
if($idMan){ PostVar $idMan '3' }
if($idSetTyp){ PostVar $idSetTyp '3' }
if($idSetTypT){ PostVar $idSetTypT '3' }
Start-Sleep -Milliseconds 400

Write-Host ('Write Comfort target: ' + $ComfortTarget)
if($idComfort){
  $dot3   = ([double]([string]$ComfortTarget.Replace(',', '.'))).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
  $comma3 = $dot3.Replace('.', ',')
  PostVar $idComfort $dot3
  Start-Sleep -Milliseconds 250
  PostVar $idComfort $comma3
}

if($idSave){ PostVar $idSave '1' }

Start-Sleep -Milliseconds 700
ReadVar $idComfort 'UnitSetP.RoomTempSetP.Comfort'
ReadVar $idCurrSet 'CurrRoomTempSetP_Val'

Write-Host 'END apply_economy_precomfort'