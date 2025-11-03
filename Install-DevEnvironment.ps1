<#
.SYNOPSIS
    Interactive Windows Development Environment Setup Script
.DESCRIPTION
    This script provides an interactive menu to install development tools with user choice for each application
.PARAMETER AutoInstall
    Skip interactive mode and install all applications automatically
.PARAMETER SkipSystemChecks
    Skip system requirement checks
#>

param(
    [switch]$AutoInstall = $false,
    [switch]$SkipSystemChecks = $false,
    [string]$ConfigFile = $null,
    [string]$LogFile = "$env:USERPROFILE\\dev-installation-install.log",
    [switch]$UseParallel = $false,
    [int]$MaxParallel = 4,
    [switch]$ChildInstallMode = $false,
    [string]$ChildAppName = $null,
    [switch]$ChildAutoMode = $false
)

# Logging and helper output functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    try {
        if ($LogFile) {
            $logPath = $LogFile
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $entry = "${timestamp} [${Level}] ${Message}"
            $entry | Out-File -FilePath $logPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
    catch {
        # Logging failures should not stop the installation
    }
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
    Write-Log -Message $Message -Level "INFO"
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
    Write-Log -Message $Message -Level "SUCCESS"
}

function Write-Status {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
    Write-Log -Message $Message -Level "STATUS"
}

# Security Warning and Validation
function Show-SecurityWarning {
    Write-Host "`n$("!" * 60)" -ForegroundColor Red
    Write-Host "   SECURITY WARNING" -ForegroundColor Red
    Write-Host $("!" * 60) -ForegroundColor Red
    Write-Host "This script will download and install software from the internet." -ForegroundColor Yellow
    Write-Host "Please ensure you understand the following:" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor White
    Write-Host "• Only run scripts from trusted sources" -ForegroundColor White
    Write-Host "• Review the code before execution" -ForegroundColor White
    Write-Host "• Applications will be installed with administrator privileges" -ForegroundColor White
    Write-Host "• Internet connection is required for downloads" -ForegroundColor White
    Write-Host "• Some downloads may include additional software" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "Do you want to continue? (y/N): " -ForegroundColor Cyan -NoNewline
    
    $choice = Read-Host
    if ($choice -notmatch "^[Yy]$") {
        Write-Info "Installation cancelled by user."
        exit 0
    }
    
    Write-Host "" -ForegroundColor White
}

function Test-ScriptIntegrity {
    # Basic integrity check - ensure we're running from a reasonable location
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        $scriptDir = Split-Path -Parent $scriptPath
        Write-Status "Script location: $scriptDir"
        
        # Warn if running from unusual locations
        $unusualPaths = @($env:TEMP, $env:TMP, [System.IO.Path]::GetTempPath())
        foreach ($tempPath in $unusualPaths) {
            if ($scriptDir.StartsWith($tempPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Script is running from a temporary directory. Consider moving it to a permanent location."
                break
            }
        }
    }
}

# Enhanced Error Handling and Retry Functions
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5,
        [string]$OperationName = "operation"
    )
    
    $attempt = 0
    $lastError = $null
    
    do {
        $attempt++
        try {
            Write-Status "Attempting $OperationName (attempt $attempt/$MaxRetries)..."
            & $ScriptBlock
            return @{ Success = $true; Result = $null }
        }
        catch {
            $lastError = $_
            Write-Warning "$OperationName failed on attempt $attempt/$MaxRetries : $($_.Exception.Message)"
            
            if ($attempt -lt $MaxRetries) {
                Write-Info "Retrying in $DelaySeconds seconds..."
                Start-Sleep -Seconds $DelaySeconds
                # Exponential backoff
                $DelaySeconds = [math]::Min($DelaySeconds * 2, 30)
            }
        }
    } while ($attempt -lt $MaxRetries)
    
    return @{ Success = $false; Error = $lastError }
}

function Get-ErrorSuggestion {
    param([string]$ErrorMessage, [string]$AppName = "")
    
    $suggestions = @{
        "network" = @(
            "Check your internet connection",
            "Try disabling VPN or proxy temporarily",
            "Check firewall settings",
            "Try again later - the server might be temporarily unavailable"
        )
        "permission" = @(
            "Ensure you're running as Administrator",
            "Check if the application is already running",
            "Try closing conflicting applications",
            "Check antivirus software settings"
        )
        "diskspace" = @(
            "Free up disk space (at least 2GB recommended)",
            "Check available space on system drive",
            "Clear temporary files and downloads"
        )
        "winget" = @(
            "Install Windows Package Manager (WinGet) from Microsoft Store",
            "Update WinGet to the latest version",
            "Try using Chocolatey as alternative"
        )
        "chocolatey" = @(
            "Install Chocolatey package manager",
            "Run PowerShell as Administrator",
            "Check Chocolatey installation: choco --version"
        )
    }
    
    $errorLower = $ErrorMessage.ToLower()
    
    if ($errorLower -match "network|connection|timeout|unreachable") {
        return $suggestions.network
    }
    elseif ($errorLower -match "access|permission|denied|administrator") {
        return $suggestions.permission
    }
    elseif ($errorLower -match "space|disk|full") {
        return $suggestions.diskspace
    }
    elseif ($errorLower -match "winget") {
        return $suggestions.winget
    }
    elseif ($errorLower -match "choco|chocolatey") {
        return $suggestions.chocolatey
    }
    
    return @("Check the error message above for specific details", "Try manual installation from official website", "Search for the error message online for solutions")
}

