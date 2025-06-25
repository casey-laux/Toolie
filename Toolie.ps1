$asciiArt = @"
 ____  _____  _____  __    ____  ____ 
(_  _)(  _  )(  _  )(  )  (_  _)( ___)
  )(   )(_)(  )(_)(  )(__  _)(_  )__) 
 (__) (_____)(_____)(____)(____)(____)

The TuiToolkit
"@

function Write-CenteredText {
    param(
        [string]$Text,
        [System.ConsoleColor]$Color = [System.ConsoleColor]::White
    )
    $screenWidth = $host.UI.RawUI.WindowSize.Width
    $spaces = [Math]::Max(0, ($screenWidth - $Text.Length) / 2)
    Write-Host (" " * [Math]::Floor($spaces) + $Text) -ForegroundColor $Color
}

function Clear-HostWithBanner {
    Clear-Host
    $asciiLines = $asciiArt -split "`n"
    foreach ($line in $asciiLines) {
        Write-CenteredText $line
    }
    Write-Host ""
}

function Show-ArrowMenu {
    param (
        [string]$Title,
        [string[]]$Options
    )

    $index = 0
    while ($true) {
        Clear-HostWithBanner
        Write-CenteredText "=== $Title ===`n"

        for ($i = 0; $i -lt $Options.Length; $i++) {
            if ($i -eq $index) {
                Write-CenteredText "> $($Options[$i])" -Color Cyan
            } else {
                Write-CenteredText "  $($Options[$i])"
            }
        }

        Write-CenteredText "`nUse arrow keys to navigate, Enter to select, Esc to go back" -Color DarkGray

        $key = [System.Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow'   { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($Options.Length - 1)) { $index++ } }
            'RightArrow'{ return $index }
            'Enter'     { return $index }
            'LeftArrow' { return -1 }
            'Escape'    { return -1 }
        }
    }
}

function Pause {
    Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
}

function Show-Menu {
    param (
        [string]$MenuTitle,
        [string[]]$Options,
        [scriptblock[]]$Actions
    )

    while ($true) {
        $selection = Show-ArrowMenu -Title $MenuTitle -Options ($Options + @("<< Back"))

        if ($selection -eq -1 -or $selection -eq $Options.Length) {
            break
        }

        Clear-HostWithBanner
        Write-CenteredText "=== $MenuTitle > $($Options[$selection]) ===`n" -Color Magenta
        & $Actions[$selection]
        Write-CenteredText "`nPress any key to continue..." -Color DarkGray
        [void][System.Console]::ReadKey($true)
    }
}

function Get-VTSInterfaces {
# This script checks the network configuration of the Wi-Fi and Ethernet interfaces
    function IsValidIP($ip) {
        return $ip -and -not ($ip.StartsWith("169.254"))
    }

    $wifi = Get-NetIPConfiguration -InterfaceAlias "Wi-Fi" 
    $eth = Get-NetIPConfiguration | Where-Object {$_.InterfaceAlias -like "Ethernet"}

    $wifiIP = $wifi.IPv4Address.IPAddress
    $ethIP = $eth.IPv4Address.IPAddress

    $wifiConnected = IsValidIP $wifiIP
    $ethConnected = IsValidIP $ethIP
    Write-Host "`n"

    if ($wifiConnected) {
        Write-Host "WIFI Connected: $wifiConnected" -ForegroundColor Green
    } else {
        Write-Host "WIFI Connected: $wifiConnected" -ForegroundColor Red
    }

    if ($ethConnected) {
        Write-Host "Ethernet Connected: $ethConnected" -ForegroundColor Green
    } else {
        Write-Host "Ethernet Connected: $ethConnected" -ForegroundColor Red
    }
    Write-Host ""

    if ($wifiConnected) {
        Write-Host "`nWIFI IP: $wifiIP"
        Write-Host "WIFI DNS: $($wifi.DnsServer.ServerAddresses -join ', ')"
        Write-Host "WIFI Default Gateway: $($wifi.IPv4DefaultGateway.NextHop)"
        Write-Host ""
    }

    if ($ethConnected) {
        Write-Host "`nETH IP: $ethIP"
        Write-Host "ETH DNS: $($eth.DnsServer.ServerAddresses -join ', ')"
        Write-Host "ETH Default Gateway: $($eth.IPv4DefaultGateway.NextHop)"
    }
}

function Get-vtsUSB {
    # This script checks for USB devices connected to the system and colors output by status
    Write-Host "USB Devices:`n" -ForegroundColor Yellow

    $devices = Get-PnpDevice -FriendlyName * |
        Where-Object { $_.InstanceId -like "*usb*" } |
        Select-Object FriendlyName, Present, Status -Unique |
        Sort-Object Present -Descending

    # Print header
    Write-Host ("{0,-35} {1,-8} {2,-8}" -f "FriendlyName", "Present", "Status") 
    Write-Host ("{0,-35} {1,-8} {2,-8}" -f "------------", "-------", "------") 

    foreach ($dev in $devices) {
        $color = "Yellow"
        if ($dev.Present -eq $true -and $dev.Status -eq "OK") {
            $color = "Green"
        } elseif ($dev.Present -eq $false -and $dev.Status -eq "Unknown") {
            $color = "Red"
        }
        Write-Host ("{0,-35} {1,-8} {2,-8}" -f $dev.FriendlyName, $dev.Present, $dev.Status) -ForegroundColor $color
    }
}

