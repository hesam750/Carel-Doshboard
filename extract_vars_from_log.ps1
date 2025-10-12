$ErrorActionPreference = 'Stop'
$log = 'log.text'
# Broad patterns to be robust against formatting/encoding
$patVarsTable = 'varsTable'
$patVarsUrl   = '"page_url":"http://169.254.61.68/vars.htm"'
$patHasName   = '"col_2":"'

function Clean-Line([string]$line) {
    if (-not $line) { return $null }
    $l = $line.Trim()
    $l = $l -replace '^[`]+',''
    $l = $l -replace '[`]+$',''
    $l = $l -replace ',\s*$', ''
    return $l
}

function Try-Parse([string]$line) {
    try { return $line | ConvertFrom-Json } catch {
        $id   = [regex]::Match($line, '"col_1":"(?<v>.*?)"').Groups['v'].Value
        $name = [regex]::Match($line, '"col_2":"(?<v>.*?)"').Groups['v'].Value
        $desc = [regex]::Match($line, '"col_3":"(?<v>.*?)"').Groups['v'].Value
        $val  = [regex]::Match($line, '"col_4":"(?<v>.*?)"').Groups['v'].Value
        $url  = [regex]::Match($line, '"page_url":"(?<v>.*?)"').Groups['v'].Value
        $tid  = [regex]::Match($line, '"table_id":"(?<v>.*?)"').Groups['v'].Value
        $tidx = [regex]::Match($line, '"table_index":(?<v>-?\d+)').Groups['v'].Value
        if ($name) {
            return [PSCustomObject]@{ col_1=$id; col_2=$name; col_3=$desc; col_4=$val; page_url=$url; table_id=$tid; table_index=$tidx }
        }
        return $null
    }
}

# Strategy A: Prefer explicit varsTable matches (case-insensitive, simple match)
$matchesA = Select-String -Path $log -SimpleMatch -Pattern $patVarsTable
# Strategy B: Fallback to page URL + has name
$matchesB = if ($matchesA.Count -eq 0) { Select-String -Path $log -SimpleMatch -Pattern $patVarsUrl | Where-Object { $_.Line -like "*`"col_2`":`"*" } } else { @() }

$allMatches = @()
if ($matchesA.Count -gt 0) { $allMatches = $matchesA }
elseif ($matchesB.Count -gt 0) { $allMatches = $matchesB }

Write-Host ("MATCHED_LINES_A=" + $matchesA.Count)
Write-Host ("MATCHED_LINES_B=" + $matchesB.Count)

$lines = $allMatches | Select-Object -ExpandProperty Line | ForEach-Object { Clean-Line $_ } | Where-Object { $_ -and $_.Trim().Length -gt 0 }

$objs = @()
foreach ($l in $lines) {
    $o = Try-Parse $l
    if ($o -ne $null) { $objs += $o }
}

$rows = $objs | ForEach-Object {
    [PSCustomObject]@{
        VariableID           = $_.col_1
        VariableName         = $_.col_2
        VariableDescription  = $_.col_3
        VariableCurrentValue = $_.col_4
        PageUrl              = $_.page_url
        TableId              = $_.table_id
        TableIndex           = $_.table_index
    }
} | Where-Object { $_.VariableName -and ($_.VariableName -ne '') }

$csvPath = 'vars_htm_extract.csv'
$ndjsonPath = 'vars_htm_extract.ndjson'
$rows | Sort-Object {[int]($_.VariableID)} -ErrorAction SilentlyContinue | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
$rows | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -Path $ndjsonPath -Encoding UTF8

Write-Host ("TOTAL_ROWS=" + $rows.Count)
Write-Host 'FIRST_10_ROWS:'
$rows | Select-Object -First 10 VariableID,VariableName,VariableCurrentValue | Format-Table -AutoSize | Out-String | Write-Host
Write-Host 'LAST_10_ROWS:'
$rows | Select-Object -Last 10 VariableID,VariableName,VariableCurrentValue | Format-Table -AutoSize | Out-String | Write-Host