function Write-EnhancedError {
    param(
        [string]$AppName,
        [string]$ErrorMessage,
        [string]$Operation = "installation"
    )
    
    Write-Error "$AppName $Operation failed: $ErrorMessage"
    
    $suggestions = Get-ErrorSuggestion -ErrorMessage $ErrorMessage -AppName $AppName
    
    Write-Host "`nTroubleshooting suggestions:" -ForegroundColor Yellow
    foreach ($suggestion in $suggestions) {
        Write-Host "• $suggestion" -ForegroundColor Gray
    }
    
    if ($AppName -and $Applications.ContainsKey($AppName)) {
        $appConfig = $Applications[$AppName]
        if ($appConfig.DirectDownload) {
            Write-Host "`nManual download: $($appConfig.DirectDownload)" -ForegroundColor Cyan
        }
    }
}

function Test-NetworkConnectivity {
    param([string]$Url = "https://www.google.com")
    
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    }
    catch {
        return $false
    }
}

# Progress Tracking Functions
function Write-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity = "Processing",
        [string]$Status = "",
        [int]$Id = 0
    )
    
    $percentComplete = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100) } else { 0 }
    $leftCount = [int][math]::Round($percentComplete / 2)
    $rightCount = [int][math]::Round((100 - $percentComplete) / 2)
    $progressBar = "[" + "█" * $leftCount + "░" * $rightCount + "]"
    
    # Update both Write-Progress (PowerShell progress bar) and console output for real-time updates
    Write-Progress -Activity $Activity -Status "$Status ($Current/$Total)" -PercentComplete $percentComplete -Id $Id
    
    # Clear the line and write progress bar
    Write-Host ("`r" + " " * 100 + "`r") -NoNewline
    Write-Host "$progressBar $percentComplete% ($Current/$Total) - $Status" -NoNewline -ForegroundColor Cyan
}

function Show-InstallationSummary {
    param([hashtable]$Results)
    
    Write-Host "`n$("=" * 60)" -ForegroundColor Magenta
    Write-Host "   INSTALLATION SUMMARY" -ForegroundColor Magenta
    Write-Host $("=" * 60) -ForegroundColor Magenta
    
    $successful = $Results.Successful
    $failed = $Results.Failed
    $skipped = $Results.Skipped
    
    Write-Host "`nSuccessful installations: $($successful.Count)" -ForegroundColor Green
    if ($successful.Count -gt 0) {
        foreach ($app in $successful) {
            Write-Host "  ✓ $app" -ForegroundColor Green
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-Host "`nFailed installations: $($failed.Count)" -ForegroundColor Red
        foreach ($app in $failed) {
            Write-Host "  ✗ $app" -ForegroundColor Red
        }
    }
    
    if ($skipped.Count -gt 0) {
        Write-Host "`nSkipped installations: $($skipped.Count)" -ForegroundColor Yellow
        foreach ($app in $skipped) {
            Write-Host "  ⚠ $app" -ForegroundColor Yellow
        }
    }
    
    $totalAttempted = $successful.Count + $failed.Count
    $successRate = if ($totalAttempted -gt 0) { [math]::Round(($successful.Count / $totalAttempted) * 100) } else { 0 }
    
    Write-Host "`nOverall Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })
}

function Get-EstimatedTime {
    param([int]$Completed, [int]$Total, [timespan]$Elapsed)
    
    if ($Completed -eq 0) { return "Calculating..." }
    
    $avgTimePerItem = $Elapsed.TotalSeconds / $Completed
    $remaining = $Total - $Completed
    $estimatedSeconds = $avgTimePerItem * $remaining
    
    if ($estimatedSeconds -lt 60) {
        return "~$([math]::Round($estimatedSeconds)) seconds remaining"
    } elseif ($estimatedSeconds -lt 3600) {
        return "~$([math]::Round($estimatedSeconds / 60)) minutes remaining"
    } else {
        return "~$([math]::Round($estimatedSeconds / 3600, 1)) hours remaining"
    }
}

# Security and Validation Functions
function Get-FileHash {
    param([string]$FilePath, [string]$Algorithm = "SHA256")
    
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm $Algorithm -ErrorAction Stop
        return $hash.Hash.ToLower()
    }
    catch {
        Write-Warning "Failed to calculate file hash: $($_.Exception.Message)"
        return $null
    }
}

function Test-FileIntegrity {
    param([string]$FilePath, [string]$ExpectedHash = "", [string]$Algorithm = "SHA256")
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File does not exist: $FilePath"
        return $false
    }
    
    $fileHash = Get-FileHash -FilePath $FilePath -Algorithm $Algorithm
    
    if (-not $fileHash) {
        return $false
    }
    
    if ($ExpectedHash -and $ExpectedHash -ne "") {
        $expectedHashLower = $ExpectedHash.ToLower()
        if ($fileHash -eq $expectedHashLower) {
            Write-Success "File integrity verified (SHA256: $fileHash)"
            return $true
        } else {
            Write-Error "File integrity check failed!"
            Write-Host "Expected: $expectedHashLower" -ForegroundColor Red
            Write-Host "Actual:   $fileHash" -ForegroundColor Red
            return $false
        }
    }
    
    # If no expected hash provided, just check if file is not empty
    $fileSize = (Get-Item $FilePath).Length
    if ($fileSize -gt 0) {
        $sizeMsg = "File downloaded successfully (" + $fileSize + " bytes)"
        Write-Success $sizeMsg
        return $true
    } else {
        Write-Error "Downloaded file is empty"
        return $false
    }
}

