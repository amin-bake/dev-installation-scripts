<#
.SYNOPSIS
    Complete Windows Development Environment Setup Script
.DESCRIPTION
    This script installs and configures a complete development environment including:
    - Browsers (Chrome, Brave)
    - Development Tools (Git, Node.js, Python, Docker, etc.)
    - IDEs (VS Code, Android Studio, Visual Studio)
    - Utilities (WinRAR, AnyDesk, Zoom, etc.)
.PARAMETER SkipSystemChecks
    Skip system requirement checks
.PARAMETER SkipDevTools
    Skip development tools configuration
.PARAMETER SkipIDEs
    Skip IDE installations
.PARAMETER ForceReinstall
    Force reinstall of existing applications
#>

param(
    [switch]$SkipSystemChecks = $false,
    [switch]$SkipDevTools = $false,
    [switch]$SkipIDEs = $false,
    [switch]$ForceReinstall = $false
)

# Configuration
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

# CORRECTED OUTPUT FUNCTIONS - Fixed scope issues
function Write-Success { 
    param($msg) 
    Write-Host "✓ $msg" -ForegroundColor Green
}
function Write-Error { 
    param($msg) 
    Write-Host "✗ $msg" -ForegroundColor Red
}
function Write-Info { 
    param($msg) 
    Write-Host "ℹ $msg" -ForegroundColor Cyan
}
function Write-Warning { 
    param($msg) 
    Write-Host "⚠ $msg" -ForegroundColor Yellow
}
function Write-Status { 
    param($msg) 
    Write-Host "• $msg" -ForegroundColor Gray
}

# Check if running as Administrator
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'"
    exit 1
}

# System Requirements Check
function Test-SystemRequirements {
    Write-Info "Checking system requirements..."
    
    # Check Windows version
    $os = Get-WmiObject -Class Win32_OperatingSystem
    if ([System.Environment]::OSVersion.Version.Major -lt 10) {
        Write-Error "Windows 10 or later is required"
        return $false
    }
    
    # Check available disk space
    $drive = Get-PSDrive C
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    Write-Info "Available disk space: $freeSpaceGB GB"
    if ($freeSpaceGB -lt 20) {
        Write-Warning "Low disk space: $freeSpaceGB GB free (recommended: 20+ GB)"
    }
    
    # Check RAM
    $memory = Get-WmiObject -Class Win32_ComputerSystem
    $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
    Write-Info "Total RAM: $totalMemoryGB GB"
    if ($totalMemoryGB -lt 8) {
        Write-Warning "Low memory: $totalMemoryGB GB (recommended: 8+ GB for development)"
    }
    
    Write-Success "System requirements check passed"
    return $true
}

# Install WinGet
function Install-WinGet {
    Write-Info "Checking for Windows Package Manager (winget)..."
    
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Success "Windows Package Manager (winget) is available."
        return $true
    }
    
    Write-Warning "WinGet is not installed or not in PATH."
    Write-Info "You can manually install WinGet from Microsoft Store or visit: https://aka.ms/getwinget"
    return $false
}

# Install Chocolatey
function Install-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Success "Chocolatey already installed"
        return $true
    }
    
    Write-Info "Installing Chocolatey package manager..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Wait for installation to complete
        Start-Sleep -Seconds 10
        
        # Refresh environment to recognize choco command
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Success "Chocolatey installed successfully"
            return $true
        } else {
            Write-Error "Chocolatey installed but not recognized. You may need to restart PowerShell."
            return $false
        }
    }
    catch {
        Write-Error "Failed to install Chocolatey: $($_.Exception.Message)"
        return $false
    }
}

