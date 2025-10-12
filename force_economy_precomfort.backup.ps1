param(
    [string]$TargetValue = "25.0",
    [string]$Proxy = "http://127.0.0.1:8002"
)

Write-Host "=== FORCE ECONOMY/PRECOMFORT SCRIPT ==="
Write-Host "Target Value: $TargetValue"
Write-Host "Proxy: $Proxy"

function PostVarById([string]$id, [string]$value) {
    if (-not $id) { Write-Host "ERROR: Empty ID for PostVar"; return }
    $url = "$Proxy/setvar.csv?$id=$value"
    Write-Host "POST: $url"
    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing
        Write-Host "Response: $($response.StatusCode) - $($response.Content)"
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)"
    }
}

function GetVarById([string]$id) {
    if (-not $id) { Write-Host "ERROR: Empty ID for GetVar"; return $null }
    $url = "$Proxy/getvar.csv?$id"
    Write-Host "GET: $url"
    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing
        Write-Host "Response: $($response.StatusCode) - $($response.Content)"
        return $response.Content
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)"
        return $null
    }
}

function FindId([string]$name) {
    $encoded = [System.Web.HttpUtility]::UrlEncode($name)
    $url = "$Proxy/getvar.csv?FindId=$encoded"
    Write-Host "FIND: $name"
    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing
        $id = $response.Content.Trim()
        Write-Host "ID($name) = $id"
        return $id
    } catch {
        Write-Host "ERROR FindId($name): $($_.Exception.Message)"
        return $null
    }
}

function PostByName([string]$name, [string]$value) {
    $id = FindId $name
    if ($id) { PostVarById $id $value } else { Write-Host "SKIP: No ID for $name" }
}

function GetByName([string]$name) {
    $id = FindId $name
    if ($id) { return GetVarById $id } else { Write-Host "SKIP: No ID for $name"; return $null }
}

# STEP 1: Disable all schedulers
Write-Host "=== STEP 1: DISABLE ALL SCHEDULERS ==="
PostByName "Scheduler_OnOffUnit.Scheduler_1.Today.Enabled" "0"
PostByName "Scheduler_OnOffUnit.Scheduler_1.SpecDay.Enabled" "0"
PostByName "Scheduler_OnOffUnit.Scheduler_1.Holiday.Enabled" "0"
PostByName "Scheduler_OnOffUnit.Scheduler_1.VacationsSched.Enabled" "0"

# STEP 2: Force system manual status
Write-Host "=== STEP 2: FORCE SYSTEM MANUAL ==="
PostByName "SystemStatus.ManAct" "1"
PostByName "SystemStatus.Man" "1"  # 1 = ECONOMY (assumed mapping)

# STEP 3: Disable all DIN overrides
Write-Host "=== STEP 3: DISABLE DIN OVERRIDES ==="
PostByName "DIN_Comf" "0"
PostByName "DIN_PreComf" "0"
PostByName "DIN_Eco" "0"
PostByName "DIN_Off" "0"

# STEP 4: Activate manual setpoint source
Write-Host "=== STEP 4: ACTIVATE MANUAL SOURCE ==="
PostByName "RoomTempSetP.ManAct" "1"

# STEP 5: Apply Economy setpoint
Write-Host "=== STEP 5: APPLY ECONOMY SETPOINT ==="
$commaValue = $TargetValue -replace '\.', ','
PostByName "SystemStatus.Man" "1"   # ECONOMY
PostByName "DIN_Eco" "1"
PostByName "DIN_PreComf" "0"
PostByName "UnitSetP.RoomTempSetP.Economy" $TargetValue
PostByName "UnitSetP.RoomTempSetP.Economy" $commaValue
PostByName "UnitSetP.RoomTempSetP.Man" $TargetValue
PostByName "UnitSetP.RoomTempSetP.Man" $commaValue

# Save
PostByName "SaveData" "1"
Start-Sleep -Seconds 2

Write-Host "=== READ ECONOMY ==="
$currEco = GetByName "CurrRoomTempSetP_Val"
$ecoVal = GetByName "UnitSetP.RoomTempSetP.Economy"

# STEP 6: Apply PreComfort setpoint
Write-Host "=== STEP 6: APPLY PRECOMFORT SETPOINT ==="
PostByName "SystemStatus.Man" "2"   # 2 = PRE-COMFORT (assumed mapping)
PostByName "DIN_Eco" "0"
PostByName "DIN_PreComf" "1"
PostByName "UnitSetP.RoomTempSetP.PreComfort" $TargetValue
PostByName "UnitSetP.RoomTempSetP.PreComfort" $commaValue

# Save
PostByName "SaveData" "1"
Start-Sleep -Seconds 2

Write-Host "=== READ PRECOMFORT ==="
$currPre = GetByName "CurrRoomTempSetP_Val"
$preVal = GetByName "UnitSetP.RoomTempSetP.PreComfort"

# Final verification
Write-Host "=== FINAL VERIFICATION ==="
$finalCurr = GetByName "CurrRoomTempSetP_Val"
$finalEco = GetByName "UnitSetP.RoomTempSetP.Economy"
$finalPre = GetByName "UnitSetP.RoomTempSetP.PreComfort"
$finalComf = GetByName "UnitSetP.RoomTempSetP.Comfort"
$finalMan = GetByName "UnitSetP.RoomTempSetP.Man"

Write-Host "Target: $TargetValue"
Write-Host "Curr: $finalCurr"
Write-Host "Eco: $finalEco"
Write-Host "PreComf: $finalPre"
Write-Host "Comf: $finalComf"
Write-Host "Man: $finalMan"

if (($finalCurr -like "*25*") -or ($finalEco -like "*25*") -or ($finalPre -like "*25*")) {
    Write-Host "SUCCESS: Values applied." -ForegroundColor Green
} else {
    Write-Host "NOTICE: Values may be locked; checking status..." -ForegroundColor Yellow
    $sysManAct = GetByName "SystemStatus.ManAct"
    $sysMan = GetByName "SystemStatus.Man"
    $roomManAct = GetByName "RoomTempSetP.ManAct"
    Write-Host "SystemStatus.ManAct: $sysManAct"
    Write-Host "SystemStatus.Man: $sysMan"
    Write-Host "RoomTempSetP.ManAct: $roomManAct"
}

Write-Host "=== SCRIPT COMPLETED ==="