function Invoke-SecureDownload {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$ExpectedHash = "",
        [int]$TimeoutSeconds = 300
    )
    
    try {
        Write-Status "Downloading from: $Url"
        Write-Warning "Security Notice: Downloading from external source. Ensure you trust this URL."
        
        # Create web client with security settings
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script/1.0")
        
        # Set security protocol to use TLS 1.2 and 1.3
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 -bor 12288
        
        # Download with progress reporting
        $webClient.DownloadFile($Url, $OutputPath)
        
        # Verify file integrity
        if (Test-FileIntegrity -FilePath $OutputPath -ExpectedHash $ExpectedHash) {
            return $true
        } else {
            # Remove corrupted file
            if (Test-Path $OutputPath) {
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
            }
            return $false
        }
    }
    catch {
        Write-Error "Download failed: $($_.Exception.Message)"
        # Clean up failed download
        if (Test-Path $OutputPath) {
            Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

function Test-CertificateValidation {
    param([string]$Url)
    
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Timeout = 10000
        
        # This will throw an exception if certificate is invalid
        $response = $request.GetResponse()
        $response.Close()
        
        Write-Success "Certificate validation passed for $Url"
        return $true
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Status -eq [System.Net.WebExceptionStatus]::TrustFailure) {
            Write-Warning "Certificate validation failed for $Url"
            return $false
        }
        throw
    }
}

# Installation Pipeline Functions
function New-InstallationContext {
    param([string]$AppName, [hashtable]$AppConfig)
    
    return @{
        AppName = $AppName
        AppConfig = $AppConfig
        Methods = [System.Collections.ArrayList]::new()
        Results = [System.Collections.ArrayList]::new()
        StartTime = Get-Date
        EndTime = $null
        Success = $false
        ErrorMessage = ""
    }
}

function Add-InstallationMethod {
    param([hashtable]$Context, [string]$MethodName, [scriptblock]$InstallScript)
    
    $Context.Methods.Add(@{
        Name = $MethodName
        Script = $InstallScript
    }) | Out-Null
}

function Invoke-InstallationPipeline {
    param([hashtable]$Context)
    
    Write-InstallationStatus -AppName $Context.AppName -Status "Starting installation pipeline"
    
    foreach ($method in $Context.Methods) {
        Write-InstallationStatus -AppName $Context.AppName -Status "Attempting installation" -Method $method.Name
        
        try {
            $result = & $method.Script
            $Context.Results.Add(@{
                Method = $method.Name
                Success = $result
                Error = $null
            }) | Out-Null
            
            if ($result) {
                $Context.Success = $true
                $Context.EndTime = Get-Date
                Write-InstallationStatus -AppName $Context.AppName -Status "Installation completed" -Method $method.Name -IsComplete $true
                return $true
            } else {
                Write-InstallationStatus -AppName $Context.AppName -Status "Method failed, trying next method" -Method $method.Name
            }
        }
        catch {
            $Context.Results.Add(@{
                Method = $method.Name
                Success = $false
                Error = $_.Exception.Message
            }) | Out-Null
            
            Write-InstallationStatus -AppName $Context.AppName -Status "Method failed: $($_.Exception.Message)" -Method $method.Name
        }
    }
    
    $Context.EndTime = Get-Date
    $Context.Success = $false
    $Context.ErrorMessage = "All installation methods failed"
    
    Write-InstallationStatus -AppName $Context.AppName -Status "All methods failed" -IsComplete $true
    return $false
}

function Show-PreInstallationSummary {
    param([string[]]$SelectedApps)
    
    Write-Host "`n$("=" * 60)" -ForegroundColor Blue
    Write-Host "   PRE-INSTALLATION SUMMARY" -ForegroundColor Blue
    Write-Host $("=" * 60) -ForegroundColor Blue
    
    Write-Host "`nApplications to be installed:" -ForegroundColor White
    $appCategories = @{}
    
    foreach ($appName in $SelectedApps) {
        $category = $Applications[$appName].Category
        if (-not $appCategories.ContainsKey($category)) {
            $appCategories[$category] = [System.Collections.ArrayList]::new()
        }
        $appCategories[$category].Add($appName) | Out-Null
    }
    
    foreach ($category in $appCategories.Keys) {
        Write-Host "`n$category" -ForegroundColor Green
        Write-Host $("-" * $category.Length) -ForegroundColor Green
        foreach ($app in $appCategories[$category]) {
            $description = $Applications[$app].Description
            Write-Host "  • $app" -ForegroundColor White
            if ($description) {
                Write-Host "    $description" -ForegroundColor Gray
            }
        }
    }
    
    # Estimate installation time (rough estimate: 2-5 minutes per app)
    $estimatedMinutes = $SelectedApps.Count * 3
    $timeEstimate = if ($estimatedMinutes -lt 60) {
        "~$estimatedMinutes minutes"
    } else {
        "~$([math]::Round($estimatedMinutes / 60, 1)) hours"
    }
    
    # Estimate disk space (rough estimate)
    $estimatedDiskGB = [math]::Round($SelectedApps.Count * 0.5, 1)
    
    Write-Host "`nInstallation Estimates:" -ForegroundColor Cyan
    Write-Host "• Estimated time: $timeEstimate" -ForegroundColor White
    Write-Host "• Estimated disk space: $estimatedDiskGB GB" -ForegroundColor White
    Write-Host "• Applications to install: $($SelectedApps.Count)" -ForegroundColor White
    
    Write-Host "`nSystem Requirements:" -ForegroundColor Yellow
    Write-Host "• Administrator privileges: Required" -ForegroundColor White
    Write-Host "• Internet connection: Required for downloads" -ForegroundColor White
    Write-Host "• Available disk space: 20+ GB recommended" -ForegroundColor White
    
    Write-Host "`nDo you want to proceed with the installation? (Y/n): " -ForegroundColor Cyan -NoNewline
    $choice = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match "^[Yy]$") {
        return $true
    }
    
    return $false
}