function Get-vtsBattery {
    powercfg /batteryreport > $null

    $report = Get-Content "$PWD/battery-report.html"

    $parsed = ($report -split '<span class="label">' |
    Select-String "DESIGN CAPACITY","FULL CHARGE CAPACITY" |
    Select-Object -first 2 -expand Line) -replace "DESIGN CAPACITY</span></td><td>" -replace "FULL CHARGE CAPACITY</span></td><td>"

    $DesignCapacity = $parsed[0]
    $FullChargeCapacity = $parsed[1]

    $DesignCapacityPercentage = $DesignCapacity -replace " mWh"
    $FullChargeCapacityPercentage = $FullChargeCapacity -replace " mWh"


    try {
        [int]$HealthPercentage = $FullChargeCapacityPercentage/$DesignCapacityPercentage * 100
    } catch {
        Write-Host "Error accessing battery, is this a laptop?" -ForegroundColor Red
        Remove-Item "$PWD/battery-report.html" -Force
        return
    }
    


    $Message = "Health: $HealthPercentage %
    Design Capacity: $DesignCapacity
    Full Charge Capacity: $FullChargeCapacity"
    # Display the health percentage with color coding
    if ($HealthPercentage -lt 80) {
        Write-Host $Message -ForegroundColor Red
    } elseif ($HealthPercentage -ge 80 -and $HealthPercentage -le 85) {
        Write-Host $Message -ForegroundColor Yellow
    } else {
        Write-Host $Message -ForegroundColor Green
    }
    Remove-Item "$PWD/battery-report.html" -Force
}


function Get-VTSUpdates {
    # Part 1: Show last 5 installed updates
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ([int](Get-Process -Id $PID | Select-Object -ExpandProperty MainWindowHandle) -ne 0) {
        $arguments = "& '" + $myinvocation.MyCommand.Path + "'"
        Write-Host "Administrator privileges required for updates. Please run as Administrator." -ForegroundColor Yellow
        exit 
    }
}
    Write-Host "Retrieving the last 5 Windows Update events..." -ForegroundColor Green
    try {
        $lastUpdates = Get-WinEvent -LogName System -FilterXPath '
            *[System[Provider[@Name="Microsoft-Windows-WindowsUpdateClient"] and
            (EventID=19 or EventID=20)]]' | 
            Select-Object -First 5 -Property TimeCreated, Message

        if ($lastUpdates) {
            Write-Host "`nLast 5 Installed Updates:" -ForegroundColor Green
            $lastUpdates | Format-Table TimeCreated, Message -AutoSize
        } else {
            Write-Host "No previous updates found in the system logs." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error: Failed to retrieve update history." -ForegroundColor Red
    }

    # Wait for user input before proceeding
    Write-Host "`nPress Enter to search for pending updates..." -ForegroundColor Green
    Read-Host

    # Part 2: Search for and handle pending updates
    Write-Host "Checking for pending updates..." -ForegroundColor Green

    # Ensure PSWindowsUpdate is installed
    try {
        if (!(Get-Module -ListAvailable PSWindowsUpdate)) {
            Install-Module PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
            Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green
        }
        Import-Module PSWindowsUpdate -ErrorAction Stop
        Write-Host "PSWindowsUpdate module imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to install or import PSWindowsUpdate module." -ForegroundColor Red
        return
    }

    #   Temporarily set execution policy to Bypass for this session
    $originalPolicy = Get-ExecutionPolicy
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    # Get outstanding updates
    try {
        $outstandingUpdates = Get-WindowsUpdate -ErrorAction Stop
        if ($outstandingUpdates.Count -gt 0) {
            Write-Host "`nThere are $($outstandingUpdates.Count) outstanding updates available." -ForegroundColor Green
            Write-Host "`nAvailable Updates:" -ForegroundColor Yellow
            $outstandingUpdates | Format-Table KB, Size, Title -AutoSize

            Write-Host "`nDo you want to install them now? (y/n)" -ForegroundColor Green
            $response = Read-Host

            if ($response -match "^(y|yes)$") {
                try {
                    Install-WindowsUpdate -AcceptAll -ErrorAction Stop
                    Write-Host "Updates installed successfully." -ForegroundColor Green
                } catch {
                    Write-Host "Error: Failed to install updates." -ForegroundColor Red
                }
            } elseif ($response -match "^(n|no)$") {
                Write-Host "Updates not installed." -ForegroundColor Yellow
            } else {
                Write-Host "Invalid response. No action taken." -ForegroundColor Red
            }
        } else {
            Write-Host "No outstanding updates found." -ForegroundColor Green
        }
    } catch {
        Write-Host "Error: Failed to retrieve updates." -ForegroundColor Red
    }

    # Reset execution policy to the original setting
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy $originalPolicy -Force
    Write-Host "Execution policy reset to original settings." -ForegroundColor Green
}

