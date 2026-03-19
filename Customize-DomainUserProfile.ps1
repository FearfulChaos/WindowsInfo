#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Customizes a domain user's profile with specific Windows settings
.DESCRIPTION
    This script performs the following customizations:
    - Disables Fast Boot
    - Changes Windows theme to Dark mode
    - Installs PowerShell 7
    - Uninstalls Copilot
    - Disables Widgets
    - Hides Search bar and Task View
    - Removes Lock Screen clutter
    - Sets screen timeout to Never
    - Sets custom wallpaper for desktop and lock screen
.PARAMETER WallpaperPath
    Path or URL to the wallpaper image file to use for both desktop and lock screen
.NOTES
    Requires Administrator privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$WallpaperPath = "https://images.pexels.com/photos/1166209/pexels-photo-1166209.jpeg"
)

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [System.ConsoleColor]$Color = [System.ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-Status "Starting domain user profile customization..." "Green"
Write-Status "========================================"

# Helper: Install a list of apps via Winget (fallback to Chocolately)
function Install-Applications {
	param(
		[string[]]$AppList #e.g. @("Vivaldi", "Notion", "Notepad++")
		)
		
		# Detect package manager availability
		$hasWinget = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
		$hasChoco  = (Get-Command choco -ErrorAction SilentlyContinue) -ne $null
		
		if (-not $hasWinget -and -not $hasChoco) {
			Write-Status "Neither Winget nor Chocolately is installed. Installing Chocolately..." "Yellow"
			Set-ExecutionPolicy Bypass -Scope Process -Force
			$chocoInstallScript = 'Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString("https://community.chocolately.org/install.ps1"))'
			try { Invoke-Expression $chocoInstallScript } catch { Write-Status "Failed to install Chocolately: $_" "Red" }
			$hasChoco = (Get-Command choco -ErrorAction SilentlyContinue) -ne $null
		}
		
		foreach ($app in $AppList) {
			Write-Status "`nInstalling $app..." "DarkBlue"
			
			if ($hasWinget) {
				# Winget IDs are case-insensitive; we let winget resolve the best match
				try {
					winget install --id $app --source winget --silent --accept-package-agreements --accept-source-agreements `
						-e 2>$null | Out-Null
						Write-Status " $app installed via Winget" "Green"
						continue
				} catch {
					Write-Status "Winget could not install $app (maybe unknown ID). Trying Chocolately..." "Yellow"
				}
			}
			
			if ($hasChoco) {
				try {
					choco install $app -y --no-progress | Out-Null
					Write-Status " $app installed via Chocolately" "Green"
				} catch {
					Write-Status " Failed to install $app with Chocolately: $_" "Red"
				}
			}else {
				Write-Status " No package manager available to install $app." "Red"
			}
		}
}
# Download or validate wallpaper
if ($WallpaperPath) {
    if ($WallpaperPath -match '^https?://') {
        Write-Status "Downloading wallpaper from URL..." "Cyan"
        try {
            $wallpaperExt = [System.IO.Path]::GetExtension($WallpaperPath)
            if ([string]::IsNullOrEmpty($wallpaperExt)) { $wallpaperExt = ".jpg" }
            $localWallpaperPath = Join-Path $env:TEMP "CustomWallpaper$wallpaperExt"
            Invoke-WebRequest -Uri $WallpaperPath -OutFile $localWallpaperPath -UseBasicParsing
            $WallpaperPath = $localWallpaperPath
            Write-Status "✓ Wallpaper downloaded successfully" "Green"
        } catch {
            Write-Status "✗ Failed to download wallpaper: $_" "Red"
            $WallpaperPath = ""
        }
    } elseif (!(Test-Path $WallpaperPath)) {
        Write-Status "Warning: Wallpaper file not found at: $WallpaperPath" "Yellow"
        $WallpaperPath = ""
    }
}

# 1. Disable Fast Boot
Write-Status "`n[1/9] Disabling Fast Boot..."
try {
    $fastBootPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $fastBootPath -Name "HiberbootEnabled" -Value 0 -ErrorAction Stop
    Write-Status "✓ Fast Boot disabled" "Green"
} catch {
    Write-Status "✗ Failed to disable Fast Boot: $_" "Red"
}

# 2. Change Windows theme to Dark mode
Write-Status "`n[2/9] Setting Dark Mode..."
try {
    # Set app mode to dark
    $themePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (!(Test-Path $themePath)) {
        New-Item -Path $themePath -Force | Out-Null
    }
    Set-ItemProperty -Path $themePath -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $themePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force
    
    # Set color prevalence for dark mode
    Set-ItemProperty -Path $themePath -Name "ColorPrevalence" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Write-Status "✓ Dark Mode enabled" "Green"
} catch {
    Write-Status "✗ Failed to enable Dark Mode: $_" "Red"
}

# 3. Install Chocolately (if needed) and PowerShell 7
Write-Status "`n[3/9] Installing PowerShell 7..."
try {
    if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Status "Downloading and installing PowerShell 7..."
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        Write-Status "✓ PowerShell 7 installed" "Green"
    } else {
        Write-Status "✓ PowerShell 7 already installed" "Green"
    }
} catch {
    Write-Status "✗ Failed to install PowerShell 7: $_" "Red"
}

# 4. Uninstall Copilot
Write-Status "`n[4/9] Uninstalling Copilot..."
try {
    # Disable Copilot via registry
    $copilotPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $copilotPath)) {
        New-Item -Path $copilotPath -Force | Out-Null
    }
    Set-ItemProperty -Path $copilotPath -Name "TurnOffWindowsCopilot" -Value 1 -ErrorAction Stop
    
    # Try to remove Copilot app package if present
    Get-AppxPackage -Name "*Copilot*" -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
    Write-Status "✓ Copilot disabled and uninstalled" "Green"
} catch {
    Write-Status "✗ Failed to uninstall Copilot: $_" "Red"
}

# 5. Hide Search bar and Task View
Write-Status "`n[5/9] Hiding Search bar and Task View..."
try {
    $taskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    
    # Hide Search bar (0 = hidden, 1 = show icon, 2 = show box)
    Set-ItemProperty -Path $taskbarPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force
    
    # Hide Task View button
    Set-ItemProperty -Path $taskbarPath -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force
    
    # Windows 11 specific search settings
    $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $searchPath)) {
        New-Item -Path $searchPath -Force | Out-Null
    }
    Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Write-Status "✓ Search bar and Task View hidden" "Green"
} catch {
    Write-Status "✗ Failed to hide Search bar/Task View: $_" "Red"
}