# Check if running as Administrator
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select `"Run as Administrator`""
    exit 1
}
function Show-InteractiveMenu {
    Write-Host "`n$("=" * 50)" -ForegroundColor Magenta
    Write-Host "   INTERACTIVE DEVELOPMENT ENVIRONMENT SETUP" -ForegroundColor Magenta
    Write-Host $("=" * 50) -ForegroundColor Magenta
    Write-Host "Choose your installation method:" -ForegroundColor Yellow
    Write-Host "1. Install ALL applications automatically" -ForegroundColor White
    Write-Host "2. Choose applications to install (interactive)" -ForegroundColor White
    Write-Host "3. Exit" -ForegroundColor White
    Write-Host "`nEnter your choice (1-3): " -ForegroundColor Cyan -NoNewline
    
    $choice = Read-Host
    return $choice
}


function Get-ApplicationCategories {
    param([hashtable]$Apps)
    
    $categories = @{}
    
    foreach ($appName in $Apps.Keys) {
        $category = $Apps[$appName].Category
        if (-not $categories.ContainsKey($category)) {
            $categories[$category] = [System.Collections.ArrayList]::new()
        }
        $categories[$category].Add($appName) | Out-Null
    }
    
    return $categories
}
function Show-CategoryMenu {
    param([hashtable]$Categories)
    
    Write-Host "`nAvailable Applications:" -ForegroundColor White
    
    $i = 1
    $menuOptions = @{}
    
    foreach ($category in $Categories.Keys) {
        Write-Host "`n$category" -ForegroundColor Green
        Write-Host $("-" * $category.Length) -ForegroundColor Green
        
        foreach ($app in $Categories[$category]) {
            Write-Host "  $i. $app" -ForegroundColor White
            $menuOptions[$i] = $app
            $i++
        }
    }
    
    Write-Host "`n$i. Install ALL applications" -ForegroundColor Yellow
    $allOption = $i
    $i++
    
    Write-Host "$i. Proceed with selected applications" -ForegroundColor Cyan
    $proceedOption = $i
    
    return @{
        MenuOptions = $menuOptions
        AllOption = $allOption
        ProceedOption = $proceedOption
    }
}


function Get-UserApplicationSelection {
    param([hashtable]$MenuInfo)
    
    $selectedApps = [System.Collections.ArrayList]::new()
    $menuOptions = $MenuInfo.MenuOptions
    $allOption = $MenuInfo.AllOption
    $proceedOption = $MenuInfo.ProceedOption
    
    do {
        Write-Host "`nEnter application numbers (comma-separated) or choose option ${allOption}/${proceedOption}: " -ForegroundColor Cyan -NoNewline
        $userInput = Read-Host
    
        if ($userInput -eq $allOption) {
            return $Applications.Keys
        }
        elseif ($userInput -eq $proceedOption) {
            break
        }
        else {
            $selections = $userInput -split ',' | ForEach-Object { $_.Trim() }
            foreach ($selection in $selections) {
                if ($selection -match '^\d+$' -and $menuOptions[[int]$selection]) {
                    $appName = $menuOptions[[int]$selection]
                    if (-not $selectedApps.Contains($appName)) {
                        $selectedApps.Add($appName) | Out-Null
                        Write-Success "Added $appName to installation list"
                    }
                }
                else {
                    Write-Warning "Invalid selection: $selection"
                }
            }
    
            if ($selectedApps.Count -gt 0) {
                Write-Host "`nCurrently selected: $($selectedApps -join ', ')" -ForegroundColor Green
            }
        }
    } while ($userInput -ne $proceedOption)
    
    return $selectedApps
}

function Show-ApplicationSelectionMenu {
    $categories = Get-ApplicationCategories -Apps $Applications
    $menuInfo = Show-CategoryMenu -Categories $categories
    $selectedApps = Get-UserApplicationSelection -MenuInfo $menuInfo
    
    return $selectedApps
}

function Confirm-ApplicationInstall {
    param([string]$AppName, [hashtable]$AppConfig)
    
    $isInstalled = Test-AppInstalled -AppName $AppName -AppConfig $AppConfig
    
    if ($isInstalled) {
        Write-Host "`n$AppName is already installed." -ForegroundColor Green
        Write-Host "Do you want to reinstall it? (y/N): " -ForegroundColor Yellow -NoNewline
        $choice = Read-Host
        return ($choice -eq 'y' -or $choice -eq 'Y')
    }
    
    Write-Host "`nInstall $AppName? (Y/n): " -ForegroundColor Cyan -NoNewline
    $choice = Read-Host
    
    # Default to Yes if user presses Enter
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $true
    }
    
    return ($choice -eq 'y' -or $choice -eq 'Y')
}