function VTSSpeedtest {
    <#PSScriptInfo

.VERSION 0.0.3

.GUID a4af5e07-d626-4b97-b4d6-eef7265d1f7c

.AUTHOR asheroto

.COMPANYNAME asheroto

.TAGS PowerShell speedtest speed test speedtest.net

.PROJECTURI https://github.com/asheroto/speedtest

.RELEASENOTES
[Version 0.0.1] - Initial Release.
[Version 0.0.2] - Added UseBasicParsing parameter to Invoke-WebRequest commands to fix issue with certain systems.
[Version 0.0.3] - Adjusted to work with GDPR acceptance.

#>

<#
.SYNOPSIS
    Downloads and runs the Speedtest.net CLI client.
.DESCRIPTION
    Downloads and runs the Speedtest.net CLI client.

    Designed to use with short URL to make it easy to remember.
.EXAMPLE
    speedtest.ps1
.PARAMETER Version
    Displays the version of the script.
.PARAMETER Help
    Displays the full help information for the script.
.NOTES
    Version      : 0.0.3
    Created by   : asheroto
.LINK
    Project Site: https://github.com/asheroto/speedtest
#>
    param (
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$ScriptArgs
    )

    # Version
    $CurrentVersion = '0.0.3'
    $RepoOwner = 'asheroto'
    $RepoName = 'speedtest'
    $PowerShellGalleryName = 'speedtest'

    # Versions
    $ProgressPreference = 'SilentlyContinue' # Suppress progress bar (makes downloading super fast)
    $ConfirmPreference = 'None' # Suppress confirmation prompts

    # Display version if -Version is specified
    if ($Version.IsPresent) {
        $CurrentVersion
        exit 0
    }

    # Display full help if -Help is specified
    if ($Help) {
        Get-Help -Name $MyInvocation.MyCommand.Source -Full
        exit 0
    }

    # Display $PSVersionTable and Get-Host if -Verbose is specified
    if ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose']) {
        $PSVersionTable
        Get-Host
    }

    # ============================================================================ #
    # Startup
    # ============================================================================ #

    # Scrape the webpage to get the download link
    function Get-SpeedTestDownloadLink {
        $url = "https://www.speedtest.net/apps/cli"
        $webContent = Invoke-WebRequest -Uri $url -UseBasicParsing
        if ($webContent.Content -match 'href="(https://install\.speedtest\.net/app/cli/ookla-speedtest-[\d\.]+-win64\.zip)"') {
            return $matches[1]
        } else {
            Write-Output "Unable to find the win64 zip download link."
            return $null
        }
    }

    # Download the zip file
    function Download-SpeedTestZip {
        param (
            [string]$downloadLink,
            [string]$destination
        )
        Invoke-WebRequest -Uri $downloadLink -OutFile $destination -UseBasicParsing
    }

    # Extract the zip file
    function Extract-Zip {
    param (
        [string]$zipPath,
        [string]$destination
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destination)
    } catch {
        if ($_.Exception.Message -like "*already exists*") {
        } else {
            throw $_
        }
    }
    }

    # Run the speedtest executable
    function Run-SpeedTest {
        param (
            [string]$executablePath,
            [array]$arguments
        )

        # Check if '--accept-license' is already in arguments
        if (-not ($arguments -contains "--accept-license")) {
            $arguments += "--accept-license"
        }

        # Check if '--accept-gdpr' is already in arguments
        if (-not ($arguments -contains "--accept-gdpr")) {
            $arguments += "--accept-gdpr"
        }

        & $executablePath $arguments
    }

    # Cleanup
    function Remove-File {
        param (
            [string]$Path
        )
        try {
            if (Test-Path -Path $Path) {
                Remove-Item -Path $Path -Recurse -ErrorAction Stop
            }
        } catch {
            Write-Debug "Unable to remove item: $_"
        }
    }

    function Remove-Files {
        param(
            [string]$zipPath,
            [string]$folderPath
        )
        Remove-File -Path $zipPath
        Remove-File -Path $folderPath
    }

    # Main Script
    try {
        $tempFolder = $env:TEMP
        $zipFilePath = Join-Path $tempFolder "speedtest-win64.zip"
        $extractFolderPath = Join-Path $tempFolder "speedtest-win64"

        Remove-Files -zipPath $zipFilePath -folderPath $extractFolderPath

        $downloadLink = Get-SpeedTestDownloadLink
        Download-SpeedTestZip -downloadLink $downloadLink -destination $zipFilePath

        Extract-Zip -zipPath $zipFilePath -destination $extractFolderPath

        $executablePath = Join-Path $extractFolderPath "speedtest.exe"
        Run-SpeedTest -executablePath $executablePath -arguments $ScriptArgs

        Remove-Files -zipPath $zipFilePath -folderPath $extractFolderPath

        Write-Output "Done."
    } catch {
        Write-Error "An error occurred: $_"
    }
}


