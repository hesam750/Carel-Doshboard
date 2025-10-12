param(
  [string]$Patterns = 'RoomTemp|SetP|Comfort|Economy|PreComfort|CurrRoomTemp|Sel|Select|Mode|Profile|Day'
)

$ErrorActionPreference = 'Stop'

function ScanFile([string]$path){
  if(Test-Path $path){
    Write-Host ('Scanning ' + $path)
    Select-String -Path $path -Pattern $Patterns | ForEach-Object { $_.Line }
  } else {
    Write-Host ('File not found: ' + $path)
  }
}

ScanFile './allvars_device.csv'
ScanFile './vars_extracted_all.csv'