# System Requirements Check with enhanced error handling
function Test-SystemRequirements {
    Write-Info "Checking system requirements..."
    
    $issues = @()
    
    # Check Windows version
    try {
        if ([System.Environment]::OSVersion.Version.Major -lt 10) {
            $issues += "Windows 10 or later is required (current: Windows $([System.Environment]::OSVersion.Version))"
        }
    }
    catch {
        $issues += "Unable to determine Windows version: $($_.Exception.Message)"
    }
    
    # Check available disk space
    try {
        $drive = Get-PSDrive C
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
        Write-Info "Available disk space: $freeSpaceGB GB"
        if ($freeSpaceGB -lt 20) {
            $issues += "Low disk space: $freeSpaceGB GB free (recommended: 20+ GB)"
        }
    }
    catch {
        $issues += "Unable to check disk space: $($_.Exception.Message)"
    }
    
    # Check RAM
    try {
        $memory = Get-WmiObject -Class Win32_ComputerSystem
        $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
        Write-Info "Total RAM: $totalMemoryGB GB"
        if ($totalMemoryGB -lt 8) {
            $issues += "Low memory: $totalMemoryGB GB (recommended: 8+ GB for development)"
        }
    }
    catch {
        $issues += "Unable to check memory: $($_.Exception.Message)"
    }
    
    # Check network connectivity
    Write-Info "Checking network connectivity..."
    if (-not (Test-NetworkConnectivity)) {
        $issues += "No internet connection detected. Required for downloading applications."
    }
    
    # Report issues
    if ($issues.Count -gt 0) {
        Write-Warning "System requirements check found $($issues.Count) issue(s):"
        foreach ($issue in $issues) {
            Write-Host "• $issue" -ForegroundColor Yellow
        }
        
        Write-Host "`nWould you like to continue anyway? (y/N): " -ForegroundColor Cyan -NoNewline
        $choice = Read-Host
        if ($choice -notmatch "^[Yy]$") {
            return $false
        }
    }
    
    Write-Success "System requirements check completed"
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

# Install Chocolatey with enhanced error handling
function Install-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Success "Chocolatey already installed"
        return $true
    }
    
    Write-Info "Installing Chocolatey package manager..."
    
    $result = Invoke-WithRetry -ScriptBlock {
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            Start-Sleep -Seconds 10
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Success "Chocolatey installed successfully"
                return $true
            } else {
                throw "Chocolatey installed but not recognized. You may need to restart PowerShell."
            }
        }
        catch {
            throw "Failed to install Chocolatey: $($_.Exception.Message)"
        }
    } -MaxRetries 2 -OperationName "Chocolatey installation"
    
    if (-not $result.Success) {
        Write-EnhancedError -AppName "Chocolatey" -ErrorMessage $result.Error.Exception.Message -Operation "installation"
        return $false
    }
    
    return $true
}

# Configuration Management
function Get-DefaultApplicationConfig {
    return @{
        "Google Chrome" = @{
            WingetId = "Google.Chrome"
            ChocolateyId = "googlechrome"
            Category = "Browsers"
            Description = "Fast, secure web browser by Google"
            TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue")
        }
        "Brave Browser" = @{
            WingetId = "Brave.Brave"
            ChocolateyId = "brave"
            Category = "Browsers"
            Description = "Privacy-focused web browser"
            TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\BraveSoftware\Update\ClientState\{C1033C00-81A4-4FB3-9143-2D2B95D2E13A}' -Name pv -ErrorAction SilentlyContinue")
        }
        "Git" = @{
            WingetId = "Git.Git"
            ChocolateyId = "git"
            Category = "Development Tools"
            Description = "Distributed version control system"
            TestCommands = @("git --version 2>&1")
        }
        "Node.js LTS" = @{
            WingetId = "OpenJS.NodeJS.LTS"
            ChocolateyId = "nodejs-lts"
            Category = "Development Tools"
            Description = "JavaScript runtime for server-side development"
            TestCommands = @("node --version 2>&1")
        }
        "Python" = @{
            WingetId = "Python.Python.3.12"
            ChocolateyId = "python"
            Category = "Development Tools"
            Description = "Popular programming language for AI, web, and automation"
            TestCommands = @("python --version 2>&1", "python3 --version 2>&1")
        }
        "VS Code" = @{
            WingetId = "Microsoft.VisualStudioCode"
            ChocolateyId = "vscode"
            Category = "IDEs"
            Description = "Lightweight but powerful source code editor"
            TestCommands = @("code --version 2>&1")
        }
        "Docker Desktop" = @{
            WingetId = "Docker.DockerDesktop"
            ChocolateyId = "docker-desktop"
            Category = "Development Tools"
            Description = "Containerization platform for developing and running applications"
            TestCommands = @("docker --version 2>&1")
        }
        "Postman" = @{
            WingetId = "Postman.Postman"
            ChocolateyId = "postman"
            Category = "Development Tools"
            Description = "API platform for building and using APIs"
            TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\Postman\Postman' -Name Version -ErrorAction SilentlyContinue")
        }
        "WinRAR" = @{
            WingetId = "RARLab.WinRAR"
            ChocolateyId = "winrar"
            Category = "Utilities"
            Description = "Powerful archive manager"
            TestCommands = @("Get-ItemProperty 'HKLM:\SOFTWARE\WinRAR' -Name version -ErrorAction SilentlyContinue")
        }
        "AnyDesk" = @{
            WingetId = "AnyDeskSoftwareGmbH.AnyDesk"
            ChocolateyId = "anydesk"
            Category = "Utilities"
            Description = "Remote desktop application"
        }
        "Zoom" = @{
            WingetId = "Zoom.Zoom"
            ChocolateyId = "zoom"
            Category = "Utilities"
            Description = "Video conferencing and communication platform"
        }
        "Visual Studio 2022 Professional" = @{
            WingetId = "Microsoft.VisualStudio.2022.Professional"
            ChocolateyId = "visualstudio2022professional"
            Category = "IDEs"
            Description = "Full-featured IDE for .NET, C++, and more"
        }
        "Android Studio" = @{
            WingetId = "Google.AndroidStudio"
            ChocolateyId = "androidstudio"
            Category = "IDEs"
            Description = "Official IDE for Android development (Manual installation recommended)"
            ManualDownload = "https://developer.android.com/studio"
        }
        "PowerShell 7" = @{
            WingetId = "Microsoft.PowerShell"
            ChocolateyId = "powershell"
            Category = "Development Tools"
            Description = "Cross-platform automation and configuration tool"
            TestCommands = @("pwsh --version 2>&1")
        }
    }
}