function PrinterRepair {
    # Script: Reconfigure Network Printers for SWC (Add First, Remove After Success)
# Description:
#   This script removes existing printers and re-adds them based on the following rules:
#     1. Any printer with SWC in the server name is replaced by \\SWC-PS01\<ShareName>
#     2. For printers not on CH-DC/CH-DC2:
#           - Check if a printer with the same share name exists on CH-DC or CH-DC2.
#           - If found, add it from there first, then remove the current printer.
#     3. For printers on CH-DC/CH-DC2 using FQDN:
#           - Add it using the short server name first, then remove the current printer.



$logPath = Join-Path -Path "\temp\" -ChildPath "printerRepairLog.txt"

function Write-Log {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $Message"
    # Write to console
    Write-Host $Message -ForegroundColor $Color
    # Write to log file
    Add-Content -Path $logPath -Value $entry
}

# Start of Script
Write-Log "`n===== Starting Printer Reconfiguration Script =====`n" "Cyan"

# Get all network printers (skip local printers like "OneNote (Desktop)")
$nsprinters = Get-Printer \\ns-dc* | Select-Object -ExpandProperty Name
$DC54printers = Get-Printer \\DC54* | Select-Object -ExpandProperty Name
$bimaPrinters = Get-Printer \\ch-bima-ps01* | Select-Object -ExpandProperty Name

Write-Log "`nStarting NS Printer Cleanup..." "Cyan"
foreach ($printer in $nsprinters) {
    Write-Log "Re-adding and removing NS printer: $printer" "Yellow"
    Add-Printer -ConnectionName "$printer"
    Start-Sleep 1
    Remove-Printer "$printer"
    
    if ($?) {
        Write-Log "$printer removed." "Green"
    } else {
        Write-Log "Failed to remove $printer." "Red"
    }
}

foreach ($printer in $DC54printers) {
    Add-Printer -ConnectionName "$printer"
    Start-Sleep 1
    Remove-Printer "$printer"
    if ($?) {
        Write-Log "$printer removed." "Green"
    } else {
        Write-Log "Failed to remove $printer." "Red"
    }
}


Write-Log "`nStarting CH-BIMA-PS01 Printer Cleanup..." "Cyan"
foreach ($printer in $bimaPrinters) {
    Write-Log "Re-adding and removing CH-BIMA-PS01 printer: $printer" "Yellow"
    Add-Printer -ConnectionName "$printer"
    Start-Sleep 1
    Remove-Printer "$printer"
    
    if ($?) {
        Write-Log "$printer removed." "Green"
    } else {
        Write-Log "Failed to remove $printer." "Red"
    }
}

$printers = Get-Printer | Where-Object { $_.Name -like "\\*" }

Write-Log "`nStarting Printer Reconfiguration..." "Cyan"
foreach ($printer in $printers) {
    # Match printer names of the form \\Server\ShareName using Regex magic.
    if ($printer.Name -match "^\\\\([^\\]+)\\(.+)$") {
        $server    = $matches[1]
        $shareName = $matches[2]

        # New Rule: If server name or sharename contains "SWC" (case-insensitive)
        if ($server -match "SWC" -or $shareName -match "SWC") {

            # Check if printer is already on SWC-PS01
            if ($server -ieq "SWC-PS01") {
                Write-Log "Printer $($printer.Name) is already on SWC-PS01. Skipping..." "Yellow"
                continue
            }

            $newPrinterPath = "\\SWC-PS01\$shareName"
            Write-Log "`nAdding printer $newPrinterPath (SWC Rule)" "Cyan"

            try {
                Add-Printer -ConnectionName $newPrinterPath -ErrorAction Stop
                Write-Log "Successfully added $newPrinterPath" "Green"

                # Now remove the old printer
                Remove-Printer -Name $printer.Name -Confirm:$false
                Write-Log "Removed old printer $($printer.Name)" "Green"
            }
            catch {
                Write-Log "Failed to add printer $newPrinterPath. Skipping removal of $($printer.Name)" "Red"
            }

            continue
        }

        # Case 1: Printer is NOT on CH-DC or CH-DC2
        if ($server -notmatch "^(CH-DC|CH-DC2)(\.|$)") {
            $replacementServer = $null

            # Attempt to find a matching printer on CH-DC
            try {
                $printerOnDC = Get-Printer -ComputerName "CH-DC" -Name $shareName -ErrorAction Stop
                if ($printerOnDC) {
                    $replacementServer = "CH-DC"
                }
            }
            catch { }

            # If not found on CH-DC, try CH-DC2
            if (-not $replacementServer) {
                try {
                    $printerOnDC2 = Get-Printer -ComputerName "CH-DC2" -Name $shareName -ErrorAction Stop
                    if ($printerOnDC2) {
                        $replacementServer = "CH-DC2"
                    }
                }
                catch { }
            }

            if ($replacementServer) {
                $newPrinterPath = "\\$replacementServer\$shareName"
                Write-Log "`nAdding printer $newPrinterPath (Replacement for $($printer.Name))" "Cyan"

                try {
                    Add-Printer -ConnectionName $newPrinterPath -ErrorAction Stop
                    Write-Log "Successfully added $newPrinterPath" "Green"

                    # Now remove the old printer
                    Remove-Printer -Name $printer.Name -Confirm:$false
                    Write-Log "Removed old printer $($printer.Name)" "Green"
                }
                catch {
                    Write-Log "Failed to add printer $newPrinterPath. Skipping removal of $($printer.Name)" "Red"
                }
            }
            else {
                Write-Log "No matching printer found on CH-DC/CH-DC2 for $($printer.Name); skipping..." "Red"
            }
        }
        else {
            # Case 2: Printer is on CH-DC or CH-DC2 but using an FQDN (contains a dot)
            if ($server -match "\.") {
                $shortServer = $server.Split('.')[0]

                if ($shortServer -eq "CH-DC" -or $shortServer -eq "CH-DC2") {
                    $newPrinterPath = "\\$shortServer\$shareName"
                    Write-Log "`nAdding printer $newPrinterPath (Re-adding with short server name)" "Cyan"

                    try {
                        Add-Printer -ConnectionName $newPrinterPath -ErrorAction Stop
                        Write-Log "Successfully added $newPrinterPath" "Green"

                        # Now remove the old printer
                        Remove-Printer -Name $printer.Name -Confirm:$false
                        Write-Log "Removed old printer $($printer.Name)" "Green"
                    }
                    catch {
                        Write-Log "Failed to add printer $newPrinterPath. Skipping removal of $($printer.Name)" "Red"
                    }
                }
            }
        }
    }
}

Write-Log "`nPrinter reconfiguration complete!" "Green"
Write-Log "`n===== End of Printer Reconfiguration Script =====`n" "Cyan"




    
}

