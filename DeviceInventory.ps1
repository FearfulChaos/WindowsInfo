# Device Inventory Tool
Write-Host "Collecting system information..." -ForegroundColor Cyan
$progress = 0
$totalSteps = 11

function Update-ProgressBar {
    param([int]$step)
    $percent = [math]::Round(($step / $totalSteps) * 100)
    Write-Progress -Activity "Scanning System..." -Status "$percent% Complete" -PercentComplete $percent
}

Update-ProgressBar -step (++$progress)
$sysInfo = Get-ComputerInfo | Select-Object CsName, OsName, OsArchitecture, WindowsVersion, CsModel, CsManufacturer

Update-ProgressBar -step (++$progress)
$cpu = (Get-WmiObject Win32_Processor).Name

Update-ProgressBar -step (++$progress)
$ram = "{0:N0} MB" -f ((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1MB)

Update-ProgressBar -step (++$progress)
$gpu = (Get-WmiObject Win32_VideoController).Name

Update-ProgressBar -step (++$progress)
$allDisks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' | 
            Select-Object DeviceId,
                          @{Name="Size";Expression={[math]::Round($_.Size/1GB,2)}},
                          @{Name="FreeSpace";Expression={[math]::Round($_.FreeSpace/1GB,2)}}
$diskUsage = ($allDisks | ForEach-Object {
	"{0} {1} GB free of {2} GB" -f $_.DeviceId, $_.FreeSpace, $_.Size
}) -join ' | '

Update-ProgressBar -step (++$progress)
$DiskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DeviceId = "C:"' | 
            Select-object DeviceId,
                          @{Name="Size";Expression={[math]::Round($_.Size/1GB,2)}},
                          @{Name="FreeSpace";Expression={[math]::Round($_.FreeSpace/1GB,2)}}

$DiskInfo
$diskUsage = "{0} GB free of {1} GB" -f $DiskInfo.FreeSpace, $DiskInfo.Size

Update-ProgressBar -step (++$progress)
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Update-ProgressBar -step (++$progress)
$domainInfo = Get-CimInstance Win32_ComputerSystem
$domainJoined = if ($domainInfo.PartOfDomain) { "Yes - $($domainInfo.Domain)" } else { "No (Workgroup: $($domainInfo.Workgroup))" }

Update-ProgressBar -step (++$progress)
$net = Get-NetIPConfiguration | Where-Object {
	$_.IPv4Address -ne $null -and $_.NetAdapter.Status -eq 'Up'
} | Select-Object -First 1
$ip = $net.IPv4Address.IPAddress
$mac = $net.NetAdapter.MacAddress

Update-ProgressBar -step (++$progress)
$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptimeFormatted = (Get-Date) - $uptime
$up = "{0} days, {1} hours, {2} minutes" -f $uptimeFormatted.Days, $uptimeFormatted.Hours, $uptimeFormatted.Minutes

$report = [PSCustomObject]@{
    "Device Name"     = $sysInfo.CsName
    "Logged In User"  = $currentUser
    "Domain Joined"   = $domainJoined
    "OS Version"      = $sysInfo.OsName
    "Architecture"    = $sysInfo.OsArchitecture
    "CPU"             = $cpu
    "RAM"             = $ram
    "GPU"             = $gpu
    "Storage"         = $diskUsage
    "IP Address"      = $ip
    "MAC Address"     = $mac
    "Uptime"          = $up
}

Write-Progress -Activity "Scanning System..." -Completed
Write-Host "`nSystem Inventory Completed!" -ForegroundColor Green

# Export Options
$folder = "C:\DeviceReports"
if (!(Test-Path $folder)) { New-Item -Path $folder -ItemType Directory | Out-Null }
$date = Get-Date -Format "yyyy-MM-dd_HHmm"
$exportFile = "$folder\Device_Inventory_$date.csv"
$report | Export-Csv -Path $exportFile -NoTypeInformation
Write-Host "Report saved to: $exportFile" -ForegroundColor Yellow