function Load-ApplicationConfiguration {
    param([string]$ConfigFile = $null)
    
    # Try to load from config file if specified
    if ($ConfigFile -and (Test-Path $ConfigFile)) {
        try {
            Write-Info "Loading configuration from: $ConfigFile"
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            Write-Success "Configuration loaded successfully"
            return $config
        }
        catch {
            Write-Warning "Failed to load config file: $($_.Exception.Message)"
            Write-Info "Using default configuration"
        }
    }
    
    # Return default configuration
    return Get-DefaultApplicationConfig
}

function Validate-ApplicationConfig {
    param([hashtable]$Config)
    
    $requiredFields = @('Category', 'Description')
    $warnings = @()
    
    foreach ($appName in $Config.Keys) {
        $appConfig = $Config[$appName]
        
        # Check required fields
        foreach ($field in $requiredFields) {
            if (-not $appConfig.ContainsKey($field)) {
                $warnings += "$appName missing required field: $field"
            }
        }
        
        # Check installation methods
        $hasInstallMethod = $appConfig.WingetId -or $appConfig.ChocolateyId -or $appConfig.DirectDownload
        if (-not $hasInstallMethod) {
            $warnings += "$appName has no installation methods defined"
        }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Warning "Configuration validation found $($warnings.Count) issues:"
        foreach ($warning in $warnings) {
            Write-Host "• $warning" -ForegroundColor Yellow
        }
    }
    
    return $warnings.Count -eq 0
}

# Initialize application configuration
$Applications = Load-ApplicationConfiguration
if (-not (Validate-ApplicationConfig -Config $Applications)) {
    Write-Warning "Configuration has validation errors. Some features may not work correctly."
}

# Child process mode: install a single app in a separate process (used for parallel installs)
if ($ChildInstallMode) {
    if (-not $ChildAppName) {
        Write-Error "ChildInstallMode requires -ChildAppName to be specified"
        exit 2
    }

    if (-not $Applications.ContainsKey($ChildAppName)) {
        Write-Error "Unknown application specified for child install: $ChildAppName"
        exit 3
    }

    $appConfig = $Applications[$ChildAppName]
    $wingetAvailable = Install-WinGet
    $chocolateyAvailable = Install-Chocolatey

    $success = Install-Application -AppName $ChildAppName -AppConfig $appConfig -ForceInstall:$ChildAutoMode -WingetAvailable:$wingetAvailable

    if ($success) { exit 0 } else { exit 1 }
}

# Check if application is installed
function Test-AppInstalled {
    param([string]$AppName, [hashtable]$AppConfig)
    
    if ($AppConfig.TestCommands) {
        foreach ($testCommand in $AppConfig.TestCommands) {
            try {
                $result = Invoke-Expression $testCommand 2>$null
                if ($result -and $result -notmatch "not recognized") {
                    return $true
                }
            }
            catch {}
        }
    }
    
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

# Install application using WinGet with enhanced error handling
function Install-WithWinGet {
    param([string]$AppName, [string]$WinGetId)
    
    $result = Invoke-WithRetry -ScriptBlock {
        Write-Status "Installing $AppName via WinGet: $WinGetId"
        
        # Check if winget is available
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "WinGet command not found. Please install Windows Package Manager."
        }
        
        $process = Start-Process -FilePath "winget" -ArgumentList "install --id $WinGetId --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Success "Successfully installed $AppName via WinGet"
            return $true
        } elseif ($process.ExitCode -eq 0x80070005) {
            throw "Access denied. Please run as Administrator."
        } elseif ($process.ExitCode -eq 0x80070490) {
            throw "Package not found or not available in current region."
        } else {
            throw "WinGet installation failed with exit code: $($process.ExitCode)"
        }
    } -MaxRetries 2 -OperationName "$AppName WinGet installation"
    
    if (-not $result.Success) {
        Write-EnhancedError -AppName $AppName -ErrorMessage $result.Error.Exception.Message -Operation "WinGet installation"
        return $false
    }
    
    return $true
}

# Install application using Chocolatey with enhanced error handling
function Install-WithChocolatey {
    param([string]$AppName, [string]$ChocolateyId)
    
    $result = Invoke-WithRetry -ScriptBlock {
        Write-Status "Installing $AppName via Chocolatey: $ChocolateyId"
        
        # Check if choco is available
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            throw "Chocolatey command not found. Please install Chocolatey package manager."
        }
        
        $process = Start-Process -FilePath "choco" -ArgumentList "install $ChocolateyId -y --no-progress" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Success "Successfully installed $AppName via Chocolatey"
            return $true
        } elseif ($process.ExitCode -eq 1) {
            throw "Chocolatey installation failed - package may not exist or network issues."
        } elseif ($process.ExitCode -eq 5) {
            throw "Access denied. Please run as Administrator."
        } else {
            throw "Chocolatey installation failed with exit code: $($process.ExitCode)"
        }
    } -MaxRetries 2 -OperationName "$AppName Chocolatey installation"
    
    if (-not $result.Success) {
        Write-EnhancedError -AppName $AppName -ErrorMessage $result.Error.Exception.Message -Operation "Chocolatey installation"
        return $false
    }
    
    return $true
}

# Android Studio requires manual installation due to large file size
function Install-AndroidStudio-Manual {
    Write-Warning "Android Studio requires manual installation due to its large size (>1GB)."
    Write-Host "`nPlease download and install Android Studio manually:" -ForegroundColor Yellow
    Write-Host "  1. Visit: https://developer.android.com/studio" -ForegroundColor Cyan
    Write-Host "  2. Download the latest version for Windows" -ForegroundColor Cyan
    Write-Host "  3. Run the installer and follow the setup wizard" -ForegroundColor Cyan
    Write-Host "  4. Configure SDK and emulator settings as needed" -ForegroundColor Cyan
    
    Write-Host "`nWould you like to open the download page in your browser? (y/N): " -ForegroundColor Green -NoNewline
    $choice = Read-Host
    
    if ($choice -match "^[Yy]$") {
        Start-Process "https://developer.android.com/studio"
        Write-Success "Opened Android Studio download page in your default browser"
    }
    
    return $false
}