function clear-Space {
        # Set Execution Policy to bypass for the current session
    Set-ExecutionPolicy Bypass -Scope Process -Force

    # Function to get the available free space on the drive
    function Get-FreeSpace {
        $drive = Get-PSDrive -Name C
        return $drive.Used, $drive.Free
    }

    # Record initial free space
    $initialUsedSpace, $initialFreeSpace = Get-FreeSpace

    # Start Component Cleanup using DISM
    Write-Host "Starting DISM component cleanup..."
    Start-Process -FilePath "Dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait
    Write-Host "DISM cleanup complete."

    # Stop Windows Update services to clean SoftwareDistribution folder contents
    Write-Host "Stopping Windows Update and Background Intelligent Transfer services... "
    Stop-Service -Name wuauserv -ErrorAction SilentlyContinue
    Stop-Service -Name bits -ErrorAction SilentlyContinue
    Write-Host "Services stopped."

    # Clean up the SoftwareDistribution folder contents using robocopy
    $SoftwareDistributionPath = "C:\Windows\SoftwareDistribution"
    if (Test-Path $SoftwareDistributionPath -ErrorAction SilentlyContinue) {
        Write-Host "Cleaning up SoftwareDistribution folder contents..."
        # Use robocopy to effectively delete the contents
        $TempPath = Join-Path $SoftwareDistributionPath "empty"
        New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
        robocopy $TempPath $SoftwareDistributionPath /MIR /XD $TempPath
        Remove-Item -Recurse -Force -Path $TempPath
        Write-Host "SoftwareDistribution folder contents deleted."
    } else {
        Write-Host "SoftwareDistribution folder not found."
    }

    # Restart the stopped services (Windows Update and BITS)
    Write-Host "Restarting Windows Update and Background Intelligent Transfer services... "
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Start-Service -Name bits -ErrorAction SilentlyContinue
    Write-Host "Services restarted."

    # Cleanup temp files for all user profiles except "Public" and "Default"
    Write-Host "Cleaning temp files for all users except 'Public' and 'Default'..."

    # Get all user profile directories except "Public" and "Default"
    $UserProfiles = Get-ChildItem "C:\Users" | Where-Object { 
        $_.Name -notin @('Public', 'Default') -and $_.PSIsContainer 
    }

# Initialize a list to store the names of users whose temp files were deleted
    $deletedUsers = @()

    # Loop through each user profile and delete temp files
    foreach ($UserProfile in $UserProfiles) {
        $TempFolder = Join-Path $UserProfile.FullName "AppData\Local\Temp"

        if (Test-Path $TempFolder -ErrorAction SilentlyContinue) {
            try {
                # Delete all contents in the Temp folder
                Get-ChildItem $TempFolder -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                $deletedUsers += $UserProfile.Name
            } catch {
                Write-Host "Failed to delete temp files for user: $($UserProfile.Name) - $_"
            }
        }
    }   

    # Output the names of all users whose temp files were deleted, grouped together
    if ($deletedUsers.Count -gt 0) {
        Write-Host "Temp files deleted for users: $($deletedUsers -join ', ')"
    } else {
        Write-Host "No temp files were deleted."
    }

    Write-Host "Temp folder cleanup complete."

    # Calculate and output total space cleared
    $finalUsedSpace, $finalFreeSpace = Get-FreeSpace
    $spaceFreed = $finalFreeSpace - $initialFreeSpace

    Write-Host "Initial free space: $([math]::Round($initialFreeSpace / 1GB, 2)) GB"
    Write-Host "Final free space: $([math]::Round($finalFreeSpace / 1GB, 2)) GB"
    Write-Host "Total space freed: $([math]::Round($spaceFreed / 1GB, 2)) GB"

    Write-Host "Disk space cleanup complete."




    
}