# Application Definitions with direct download URLs
$Applications = @{
    # Browsers
    "Google Chrome" = @{
        WingetId = "Google.Chrome"
        ChocolateyId = "googlechrome"
        DirectDownload = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
        TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue")
    }
    "Brave Browser" = @{
        WingetId = "Brave.Brave"
        ChocolateyId = "brave"
        DirectDownload = "https://referrals.brave.com/latest/BraveBrowserSetup.exe"
        TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\BraveSoftware\Update\ClientState\{C1033C00-81A4-4FB3-9143-2D2B95D2E13A}' -Name pv -ErrorAction SilentlyContinue")
    }
    
    # Development Tools
    "Git" = @{
        WingetId = "Git.Git"
        ChocolateyId = "git"
        DirectDownload = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.47.1-64-bit.exe"
        TestCommands = @("git --version 2>&1")
    }
    "Node.js LTS" = @{
        WingetId = "OpenJS.NodeJS.LTS"
        ChocolateyId = "nodejs-lts"
        DirectDownload = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
        TestCommands = @("node --version 2>&1")
    }
    "Python" = @{
        WingetId = "Python.Python.3.12"
        ChocolateyId = "python"
        DirectDownload = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
        TestCommands = @("python --version 2>&1", "python3 --version 2>&1")
    }
    "VS Code" = @{
        WingetId = "Microsoft.VisualStudioCode"
        ChocolateyId = "vscode"
        DirectDownload = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
        TestCommands = @("code --version 2>&1")
    }
    "Docker Desktop" = @{
        WingetId = "Docker.DockerDesktop"
        ChocolateyId = "docker-desktop"
        DirectDownload = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        TestCommands = @("docker --version 2>&1")
    }
    "Postman" = @{
        WingetId = "Postman.Postman"
        ChocolateyId = "postman"
        DirectDownload = "https://dl.pstmn.io/download/latest/win64"
        TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\Postman\Postman' -Name Version -ErrorAction SilentlyContinue")
    }
    
    # Utilities
    "WinRAR" = @{
        WingetId = "RARLab.WinRAR"
        ChocolateyId = "winrar"
        DirectDownload = "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-701.exe"
        TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\WinRAR' -Name version -ErrorAction SilentlyContinue")
    }
    "AnyDesk" = @{
        WingetId = "AnyDeskSoftwareGmbH.AnyDesk"
        ChocolateyId = "anydesk"
        DirectDownload = "https://download.anydesk.com/AnyDesk.exe"
    }
    "Zoom" = @{
        WingetId = "Zoom.Zoom"
        ChocolateyId = "zoom"
        DirectDownload = "https://zoom.us/client/latest/ZoomInstaller.exe"
    }
    
    # Development Environments
    "Visual Studio 2022 Professional" = @{
        WingetId = "Microsoft.VisualStudio.2022.Professional"
        ChocolateyId = "visualstudio2022professional"
    }
    "Android Studio" = @{
        WingetId = "Google.AndroidStudio"
        ChocolateyId = "androidstudio"
        DirectDownload = "https://redirector.gvt1.com/edgedl/android/studio/install/2025.1.1.12/android-studio-2025.1.1.12-windows.exe"
        AlternativeDownload = "https://dl.google.com/dl/android/studio/install/2025.1.1.12/android-studio-2025.1.1.12-windows.exe"
    }
    "PowerShell 7" = @{
        WingetId = "Microsoft.PowerShell"
        ChocolateyId = "powershell"
        DirectDownload = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.3/PowerShell-7.4.3-win-x64.msi"
        TestCommands = @("pwsh --version 2>&1")
    }
}

# Check if application is installed
function Test-AppInstalled {
    param([string]$AppName, [hashtable]$AppConfig)
    
    # Check via test commands first
    if ($AppConfig.TestCommands) {
        foreach ($testCommand in $AppConfig.TestCommands) {
            try {
                $result = Invoke-Expression $testCommand 2>$null
                if ($result -and $result -notmatch "not recognized") {
                    return $true
                }
            }
            catch {
                # Continue to next test command
            }
        }
    }
    
    # Check via registry
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        $installed = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                    Where-Object { $_.DisplayName -like "*$AppName*" }
        if ($installed) {
            return $true
        }
    }
    
    return $false
}

# Install application using WinGet
function Install-WithWinGet {
    param([string]$AppName, [string]$WinGetId)
    
    try {
        Write-Status "Installing via WinGet: $WinGetId"
        $process = Start-Process -FilePath "winget" -ArgumentList "install --id $WinGetId --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Success "Successfully installed $AppName via WinGet"
            return $true
        } else {
            Write-Warning "WinGet installation failed for $AppName with exit code: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-Warning "WinGet installation failed for $AppName : $($_.Exception.Message)"
        return $false
    }
}

