function Show-ArrowMenu {
    param (
        [string]$Title,
        [string[]]$Options
    )

    $index = 0
    while ($true) {
        Clear-Host
        Write-Host "=== $Title ===`n"

        for ($i = 0; $i -lt $Options.Length; $i++) {
            if ($i -eq $index) {
                Write-Host "> $($Options[$i])" -ForegroundColor Cyan
            } else {
                Write-Host "  $($Options[$i])"
            }
        }

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
    Write-Host "`nPress any key to continue..."
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

        Clear-Host
        & $Actions[$selection]
        Pause
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
    Write-Host "`n"
}

function Get-vtsUSB {
# This script checks for USB devices connected to the system and colors output by status
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
        Start-Process powershell.exe -Verb runAs -ArgumentList $arguments
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
        exit
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
        exit
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


    
# Menu One - Hardware Options
$HardwareOptions = @("See USB Attached devices", "Run Battery Health", "Run Script A3")
$HardwareActions = @(
    { Get-vtsUSB },
    { Get-vtsBattery },
    { Write-Host "Running Script A3..."; write-host "put your code here" }
)



# Menu 2 - Software Options
$SoftwareOptions = @("Run Script B1", "Run Script B2", "Run Script B3", "Athena")
$SoftwareActions = @(
    { Write-Host "Running Script B1..."; write-host "put your code here" },
    { Write-Host "Running Script B2..."; write-host "put your code here" },
    { Write-Host "Running Script B3..."; write-host "put your code here" },
    { Show-Menu "Athena" $AthenaOptions $AthenaActions }
)

# Menu 2a Athena Submenu
$AthenaOptions = @("Submenu Option 1", "Submenu Option 2")
$AthenaActions = @(
    { Write-Host "Submenu Option 1 selected" },
    { Write-Host "Submenu Option 2 selected" }


# menu 3 - Network Options
$NetworkOptions = @("Get network info", "Run Script C2", "Run Script C3")
$NetworkActions = @(
    { Get-VTSInterfaces },
    { Write-Host "Running Script C2..."; write-host "put your code here" },
    { Write-Host "Running Script C3..."; write-host "put your code here" }
)



)

# Menu Four - Windows OS Options
$OSOptions = @("(TESTING)(ADMIN) Update Windows", "Show System Info")
$OSOptionsActions = @(
    { get-vtsupdates },
    { Write-Host "OS Version:"; [System.Environment]::OSVersion.Version.ToString() },
    { Write-Host "System Info:"; systeminfo | more }
)

# === Main Menu Loop ===
while ($true) {
    $mainOptions = @("Hardware Tests", "Software Tests", "Network tests", "Windows OS Options", "Exit")
    $mainChoice = Show-ArrowMenu -Title "Main Menu" -Options $mainOptions

    switch ($mainChoice) {
        0 { Show-Menu "Hardware Options" $HardwareOptions $HardwareActions }
        1 { Show-Menu "Software Options" $SoftwareOptions $SoftwareActions }
        2 { Show-Menu "Network Options" $NetworkOptions $NetworkActions }
        3 { Show-Menu "Windows OS Options" $OSOptions $OSOptionsActions }
        4 { return }  # Exit the script
        -1 { return } # Escape key also exits
    }
}