function Get-VTSNetAdapter {
    function Show-Adapters {
        while ($true) {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
            if (-not $adapters) {
                Write-Error "No active network adapters found."
                return
            }

                $adapterNames = @($adapters | Select-Object -ExpandProperty Name)
                $selection = Show-ArrowMenu -Title "Available Network Adapters" -Options ($adapterNames + @("<< Back"))

            if ($selection -eq -1 -or $selection -eq $adapterNames.Length) {
                return
            }

            $selectedAdapter = $adapterNames[$selection]
            Show-Properties -AdapterName $selectedAdapter
        }
    }

    function Show-Properties {
        param ([string]$AdapterName)

        while ($true) {
            $props = Get-NetAdapterAdvancedProperty -Name $AdapterName
            if (-not $props) {
                Write-Error "No advanced properties found for $AdapterName"
                return
            }

            # Properties per page
            $itemsPerPage = 10
            $totalProps = $props.Count
            $totalPages = [Math]::Ceiling($totalProps / $itemsPerPage)
            $currentPage = 0

            while ($true) {
                Clear-Host
                Write-Host "=== Advanced Properties for $AdapterName (Page $($currentPage + 1) of $totalPages) ===`n"

                # Get items for current page
                $startIndex = $currentPage * $itemsPerPage
                $pageProps = $props | Select-Object -Skip $startIndex -First $itemsPerPage
                $propNames = $pageProps | Select-Object -ExpandProperty DisplayName

                # Add navigation options
                $options = $propNames
                if ($totalPages -gt 1) {
                    if ($currentPage -gt 0) { $options += "Previous Page" }
                    if ($currentPage -lt ($totalPages - 1)) { $options += "Next Page" }
                }
                $options += "<< Back"

                $selection = Show-ArrowMenu -Title "Page $($currentPage + 1) of $totalPages" -Options $options

                # Handle navigation
                if ($selection -eq -1 -or $selection -eq $options.Count - 1) {
                    return
                }
                elseif ($selection -ge $propNames.Count) {
                    if ($options[$selection] -eq "Previous Page") {
                        $currentPage--
                        continue
                    }
                    elseif ($options[$selection] -eq "Next Page") {
                        $currentPage++
                        continue
                    }
                }
                else {
                    $selectedProp = $pageProps[$selection]
                    Show-PropertyEditor -AdapterName $AdapterName -Prop $selectedProp
                }
            }
        }
    }

    function Show-PropertyEditor {
        param (
            [string]$AdapterName,
            $Prop
        )

        while ($true) {
            $validValues = @()
            if ($Prop.PSObject.Properties.Name -contains 'ValidDisplayValue') {
                $validValues = $Prop.ValidDisplayValue
            } elseif ($Prop.PSObject.Properties.Name -contains 'ValidDisplayValues') {
                $validValues = $Prop.ValidDisplayValues
            }

            $selection = Show-ArrowMenu -Title "Modify Property: $($Prop.DisplayName)" -Options ($validValues + @("<< Back"))

            if ($selection -eq -1 -or $selection -eq $validValues.Length) {
                return
            }

            $newValue = $validValues[$selection]

            try {
                Set-NetAdapterAdvancedProperty -Name $AdapterName `
                    -DisplayName $Prop.DisplayName `
                    -DisplayValue $newValue -NoRestart
                Write-Host "`n Property updated successfully!" -ForegroundColor Green
            } catch {
                Write-Error " Failed to update property: $_" -ForegroundColor Red
            }

            Pause
            return
        }
    }

    Show-Adapters
}


function Reset-NetAdapter {
    <#
    .SYNOPSIS
        Resets the network adapter settings to default.
    .DESCRIPTION
        This function resets the network adapter settings to their default values.
    .EXAMPLE
        reset-NetAdapter
    #>
    Write-Host "Resetting network adapter settings to default..." -ForegroundColor Yellow
    Get-NetAdapter | ForEach-Object {
        Write-Host "Resetting adapter: $($_.Name)" -ForegroundColor Cyan
        Reset-NetAdapterAdvancedProperty -Name $_.Name -NoRestart
    }
    Write-Host "Network adapters have been reset to default settings." -ForegroundColor Green
    
}

