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

function Run-Menu {
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

function interfaceConfig {
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
write-host "`n"
Write-Host "WIFI Connected: $wifiConnected"
Write-Host "Ethernet Connected: $ethConnected"
Write-Host ""

if ($wifiConnected) {
    write-host "`n"
    Write-Host "WIFI IP: $wifiIP"
    Write-Host "WIFI DNS: $($wifi.DnsServer.ServerAddresses -join ', ')"
    Write-Host "WIFI Default Gateway: $($wifi.IPv4DefaultGateway.NextHop)"
    Write-Host ""
}

if ($ethConnected) {
    write-host "`n"
    Write-Host "ETH IP: $ethIP"
    Write-Host "ETH DNS: $($eth.DnsServer.ServerAddresses -join ', ')"
    Write-Host "ETH Default Gateway: $($eth.IPv4DefaultGateway.NextHop)"
}
write-host "`n"

}

function Get-vtsUSB {
# This script checks for USB devices connected to the system
  get-pnpdevice -friendlyName * |
  Where-Object { $_.InstanceId -like "*usb*" } |
  Select-Object FriendlyName, Present, Status |
  Sort-Object Present -Descending | 
  Out-Host


}



# === Define Actual Submenu Options and Actions ===

# Menu One
$Menu1Options = @("See USB Attached devices", "Run Script A2", "Run Script A3")
$Menu1Actions = @(
    { Get-vtsUSB ;},
    { Write-Host "Running Script A2..."; write-host "put your code here" },
    { Write-Host "Running Script A3..."; write-host "put your code here" }
)

# Menu Two
$Menu2Options = @("Run Script B1", "Run Script B2", "Run Script B3")
$Menu2Actions = @(
    #
    { Write-Host "Running Script B1..."; write-host "put your code here" },
    { Write-Host "Running Script B2..."; write-host "put your code here" },
    { Write-Host "Running Script B3..."; write-host "put your code here" }
)

# Menu Three
$Menu3Options = @("Get network info", "Run Script C2", "Run Script C3")
$Menu3Actions = @(
    { Write-Host "Get Network Info"; interfaceConfig },
    { Write-Host "Running Script C2..."; write-host "put your code here" },
    { Write-Host "Running Script C3..."; write-host "put your code here" }
)

# === Main Menu Loop ===
while ($true) {
    $mainOptions = @("Hardware Tests", "Software Tests", "Network tests", "Exit")
    $mainChoice = Show-ArrowMenu -Title "Main Menu" -Options $mainOptions

    switch ($mainChoice) {
        0 { Run-Menu "Hardware Options" $Menu1Options $Menu1Actions }
        1 { Run-Menu "Software Options" $Menu2Options $Menu2Actions }
        2 { Run-Menu "Network Options" $Menu3Options $Menu3Actions }
        3 { return }  # Exit the script
        -1 { return } # Escape key also exits
    }
}