# Install application using Chocolatey
function Install-WithChocolatey {
    param([string]$AppName, [string]$ChocolateyId)
    
    try {
        Write-Status "Installing via Chocolatey: $ChocolateyId"
        $process = Start-Process -FilePath "choco" -ArgumentList "install $ChocolateyId -y --no-progress" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Success "Successfully installed $AppName via Chocolatey"
            return $true
        } else {
            Write-Warning "Chocolatey installation failed for $AppName with exit code: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-Warning "Chocolatey installation failed for $AppName : $($_.Exception.Message)"
        return $false
    }
}

# Enhanced Android Studio installation with multiple fallbacks
function Install-AndroidStudio-Enhanced {
    Write-Info "Installing Android Studio with enhanced fallback methods..."
    
    $tempFile = "$env:TEMP\android-studio-installer.exe"
    $success = $false
    
    # Method 1: Try official download with multiple URLs
    $downloadUrls = @(
        "https://redirector.gvt1.com/edgedl/android/studio/install/2025.1.1.12/android-studio-2025.1.1.12-windows.exe",
        "https://dl.google.com/dl/android/studio/install/2025.1.1.12/android-studio-2025.1.1.12-windows.exe",
        "https://developer.android.com/studio"
    )
    
    foreach ($url in $downloadUrls) {
        try {
            Write-Info "Attempting download from: $url"
            
            if ($url -eq "https://developer.android.com/studio") {
                # For the website, we can't directly download, so provide instructions
                Write-Warning "Cannot auto-download from developer.android.com"
                Write-Info "Please download Android Studio manually from: https://developer.android.com/studio"
                return $false
            }
            
            # Download with timeout and retry
            $maxRetries = 2
            for ($i = 0; $i -lt $maxRetries; $i++) {
                try {
                    Invoke-WebRequest -Uri $url -OutFile $tempFile -TimeoutSec 60
                    
                    if (Test-Path $tempFile -and (Get-Item $tempFile).Length -gt 0) {
                        Write-Success "Download completed successfully"
                        break
                    }
                }
                catch {
                    Write-Warning "Download attempt $($i + 1) failed: $($_.Exception.Message)"
                    if ($i -eq ($maxRetries - 1)) {
                        throw
                    }
                    Start-Sleep -Seconds 5
                }
            }
            
            # Install the downloaded file
            Write-Status "Installing Android Studio..."
            $process = Start-Process -FilePath $tempFile -ArgumentList "/S" -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Success "Android Studio installed successfully via direct download"
                $success = $true
                break
            } else {
                Write-Warning "Installation failed with exit code: $($process.ExitCode)"
            }
        }
        catch {
            Write-Warning "Failed to download from $url : $($_.Exception.Message)"
            continue
        }
        finally {
            # Clean up
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    if (-not $success) {
        Write-Error "All Android Studio installation methods failed"
        Write-Info "Please install Android Studio manually from: https://developer.android.com/studio"
    }
    
    return $success
}

# Direct download and install function for problematic applications
function Install-WithDirectDownload {
    param([string]$AppName, [hashtable]$AppConfig)
    
    if (-not $AppConfig.DirectDownload) {
        Write-Error "No direct download URL available for $AppName"
        return $false
    }
    
    try {
        Write-Info "Attempting direct download for $AppName..."
        $tempFile = "$env:TEMP\$AppName-installer.exe"
        
        # Try primary download URL
        try {
            Write-Status "Downloading from: $($AppConfig.DirectDownload)"
            Invoke-WebRequest -Uri $AppConfig.DirectDownload -OutFile $tempFile -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        catch {
            # Try alternative URL if available
            if ($AppConfig.AlternativeDownload) {
                Write-Warning "Primary download failed, trying alternative URL..."
                Write-Status "Downloading from: $($AppConfig.AlternativeDownload)"
                Invoke-WebRequest -Uri $AppConfig.AlternativeDownload -OutFile $tempFile -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            } else {
                throw
            }
        }
        
        Write-Status "Running installer..."
        $process = Start-Process -FilePath $tempFile -ArgumentList "/S" -Wait -PassThru -NoNewWindow
        
        # Clean up
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Success "Successfully installed $AppName via direct download"
            return $true
        } else {
            Write-Warning "Direct installation failed for $AppName with exit code: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-Error "Direct download failed for $AppName : $($_.Exception.Message)"
        return $false
    }
}

# Main installation function with enhanced Android Studio handling
function Install-Application {
    param([string]$AppName, [hashtable]$AppConfig)
    
    $isInstalled = Test-AppInstalled -AppName $AppName -AppConfig $AppConfig
    
    if ($isInstalled -and -not $ForceReinstall) {
        Write-Success "$AppName is already installed"
        return $true
    }
    
    if ($isInstalled -and $ForceReinstall) {
        Write-Info "Reinstalling $AppName..."
    } else {
        Write-Info "Installing $AppName..."
    }
    
    # Special handling for Android Studio
    if ($AppName -eq "Android Studio") {
        return Install-AndroidStudio-Enhanced
    }
    
    # Try WinGet first if available
    if ($AppConfig.WingetId -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        if (Install-WithWinGet -AppName $AppName -WinGetId $AppConfig.WingetId) {
            return $true
        }
    }
    
    # Try Chocolatey
    if ($AppConfig.ChocolateyId) {
        if (Install-WithChocolatey -AppName $AppName -ChocolateyId $AppConfig.ChocolateyId) {
            return $true
        }
    }
    
    # Fallback to direct download
    if ($AppConfig.DirectDownload) {
        Write-Warning "Package manager installation failed, trying direct download..."
        if (Install-WithDirectDownload -AppName $AppName -AppConfig $AppConfig) {
            return $true
        }
    }
    
    Write-Error "All installation methods failed for $AppName"
    Write-Info "You may need to install $AppName manually from the official website"
    return $false
}

# Configure Development Environment
function Configure-DevelopmentEnvironment {
    Write-Info "Configuring development environment..."
    
    # Add to PATH
    $paths = @(
        "$env:USERPROFILE\AppData\Local\Programs\Python\Python312\Scripts",
        "$env:ProgramFiles\Git\cmd",
        "$env:ProgramFiles\nodejs"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            if ($currentPath -notlike "*$path*") {
                [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$path", "User")
                Write-Success "Added $path to user PATH"
            }
        }
    }
    
    # Configure Git
    try {
        git config --global user.name "Developer"
        git config --global user.email "developer@example.com"
        git config --global core.autocrlf true
        git config --global core.safecrlf warn
        Write-Success "Configured Git global settings"
        Write-Info "Remember to update git user name and email with your actual details"
    }
    catch {
        Write-Warning "Failed to configure Git: $($_.Exception.Message)"
    }
    
    # Install VS Code extensions
    $vscodeExtensions = @(
        "ms-vscode.powershell",
        "ms-dotnettools.csharp",
        "ms-python.python",
        "bradlc.vscode-tailwindcss",
        "esbenp.prettier-vscode",
        "ms-vscode.vscode-typescript-next"
    )
    
    foreach ($extension in $vscodeExtensions) {
        try {
            if (Get-Command code -ErrorAction SilentlyContinue) {
                code --install-extension $extension --force
                Write-Success "Installed VS Code extension: $extension"
            }
        }
        catch {
            Write-Warning "Failed to install VS Code extension $extension : $($_.Exception.Message)"
        }
    }
}

# Configure Docker
function Configure-Docker {
    Write-Info "Configuring Docker..."
    
    try {
        # Start Docker service
        Start-Service "Docker Desktop Service" -ErrorAction SilentlyContinue
        
        # Enable Docker to start automatically
        Set-Service -Name "Docker Desktop Service" -StartupType Automatic -ErrorAction SilentlyContinue
        
        Write-Success "Docker configured successfully"
        Write-Info "You may need to start Docker Desktop manually for initial setup"
    }
    catch {
        Write-Warning "Docker configuration may require manual setup: $($_.Exception.Message)"
    }
}

# System Optimization
function Optimize-System {
    Write-Info "Setting up development environment..."
    
    # Create development folder structure
    $devFolders = @("Projects", "Scripts", "Temp", "Backups")
    foreach ($folder in $devFolders) {
        $path = "$env:USERPROFILE\$folder"
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Success "Created directory: $path"
        }
    }
    
    # Set execution policy for scripts
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Success "Set execution policy to RemoteSigned"
    }
    catch {
        Write-Warning "Could not set execution policy: $($_.Exception.Message)"
    }
}