# 6. Remove Lock Screen clutter (tips, weather, Spotlight)
Write-Status "`n[6/9] Removing Lock Screen clutter..."
try {
    # Disable Windows Spotlight on lock screen
    $cloudContentPath = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"
    if (!(Test-Path $cloudContentPath)) {
        New-Item -Path $cloudContentPath -Force | Out-Null
    }
    Set-ItemProperty -Path $cloudContentPath -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $cloudContentPath -Name "ConfigureWindowsSpotlight" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cloudContentPath -Name "IncludeEnterpriseSpotlight" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    # Disable tips, tricks, and suggestions on lock screen
    $contentDeliveryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty -Path $contentDeliveryPath -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDeliveryPath -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDeliveryPath -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDeliveryPath -Name "SubscribedContent-338393Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDeliveryPath -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord -Force
    
    # Disable lock screen fun facts, tips, tricks
    Set-ItemProperty -Path $contentDeliveryPath -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force
    
    # Set lock screen to picture (not slideshow or Spotlight)
    $lockScreenPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen"
    if (!(Test-Path $lockScreenPath)) {
        New-Item -Path $lockScreenPath -Force | Out-Null
    }
    Set-ItemProperty -Path $lockScreenPath -Name "SlideshowEnabled" -Value 0 -Type DWord -Force
    
    Write-Status "✓ Lock Screen clutter removed" "Green"
} catch {
    Write-Status "✗ Failed to remove Lock Screen clutter: $_" "Red"
}

# 7. Set screen timeout to Never
Write-Status "`n[7/9] Setting screen timeout to Never..."
try {
    # Set AC (plugged in) screen timeout to 0 (never)
    powercfg /change monitor-timeout-ac 0
    # Set DC (battery) screen timeout to 0 (never)
    powercfg /change monitor-timeout-dc 0
    Write-Status "✓ Screen timeout set to Never" "Green"
} catch {
    Write-Status "✗ Failed to set screen timeout: $_" "Red"
}

# 8. Set custom wallpaper for desktop and lock screen
if ($WallpaperPath) {
    Write-Status "`n[8/9] Setting custom wallpaper..."
    try {
        # Convert to absolute path
        $WallpaperPath = (Resolve-Path $WallpaperPath).Path
        
        # Set desktop wallpaper using SystemParametersInfo
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@
        $SPI_SETDESKWALLPAPER = 0x0014
        $SPIF_UPDATEINIFILE = 0x01
        $SPIF_SENDCHANGE = 0x02
        [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $WallpaperPath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE) | Out-Null
        
        # Set lock screen wallpaper
        $lockScreenImagePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        if (!(Test-Path $lockScreenImagePath)) {
            New-Item -Path $lockScreenImagePath -Force | Out-Null
        }
        Set-ItemProperty -Path $lockScreenImagePath -Name "LockScreenImage" -Value $WallpaperPath -ErrorAction Stop
        
        # Also set for current user
        $userLockScreen = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen\Creative"
        if (!(Test-Path $userLockScreen)) {
            New-Item -Path $userLockScreen -Force | Out-Null
        }
        Set-ItemProperty -Path $userLockScreen -Name "LockImagePath" -Value $WallpaperPath -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $userLockScreen -Name "LockImageFlags" -Value 1 -ErrorAction SilentlyContinue
        
        Write-Status "✓ Wallpaper set for desktop and lock screen" "Green"
    } catch {
        Write-Status "✗ Failed to set wallpaper: $_" "Red"
    }
} else {
    Write-Status "`n[9/9] Skipping wallpaper (no path provided)" "Yellow"
}

# 9. Install requested applications
Write-Status "`n[9/9] Installing common productivity applications..."
$appsToInstall = @(
	"Vivaldi",
	"Librewolf",
	"Notion",
	"Notepad++",
	"Glasswire",
	"Tailscale",
	"OpenVPN Connect",
	"Logseq",
	"VLC"
)
Install-Applications -AppList $appsToInstall

# Restart Explorer to apply taskbar changes
Write-Status "`n========================================"
Write-Status "Restarting Windows Explorer to apply changes..."
try {
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 2
    Write-Status "✓ Explorer restarted" "Green"
} catch {
    Write-Status "✗ Failed to restart Explorer: $_" "Red"
}

Write-Status "`n========================================"
Write-Status "Profile customization complete!" "Green"
Write-Status "Some changes may require a system restart to take full effect." "Yellow"
Write-Host ""
Read-Host "Press Enter to exit"