function Write-InstallationStatus {
    param(
        [string]$AppName,
        [string]$Status,
        [string]$Method = "",
        [bool]$IsComplete = $false
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $statusIcon = if ($IsComplete) { "✓" } else { "⟳" }
    $methodText = if ($Method) { " via $Method" } else { "" }
    
    Write-Host "$timestamp $statusIcon $AppName$methodText - $Status" -ForegroundColor $(if ($IsComplete) { "Green" } else { "Cyan" })
}

# Enhanced installation function with better status reporting
# Enhanced installation function with pipeline
function Install-Application {
    param([string]$AppName, [hashtable]$AppConfig, [bool]$ForceInstall = $false, [bool]$WingetAvailable = $false)
    
    if (-not $ForceInstall) {
        if (-not (Confirm-ApplicationInstall -AppName $AppName -AppConfig $AppConfig)) {
            Write-InstallationStatus -AppName $AppName -Status "Skipped by user" -IsComplete $true
            return $false
        }
    }
    
    $isInstalled = Test-AppInstalled -AppName $AppName -AppConfig $AppConfig
    
    if ($isInstalled -and -not $ForceInstall) {
        Write-InstallationStatus -AppName $AppName -Status "Already installed" -IsComplete $true
        return $true
    }
    
    Write-InstallationStatus -AppName $AppName -Status "Starting installation"
    Write-Status "Description: $($AppConfig.Description)"
    
    # Create installation context
    $context = New-InstallationContext -AppName $AppName -AppConfig $AppConfig
    
    # Special handling for Android Studio - manual installation only
    if ($AppName -eq "Android Studio") {
        Add-InstallationMethod -Context $context -MethodName "Manual Installation" -InstallScript {
            Install-AndroidStudio-Manual
        }
    }
    else {
        # Add installation methods in order of preference
        if ($AppConfig.WingetId -and $WingetAvailable) {
            Add-InstallationMethod -Context $context -MethodName "WinGet" -InstallScript {
                Install-WithWinGet -AppName $AppName -WinGetId $AppConfig.WingetId
            }
        }
        
        if ($AppConfig.ChocolateyId) {
            Add-InstallationMethod -Context $context -MethodName "Chocolatey" -InstallScript {
                Install-WithChocolatey -AppName $AppName -ChocolateyId $AppConfig.ChocolateyId
            }
        }
    }
    
    # Execute installation pipeline
    $success = Invoke-InstallationPipeline -Context $context
    
    if (-not $success) {
        Write-EnhancedError -AppName $AppName -ErrorMessage "All automated installation methods failed" -Operation "installation"
    }
    
    return $success
}

# Configure Development Environment
function Set-DevelopmentEnvironment {
    Write-Info "Configuring development environment..."

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

    try {
        git config --global user.name "Developer"
        git config --global user.email "developer@example.com"
        git config --global core.autocrlf true
        Write-Success "Configured Git global settings"
        Write-Info "Remember to update git user name and email with your actual details"
    }
    catch {
        Write-Warning "Failed to configure Git: $($_.Exception.Message)"
    }
}

# Configure Docker
function Set-Docker {
    Write-Info "Configuring Docker..."

    try {
        Start-Service "Docker Desktop Service" -ErrorAction SilentlyContinue
        Set-Service -Name "Docker Desktop Service" -StartupType Automatic -ErrorAction SilentlyContinue
        Write-Success "Docker configured successfully"
    }
    catch {
        Write-Warning "Docker configuration may require manual setup"
    }
}

# System Optimization
function Optimize-System {
    Write-Info "Setting up development environment..."
    
    $devFolders = @("Projects", "Scripts", "Temp", "Backups")
    foreach ($folder in $devFolders) {
        $path = "$env:USERPROFILE\$folder"
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Success "Created directory: $path"
        }
    }
}
function Start-InteractiveInstallation {
    param([string[]]$SelectedApps, [bool]$AutoMode = $false)
    
    Write-Host "`n$("=" * 50)" -ForegroundColor Magenta
    Write-Host "   STARTING INSTALLATION" -ForegroundColor Magenta
    Write-Host $("=" * 50) -ForegroundColor Magenta
    
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
    
    # Show pre-installation summary (unless in auto mode)
    if (-not $AutoMode) {
        if (-not (Show-PreInstallationSummary -SelectedApps $SelectedApps)) {
            Write-Info "Installation cancelled by user."
            return
        }
    }
    
    # Install applications with progress tracking
    $successCount = 0
    $totalCount = $SelectedApps.Count
    $startTime = Get-Date
    
    # Initialize results tracking
    $results = @{
        Successful = [System.Collections.ArrayList]::new()
        Failed = [System.Collections.ArrayList]::new()
        Skipped = [System.Collections.ArrayList]::new()
    }
    
    Write-Host "`nApplications to install: $($SelectedApps -join ', ')" -ForegroundColor Green
    Write-Host "Starting installation process..." -ForegroundColor Cyan
    
    if ($UseParallel -and $SelectedApps.Count -gt 1) {
        Write-Info "Parallel installation enabled (max parallel: $MaxParallel)"
        $psExe = (Get-Process -Id $PID).Path
        $processes = @()
        $procMap = @{}

        foreach ($appName in $SelectedApps) {
            # Throttle to MaxParallel
            while ($processes.Count -ge $MaxParallel) {
                Start-Sleep -Seconds 1
                $processes = $processes | Where-Object { -not $_.HasExited }
            }

            Write-Host "`nStarting child installer for $appName" -ForegroundColor Cyan

            $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $MyInvocation.MyCommand.Path, '-ChildInstallMode', '-ChildAppName', $appName)
            if ($AutoMode) { $args += '-ChildAutoMode' }
            if ($LogFile) { $args += '-LogFile'; $args += $LogFile }
            if ($ConfigFile) { $args += '-ConfigFile'; $args += $ConfigFile }

            $proc = Start-Process -FilePath $psExe -ArgumentList $args -PassThru -NoNewWindow
            $processes += $proc
            $procMap[$proc.Id] = $appName
        }

        # Wait for all child processes to complete
        while ($processes | Where-Object { -not $_.HasExited }) {
            $running = ($processes | Where-Object { -not $_.HasExited }).Count
            Write-Progress -Activity "Installing Applications (parallel)" -Status "$running running" -PercentComplete ([math]::Round((($totalCount - $running) / $totalCount) * 100)) -Id 1
            Start-Sleep -Seconds 1
        }

        # Collect results from child processes
        foreach ($p in $processes) {
            $app = $procMap[$p.Id]
            if ($p.ExitCode -eq 0) {
                $results.Successful.Add($app) | Out-Null
                $successCount++
            } else {
                $results.Failed.Add($app) | Out-Null
            }
        }
    }
    else {
        for ($i = 0; $i -lt $SelectedApps.Count; $i++) {
            $appName = $SelectedApps[$i]
            $current = $i + 1
            $elapsed = (Get-Date) - $startTime
            $estimatedTime = Get-EstimatedTime -Completed $current -Total $totalCount -Elapsed $elapsed

            Write-Host "`n$("-" * 60)" -ForegroundColor Gray
            Write-Host "Processing: $appName ($current/$totalCount)" -ForegroundColor White
            Write-Host "Estimated time remaining: $estimatedTime" -ForegroundColor Cyan
            Write-Host $("-" * 60) -ForegroundColor Gray

            # Update progress bar before installation
            Write-ProgressBar -Current $current -Total $totalCount -Activity "Installing Applications" -Status "Starting $appName" -Id 1

            $installResult = Install-Application -AppName $appName -AppConfig $Applications[$appName] -ForceInstall $AutoMode -WingetAvailable $wingetAvailable

            if ($installResult) {
                $results.Successful.Add($appName) | Out-Null
                $successCount++
                Write-ProgressBar -Current $current -Total $totalCount -Activity "Installing Applications" -Status "Completed $appName" -Id 1
            } else {
                $results.Failed.Add($appName) | Out-Null
                Write-ProgressBar -Current $current -Total $totalCount -Activity "Installing Applications" -Status "Failed $appName" -Id 1
            }

            # Brief pause to show final status
            Start-Sleep -Milliseconds 300
            Write-Host ""  # New line after each app
        }
    }
    
    # Clear progress bar
    Write-Progress -Activity "Installing Applications" -Completed -Id 1
    Write-Host "`n" # New line after progress bar
    
    # Configuration
    Write-Host "`n$("=" * 50)" -ForegroundColor Cyan
    Write-Host "   FINALIZING SETUP" -ForegroundColor Cyan
    Write-Host $("=" * 50) -ForegroundColor Cyan
    
    Set-DevelopmentEnvironment
    Set-Docker
    Optimize-System
    
    # Show detailed summary
    Show-InstallationSummary -Results $results
    
    # Final next steps
    Write-Host "`nNEXT STEPS:" -ForegroundColor Green
    Write-Host "1. Restart your computer to complete installations" -ForegroundColor Yellow
    Write-Host "2. Configure Docker Desktop (if installed)" -ForegroundColor Yellow
    Write-Host "3. Update Git user name and email: git config --global user.name `"Your Name`"" -ForegroundColor Yellow
    
    # Show Android Studio manual installation reminder if it was selected
    if ($SelectedApps -contains "Android Studio") {
        Write-Host "4. Install Android Studio manually from: https://developer.android.com/studio" -ForegroundColor Yellow
    }
    
    if ($results.Failed.Count -gt 0) {
        Write-Host "`nMANUAL INSTALLATION REQUIRED:" -ForegroundColor Red
        foreach ($app in $results.Failed) {
            Write-Host "• $app - Check the error messages above for manual installation links" -ForegroundColor Red
        }
    }
}

# Main Script Execution
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "   INTERACTIVE DEV ENVIRONMENT INSTALLER" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "GitHub: github.com/amin-bake/dev-installation-scripts" -ForegroundColor Gray

# Security and integrity checks
Test-ScriptIntegrity
Show-SecurityWarning

if ($AutoInstall) {
    Write-Info "Auto-install mode enabled. Installing all applications..."
    Start-InteractiveInstallation -SelectedApps $Applications.Keys -AutoMode $true
} else {
    $choice = Show-InteractiveMenu
    
    switch ($choice) {
        "1" {
            Write-Info "Installing ALL applications..."
            Start-InteractiveInstallation -SelectedApps $Applications.Keys -AutoMode $true
        }
        "2" {
            $selectedApps = Show-ApplicationSelectionMenu
            if ($selectedApps.Count -gt 0) {
                Write-Info "Starting installation of selected applications..."
                Start-InteractiveInstallation -SelectedApps $selectedApps -AutoMode $false
            } else {
                Write-Warning "No applications selected. Exiting."
            }
        }
        "3" {
            Write-Info "Exiting installation."
            exit 0
        }
        default {
            Write-Error "Invalid choice. Exiting."
            exit 1
        }
    }
}