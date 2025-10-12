param(
  [string]$Value = '25.0',
  [string]$Var = 'UnitSetP.RoomTempSetP.Comfort'
)

function Show([string]$m){ $msg = "==== $m ===="; Write-Host $msg; $msg | Out-File -FilePath "$PSScriptRoot\test_setpoint.log" -Append -Encoding UTF8 }
function Log([string]$m){ Write-Host $m; $m | Out-File -FilePath "$PSScriptRoot\test_setpoint.log" -Append -Encoding UTF8 }

# Proxy/device URL builders to correctly embed inner query into url= parameter
$proxy  = 'http://127.0.0.1:8005/proxy?url='
$device = 'http://169.254.61.68'
function MakeUri([string]$path, [string]$query = $null) {
  $inner = if ($query) { "$device/$path?$query" } else { "$device/$path" }
  return ($proxy + [System.Uri]::EscapeDataString($inner))
}

# Known IDs for target variables and unlock vars
$varIds = @{ 'UnitSetP.RoomTempSetP.Comfort' = 9424; 'UnitSetP.RoomTempSetP.Economy' = 9425; 'UnitSetP.RoomTempSetP.PreComfort' = 9426 }
$unlockIds = @{ 'PwdService' = 8101; 'PwdUser' = 8103; 'PwdManuf' = 8098 }

$read = MakeUri('commissioning/getvar.csv')
$setUrl = MakeUri('commissioning/setvar.csv')
$var  = $Var
$varId = $varIds[$var]
$vals = @($Value, ($Value -replace '\.', ','))

Show 'Read BEFORE'
try {
  $readCur = if ($varId) { MakeUri('commissioning/getvar.csv', "id=$varId") } else { $read }
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $readCur -TimeoutSec 8).Content
  ($content | Select-String -Pattern $var) | ForEach-Object { Log $_.ToString() }
} catch { Log 'Read failed' }

foreach ($valCur in $vals) {
  Show ("TRY value=" + $valCur)
  $gets = @(
    "name=$var&value=$valCur",
    "name=$var&val=$valCur",
    $(if ($varId) { "id=$varId&value=$valCur" } else { $null }),
    "var=$var&val=$valCur"
  ) | Where-Object { $_ }
  foreach ($q in $gets) {
    Show ("GET setvar?" + $q)
    $u = MakeUri('setvar.csv', $q)
    try { Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 8 | Out-Null } catch { Log ("GET error: " + $_.Exception.Message) }
    Start-Sleep -Milliseconds 500
  }

  Show 'Read AFTER GET attempts'
  try {
    $readCur = if ($varId) { MakeUri('commissioning/getvar.csv', "id=$varId") } else { $read }
    $content = (Invoke-WebRequest -UseBasicParsing -Uri $readCur -TimeoutSec 8).Content
    ($content | Select-String -Pattern $var) | ForEach-Object { Log $_.ToString() }
  } catch { Log 'Read failed' }

  $posts = @(
    "name=$var&value=$valCur",
    "name=$var&val=$valCur",
    $(if ($varId) { "id=$varId&value=$valCur" } else { $null }),
    "var=$var&val=$valCur"
  ) | Where-Object { $_ }
  foreach ($b in $posts) {
    Show ("POST body: " + $b)
    try { Invoke-WebRequest -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri $setUrl -Body $b -TimeoutSec 8 | Out-Null } catch { Log ("POST error: " + $_.Exception.Message) }
    Start-Sleep -Milliseconds 500
  }

  Show 'Read AFTER POST attempts'
  try {
    $readCur = if ($varId) { MakeUri('getvar.csv', "id=$varId") } else { $read }
    $content = (Invoke-WebRequest -UseBasicParsing -Uri $readCur -TimeoutSec 8).Content
    ($content | Select-String -Pattern $var) | ForEach-Object { Log $_.ToString() }
  } catch { Log 'Read failed' }
}

$unlockVars  = @('PwdService','PwdUser','PwdManuf')
$unlockCodes = @('0002','1234','1489')
foreach ($uv in $unlockVars) {
  $uvId = $unlockIds[$uv]
  foreach ($code in $unlockCodes) {
    Show ("UNLOCK GET " + $uv + "=" + $code)
    try { Invoke-WebRequest -UseBasicParsing -Uri (MakeUri('setvar.csv', "id=$uvId&value=$code")) -TimeoutSec 8 | Out-Null } catch { Log ("UNLOCK GET error: " + $_.Exception.Message) }
    Start-Sleep -Milliseconds 400

    Show ("UNLOCK POST " + $uv + "=" + $code)
    try { Invoke-WebRequest -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri $setUrl -Body ("id=$uvId&value=$code") -TimeoutSec 8 | Out-Null } catch { Log ("UNLOCK POST error: " + $_.Exception.Message) }
    Start-Sleep -Milliseconds 400

    foreach ($valCur in $vals) {
      Show ("WRITE after UNLOCK value=" + $valCur)
      foreach ($q in @("name=$var&value=$valCur","name=$var&val=$valCur",$(if ($varId) { "id=$varId&value=$valCur" } else { $null }),"var=$var&val=$valCur") | Where-Object { $_ }) {
        Show ("GET setvar?" + $q)
        try { Invoke-WebRequest -UseBasicParsing -Uri (MakeUri('setvar.csv', $q)) -TimeoutSec 8 | Out-Null } catch { Log ("GET error: " + $_.Exception.Message) }
        Start-Sleep -Milliseconds 500
      }
      foreach ($b in @("name=$var&value=$valCur","name=$var&val=$valCur",$(if ($varId) { "id=$varId&value=$valCur" } else { $null }),"var=$var&val=$valCur") | Where-Object { $_ }) {
        Show ("POST body: " + $b)
        try { Invoke-WebRequest -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri $setUrl -Body $b -TimeoutSec 8 | Out-Null } catch { Log ("POST error: " + $_.Exception.Message) }
        Start-Sleep -Milliseconds 500
      }
      Show 'Read AFTER UNLOCK+WRITE'
      try {
        $readCur = if ($varId) { MakeUri('commissioning/getvar.csv', "id=$varId") } else { $read }
        $content = (Invoke-WebRequest -UseBasicParsing -Uri $readCur -TimeoutSec 8).Content
        ($content | Select-String -Pattern $var) | ForEach-Object { Log $_.ToString() }
      } catch { Log 'Read failed' }
    }

    Show 'Relock'
    try { Invoke-WebRequest -UseBasicParsing -Uri (MakeUri('setvar.csv', "id=$uvId&value=0")) -TimeoutSec 8 | Out-Null } catch { Log ("Relock error: " + $_.Exception.Message) }
    try { Invoke-WebRequest -UseBasicParsing -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri $setUrl -Body ("id=$uvId&value=0") -TimeoutSec 8 | Out-Null } catch { Log ("Relock POST error: " + $_.Exception.Message) }
  }
}

Show 'Read FINAL'
try {
  $readCur = if ($varId) { MakeUri('commissioning/getvar.csv', "id=$varId") } else { $read }
  $content = (Invoke-WebRequest -UseBasicParsing -Uri $readCur -TimeoutSec 8).Content
  ($content | Select-String -Pattern $var) | ForEach-Object { Log $_.ToString() }
} catch { Log 'Read failed' }

Log "Output saved to $PSScriptRoot\test_setpoint.log"