function Add-VTSPrinter {
    # Initialize variables
    $SelectedPrinter = ""
    $SelectedPrintServer = ""

    function Show-SearchableMenu {
    param (
        [string]$Title,
        [array]$Options
    )
    $searchText = ""
    $currentIndex = 0
    $itemsPerPage = 10

    while ($true) {
        Clear-HostWithBanner
        Write-CenteredText "$Title`n" -Color Cyan
        Write-CenteredText "Search: $searchText" -Color Yellow
        Write-CenteredText "<- -> Arrow keys to change pages, Up/Down to select, Enter to confirm, ESC to cancel`n" -Color Gray
        
        # Filter options based on search text
        $filteredOptions = $Options | Where-Object { $_ -like "*$searchText*" }
        
        if ($filteredOptions.Count -eq 0) {
            Write-CenteredText "No matches found" -Color Red
            $currentIndex = 0
        }
        else {
            # Calculate current page and total pages
            $totalPages = [Math]::Ceiling($filteredOptions.Count / $itemsPerPage)
            $currentPage = [Math]::Floor($currentIndex / $itemsPerPage)
            $startIndex = $currentPage * $itemsPerPage
            
            # Display page information
            Write-CenteredText "Page $($currentPage + 1) of $totalPages`n" -Color Gray
            
            # Display filtered options for current page
            for ($i = $startIndex; $i -lt [Math]::Min($startIndex + $itemsPerPage, $filteredOptions.Count); $i++) {
                if ($i -eq $currentIndex) {
                    Write-CenteredText "-> $($filteredOptions[$i])" -Color Green
                }
                else {
                    Write-CenteredText "  $($filteredOptions[$i])" -Color White
                }
            }
        }
        

        # Handle key input
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                if ($currentIndex -gt 0) { $currentIndex-- }
            }
            40 { # Down arrow
                if ($currentIndex -lt ($filteredOptions.Count - 1)) { $currentIndex++ }
            }
            37 { # Left arrow - Previous page
                $newIndex = $currentIndex - $itemsPerPage
                if ($newIndex -ge 0) {
                    $currentIndex = $newIndex
                }
            }
            39 { # Right arrow - Next page
                $newIndex = $currentIndex + $itemsPerPage
                if ($newIndex -lt $filteredOptions.Count) {
                    $currentIndex = $newIndex
                }
            }
            13 { # Enter
                if ($filteredOptions.Count -gt 0) {
                    return $Options.IndexOf($filteredOptions[$currentIndex])
                }
            }
            27 { # Escape
                return -1
            }
            8 { # Backspace
                if ($searchText.Length -gt 0) {
                    $searchText = $searchText.Substring(0, $searchText.Length - 1)
                    $currentIndex = 0
                }
            }
            default {
                if ([char]::IsLetterOrDigit($key.Character) -or 
                    [char]::IsPunctuation($key.Character) -or 
                    [char]::IsWhiteSpace($key.Character)) {
                    $searchText += $key.Character
                    $currentIndex = 0
                }
            }
        }
    }
}

    function Get-PrinterSelection {
        $servers = @('CH-DC', 'CH-DC2', 'SWC-PS01')
        
        $serverSelection = Show-SearchableMenu -Title "Select Print Server" -Options $servers
        if ($serverSelection -eq -1) { return $null }
        
        $selectedServer = $servers[$serverSelection]
        Clear-HostWithBanner
        Write-Host "Getting printers from $selectedServer..." -ForegroundColor Cyan
        
        try {
            $printers = Get-Printer -ComputerName $selectedServer | 
                Select-Object -ExpandProperty Name |
                Sort-Object
            
            if ($printers.Count -eq 0) {
                Write-Host "No printers found on $selectedServer" -ForegroundColor Red
                Pause
                return $null
            }

            $printerSelection = Show-SearchableMenu -Title "Select Printer on $selectedServer" -Options $printers
            if ($printerSelection -eq -1) { return $null }
            
            return @{
                printer = $printers[$printerSelection]
                server = $selectedServer
            }
        }
        catch {
            Write-Host "Error accessing printers on $selectedServer : $_" -ForegroundColor Red
            Pause
            return $null
        }
    }

    # Main printer selection loop
    while ($SelectedPrinter -eq "") {
        Clear-HostWithBanner
        $printerResults = Get-PrinterSelection
        
        if ($null -eq $printerResults) { 
            Write-Host "Printer selection cancelled" -ForegroundColor Yellow
            return 
        }
        
        $SelectedPrinter = $printerResults.printer
        $SelectedPrintServer = $printerResults.server
        
        # Confirm selection
        Clear-HostWithBanner
        Write-Host "Selected Printer: $SelectedPrinter"
        Write-Host "Print Server: $SelectedPrintServer`n"
        
        $confirmation = Show-ArrowMenu -Title " $SelectedPrinter on $SelectedPrintServer Is this correct?" -Options @("Yes", "No")
        
        if ($confirmation -eq 0) {
            try {
                Write-Host "`nAdding printer..." -ForegroundColor Cyan
                Add-Printer -ConnectionName "\\$SelectedPrintServer\$SelectedPrinter" -ErrorAction Stop
                Clear-HostWithBanner
                Write-Host "`nPrinter $SelectedPrinter added successfully from $SelectedPrintServer" -ForegroundColor Green
                Pause
                return
            }
            catch {
                Write-Host "`nFailed to add printer: $_" -ForegroundColor Red
                Pause
                return
            }
        }
        else {
            $SelectedPrinter = ""
        }
    }
}

function Get-vtsMappedDrive {
  <#
  .Description
  Displays Mapped Drives information from the Windows Registry.
  .EXAMPLE
  PS> Get-vtsMappedDrive
  
  Output:
  Username            : VTS-ROBERTO\rober
  DriveLetter         : Y
  RemotePath          : https://live.sysinternals.com
  ConnectWithUsername : rober
  SID                 : S-1-5-21-376445358-2603134888-3166729622-1001
  
  .LINK
  Drive Management
  #>
  [CmdletBinding()]
  param ()

  # On most OSes, HKEY_USERS only contains users that are logged on.
  # There are ways to load the other profiles, but it can be problematic.
  $Drives = Get-ItemProperty "Registry::HKEY_USERS\*\Network\*" 2>$null

  # See if any drives were found
  if ( $Drives ) {

    ForEach ( $Drive in $Drives ) {

      # PSParentPath looks like this: Microsoft.PowerShell.Core\Registry::HKEY_USERS\S-1-5-21-##########-##########-##########-####\Network
      $SID = ($Drive.PSParentPath -split '\\')[2]

      [PSCustomObject]@{
        # Use .NET to look up the username from the SID
        Username            = ([System.Security.Principal.SecurityIdentifier]"$SID").Translate([System.Security.Principal.NTAccount])
        DriveLetter         = $Drive.PSChildName
        RemotePath          = $Drive.RemotePath

        # The username specified when you use "Connect using different credentials".
        # For some reason, this is frequently "0" when you don't use this option. I remove the "0" to keep the results consistent.
        ConnectWithUsername = $Drive.UserName -replace '^0$', $null
        SID                 = $SID
      }

    }

  }
  else {

    Write-Verbose "No mapped drives were found"

  }
}