# Main Installation Process
function Start-Installation {
    Write-Host "==========================================" -ForegroundColor Magenta
    Write-Host "   DEVELOPMENT ENVIRONMENT SETUP" -ForegroundColor Magenta
    Write-Host "==========================================" -ForegroundColor Magenta
    
    # System checks
    if (-not $SkipSystemChecks) {
        if (-not (Test-SystemRequirements)) {
            Write-Error "System requirements check failed"
            return
        }
    }
    
    # Install package managers
    Write-Info "Setting up package managers..."
    $wingetAvailable = Install-WinGet
    $chocolateyAvailable = Install-Chocolatey
    
    if (-not $chocolateyAvailable) {
        Write-Error "Chocolatey installation failed. Cannot continue."
        return
    }
    
    # Install applications
    Write-Info "Installing applications..."
    $successCount = 0
    $totalCount = $Applications.Count
    
    foreach ($appName in $Applications.Keys) {
        Write-Host "`nProcessing: $appName" -ForegroundColor White
        Write-Host "----------------------------------------" -ForegroundColor Gray
        
        if (Install-Application -AppName $appName -AppConfig $Applications[$appName]) {
            $successCount++
        }
    }
    
    # Configuration
    if (-not $SkipDevTools) {
        Configure-DevelopmentEnvironment
    }
    
    Configure-Docker
    Optimize-System
    
    # Summary
    Write-Host "`n==========================================" -ForegroundColor Magenta
    Write-Host "INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host "Applications processed: $successCount/$totalCount" -ForegroundColor White
    
    if ($successCount -eq $totalCount) {
        Write-Success "All applications installed successfully!"
    } else {
        Write-Warning "$($totalCount - $successCount) applications may need manual installation"
    }
    
    # Manual installation instructions for failed applications
    if ($successCount -lt $totalCount) {
        Write-Host "`nMANUAL INSTALLATION INSTRUCTIONS:" -ForegroundColor Yellow
        foreach ($appName in $Applications.Keys) {
            $isInstalled = Test-AppInstalled -AppName $appName -AppConfig $Applications[$appName]
            if (-not $isInstalled) {
                Write-Host "• $($appName):" -ForegroundColor Red
                if ($appName -eq "Android Studio") {
                    Write-Host "  Download from: https://developer.android.com/studio" -ForegroundColor White
                } elseif ($Applications[$appName].DirectDownload) {
                    Write-Host "  Download from: $($Applications[$appName].DirectDownload)" -ForegroundColor White
                }
            }
        }
    }
    
    Write-Host "`nNEXT STEPS:" -ForegroundColor Green
    Write-Host "1. Restart your computer" -ForegroundColor Yellow
    Write-Host "2. Configure Docker Desktop" -ForegroundColor Yellow
    Write-Host "3. Update Git user name and email: git config --global user.name 'Your Name'" -ForegroundColor Yellow
    Write-Host "4. Launch Android Studio to complete setup" -ForegroundColor Yellow
}

# Display usage information
Write-Host "Windows Development Environment Installer" -ForegroundColor Green
Write-Host "Usage: powershell -ExecutionPolicy Bypass -File script.ps1 [parameters]" -ForegroundColor Gray
Write-Host "Parameters:" -ForegroundColor Gray
Write-Host "  -SkipSystemChecks   Skip system requirement checks" -ForegroundColor Gray
Write-Host "  -SkipDevTools       Skip development tools configuration" -ForegroundColor Gray
Write-Host "  -SkipIDEs           Skip IDE installations" -ForegroundColor Gray
Write-Host "  -ForceReinstall     Force reinstall of existing applications" -ForegroundColor Gray
Write-Host "`nStarting installation in 3 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Start the installation
Start-Installation