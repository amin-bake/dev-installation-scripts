# Windows Development Environment Setup

[![PowerShell](https://img.shields.io/badge/PowerShell-7.4+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10+-blue.svg)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive PowerShell script to automatically install and configure a complete Windows development environment with essential tools, IDEs, and utilities.

## 🚀 Features

This script installs and configures:

### Browsers

- Google Chrome
- Brave Browser

### Development Tools

- Git for Windows
- Node.js LTS
- Python 3.12
- Docker Desktop
- Postman

### IDEs & Editors

- Visual Studio Code
- Visual Studio 2022 Professional
- **Android Studio** (Manual installation recommended - see notes below)

### Utilities

- WinRAR
- AnyDesk
- Zoom
- PowerShell 7

## 📋 Prerequisites

- **Operating System**: Windows 10 or later (64-bit)
- **Administrator Privileges**: Required for installation
- **Internet Connection**: Required for downloading applications
- **Disk Space**: At least 20 GB free space recommended
- **RAM**: 8 GB or more recommended

## 🛠️ Installation & Usage

### Method 1: Direct Execution (Recommended)

1. **Download the script**:

   ```powershell
   git clone https://github.com/amin-bake/dev-installation-scripts.git
   cd dev-installation-scripts
   ```

2. **Run as Administrator**:
   - Right-click on `Install-DevEnvironment.ps1`
   - Select "Run with PowerShell" (as Administrator)
   - Or open PowerShell as Administrator and run:
   ```powershell
   .\Install-DevEnvironment.ps1
   ```

### Method 2: Command Line with Parameters

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-DevEnvironment.ps1 [parameters]
```

### Available Parameters

| Parameter               | Description                                                              |
| ----------------------- | ------------------------------------------------------------------------ |
| `-AutoInstall`          | Skip interactive mode and install all applications automatically         |
| `-SkipSystemChecks`     | Skip system requirement checks                                           |
| `-UseParallel`          | Enable parallel installation of applications (faster)                    |
| `-MaxParallel <number>` | Maximum number of parallel installations (default: 4)                    |
| `-ConfigFile <path>`    | Path to custom JSON configuration file                                   |
| `-LogFile <path>`       | Path to log file (default: `%USERPROFILE%\dev-installation-install.log`) |

### Examples

```powershell
# Interactive mode - choose applications to install
.\Install-DevEnvironment.ps1

# Install all applications automatically
.\Install-DevEnvironment.ps1 -AutoInstall

# Use parallel installation for faster setup (up to 4 apps at once)
.\Install-DevEnvironment.ps1 -UseParallel -MaxParallel 4

# Use custom configuration file
.\Install-DevEnvironment.ps1 -ConfigFile ".\my-apps.json"

# Quick install without system checks
.\Install-DevEnvironment.ps1 -SkipSystemChecks -AutoInstall

# Parallel install with custom log location
.\Install-DevEnvironment.ps1 -UseParallel -LogFile "C:\Logs\install.log"
```

## ⚙️ What the Script Does

### System Checks

- Verifies Windows version compatibility
- Checks available disk space and RAM
- Validates administrator privileges

### Package Manager Setup

- Installs Windows Package Manager (WinGet) if available
- Installs Chocolatey package manager
- Falls back to direct downloads when needed

### Application Installation

- **Interactive Mode**: Choose which applications to install
- **Automated Mode**: Install all applications automatically with `-AutoInstall`
- **Parallel Installation**: Install multiple applications simultaneously with `-UseParallel`
- Attempts installation via WinGet (fastest)
- Falls back to Chocolatey
- Uses direct downloads as final fallback
- **Android Studio**: Prompts for manual installation (due to large file size >1GB)

### Environment Configuration

- Adds development tools to PATH
- Configures Git with basic settings
- Sets up Docker service
- Creates development folder structure (`Projects`, `Scripts`, `Temp`, `Backups`)
- Comprehensive logging to track installation progress
- Real-time progress indicators for installation status

## 🔧 Post-Installation Steps

1. **Restart your computer** to complete installations
2. **Configure Docker Desktop** - Launch and complete initial setup
3. **Update Git configuration**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```
4. **Install Android Studio manually** (if selected):
   - Visit: https://developer.android.com/studio
   - Download the latest version for Windows
   - Run the installer and configure SDK settings
5. **Verify installations** by running:
   ```powershell
   # Check installed tools
   git --version
   node --version
   python --version
   code --version
   docker --version
   ```
6. **Check installation log** for any errors:
   ```powershell
   Get-Content "$env:USERPROFILE\dev-installation-install.log"
   ```

## 🐛 Troubleshooting

### Common Issues

**"Execution Policy" Error**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Chocolatey Installation Fails**

- Ensure you're running as Administrator
- Check internet connection
- Try manual Chocolatey installation

**Application Installation Fails**

- Some applications may require manual installation
- Check the installation summary for failed applications
- Download directly from official websites

**Android Studio Issues**

- **Note**: Android Studio is no longer automatically downloaded due to its large file size (>1GB)
- The script will prompt you to download it manually from https://developer.android.com/studio
- This ensures faster script execution and better control over the installation
- Follow the on-screen prompts to open the download page in your browser

### Manual Installation Links

If automatic installation fails, download manually:

- [Android Studio](https://developer.android.com/studio)
- [Visual Studio](https://visualstudio.microsoft.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Node.js](https://nodejs.org/)
- [Python](https://python.org/)

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### New Features in This Version

- ✨ **Parallel Installation**: Install multiple applications simultaneously for faster setup
- 📊 **Real-time Progress Indicators**: Visual progress bars with live status updates
- 📝 **Comprehensive Logging**: Detailed logs saved automatically for troubleshooting
- ⚙️ **Configuration File Support**: Use JSON files to customize installation packages
- 🎯 **Android Studio Manual Install**: Faster script execution by prompting manual download
- 🔄 **Enhanced Error Handling**: Retry logic with exponential backoff for network issues
- 🔒 **Secure Downloads**: File integrity checks and certificate validation

### Development Setup

1. **Fork the repository**
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/dev-installation-scripts.git
   cd dev-installation-scripts
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Code Guidelines

#### PowerShell Best Practices

- Use meaningful variable names
- Add comments for complex logic
- Follow PowerShell naming conventions (Verb-Noun)
- Use proper error handling with try/catch blocks
- Test functions independently

#### Script Structure

- Keep functions focused and single-purpose
- Use consistent indentation (4 spaces)
- Group related functions together
- Add parameter validation where appropriate

#### Application Definitions

When adding new applications to the `$Applications` hashtable:

```powershell
"Application Name" = @{
    WingetId = "Publisher.Application"          # WinGet package ID
    ChocolateyId = "application-name"           # Chocolatey package ID
    DirectDownload = "https://example.com/download.exe"  # Direct download URL
    TestCommands = @("app --version 2>&1")      # Commands to verify installation
}
```

### Testing

1. **Test on a clean Windows VM** before submitting
2. **Verify all installation methods** work
3. **Test parameter combinations**
4. **Check error handling** for network failures

### Pull Request Process

1. **Update documentation** if adding new features
2. **Test thoroughly** on multiple Windows versions if possible
3. **Create a descriptive PR** with:
   - Clear title describing the change
   - Detailed description of what was changed
   - Screenshots if UI changes
   - Test results
4. **Reference issues** if applicable

### Adding New Applications

1. **Research installation methods**:

   - Check WinGet: `winget search "app name"`
   - Check Chocolatey: `choco search app-name`
   - Find official download URLs

2. **Add to `$Applications` hashtable** with all required fields

3. **Test installation** thoroughly

4. **Update README** with new application in features list

### Reporting Issues

When reporting bugs:

- Include Windows version and PowerShell version
- Describe the exact error message
- List which applications failed to install
- Include script output if possible

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚖️ Disclaimer

This script is provided as-is. While we strive for reliability, automatic installations can sometimes fail due to:

- Network connectivity issues
- Conflicting software
- System-specific configurations
- Changes in download URLs

Always review the script before running and consider testing in a virtual environment first.

## 🙏 Acknowledgments

- Microsoft for WinGet and PowerShell
- Chocolatey community for package management
- All the open-source projects that make development possible