function New-vtsMappedDrive {
  <#
  .DESCRIPTION
  Maps a remote drive. Prompts the user for drive letter and path if not provided.
  .EXAMPLE
  PS> New-vtsMappedDrive
  #>
  param(
    [string]$Letter,
    [string]$Path
  )

  if (-not $Letter) {
    $Letter = Read-Host "Enter drive letter (e.g., Z)"
  }
  if (-not $Path) {
    $Path = Read-Host "Enter network path (e.g., \\server\share)"
  }

  if (-not $Letter -or -not $Path) {
    Write-Host "Both drive letter and path are required." -ForegroundColor Red
    return
  }

  try {
    $drive = New-PSDrive -Name "$Letter" -PSProvider FileSystem -Root "$Path" -Persist -Scope Global -ErrorAction Stop
    Write-Host "Drive $Letter mapped to $Path successfully." -ForegroundColor Green
    return $drive
  }
  catch {
    Write-Host "Failed to map drive: $_" -ForegroundColor Red
  }
}



# This is how you would add a new menu option
#if we were adding a new menu option named script A3, it would look like this

#$HardwareOptions = @("See USB Attached devices", "Run Battery Health", "Run Script A3")
#$HardwareActions = @(
#    { Get-vtsUSB },
#    { Get-vtsBattery },
#    { Write-Host "Running Script A3..."; write-host "put your code here" }
#)


# to add a submenu, you would have to create a new menu and actions like this
#$SubMenuOptions = @("Submenu Option 1", "Submenu Option 2")
#$SubMenuActions = @(
#    { Write-Host "Submenu Option 1 selected" },
#    { Write-Host "Submenu Option 2 selected" }

# then you would add the submenu to the main menu like this
#$HardwareOptions = @("See USB Attached devices", "Run Battery Health", "Run Script A3")
#$HardwareActions = @(
#    { Get-vtsUSB },
#    { Get-vtsBattery },
#    { Show-Menu "SubMenu" $SubMenuOptions $SubMenuActions }




    
# Menu One - Hardware Options
$HardwareOptions = @("See USB Attached devices", "Run Battery Health", "Clear Disk Space", "(ADMIN)(REBOOT)check disk and fix errors")
$HardwareActions = @(
    { Get-vtsUSB },
    { Get-vtsBattery },
    { clear-Space },
    { chkdsk C: /f /r /x }
)



# Menu 2 - Software Options
$SoftwareOptions = @("(CH)Athena", "Adobe")
$SoftwareActions = @(
    
    { Show-Menu "Athena" $AthenaOptions $AthenaActions },
    { Show-Menu "Adobe" $AdobeOptions $AdobeActions }
)


# Menu 2a Athena Submenu
$AthenaOptions = @("(ADMIN)Reset ADM")
$AthenaActions = @(
    { Restart-Service athenaNetDeviceManager3.1 }
)

$adobeOptions = @("(ADMIN)Adobe Reader DC install")
$adobeActions = @(
    {choco install adobereader -y; Write-Host "Adobe Reader installed"; }
)  


# menu 3 - Network Options
$NetworkOptions = @("Get network info", "Speed Test", "(TESTING)(ADMIN)Change Network Adapters", "(ADMIN)Reset Network Adapters")
$NetworkActions = @(
    { Get-VTSInterfaces },
    { VTSSpeedtest },
    { Get-VTSNetAdapter },
    { Reset-NetAdapter }

)



# Menu Four - Windows OS Options
$OSOptions = @("(ADMIN) Update Windows", "(ADMIN)Fix corrupted files" , "(ADMIN)Clear Disk Space", "(TESTING)List Mapped Drives", "(TESTING)Add Mapped Drive")
$OSOptionsActions = @(
    { Get-VTSUpdates },
    { Dism /online /cleanup-image /restorehealth; sfc /scannow },
    { clear-Space },
    { Get-vtsMappedDrive },
    { New-vtsMappedDrive } 
)
# Menu 5 - Printer Options
$PrinterOptions = @("(USER)List Printers", "(CH)Remove old print server printers and FQDN printers", "(CH)Add Printer")
$PrinterActions = @(
    { Get-Printer },
    { PrinterRepair },
    { Add-VTSPrinter }
)

# === Main Menu Loop ===
while ($true) {
    $mainOptions = @("Hardware Tools", "Software Tools", "Network Tools", "Windows OS Tools", "Printer Tools", "Exit")
    $mainChoice = Show-ArrowMenu -Title "Main Menu" -Options $mainOptions

    switch ($mainChoice) {
        0 { Show-Menu "Hardware Options" $HardwareOptions $HardwareActions }
        1 { Show-Menu "Software Options" $SoftwareOptions $SoftwareActions }
        2 { Show-Menu "Network Options" $NetworkOptions $NetworkActions }
        3 { Show-Menu "Windows OS Options" $OSOptions $OSOptionsActions }
        4 { Show-Menu "Printer Options" $PrinterOptions $PrinterActions }
        5 { return }  
        -1 { return }
    }
}

