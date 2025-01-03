#Requires -Version 5.1

param(
    [string]$EnvFile = (Join-Path $PSScriptRoot ".env")
)

<#
.SYNOPSIS
    Panopto software version checker and updater script.
.DESCRIPTION
    Checks and updates Panopto Recorder and RemoteRecorder installations in an enterprise environment.
    Verifies installed versions against specified versions and performs updates when needed.
.PARAMETER EnvFile
    Optional path to the .env configuration file. If not specified, defaults to .env in the script directory.
.NOTES
    Version:        1.0
    Author:         Richard Perez Jr.
    Creation Date:  2025-01-03
    Purpose/Change: Initial version - Implements version checking and installation
                    of Panopto Recorder and Remote Recorder software
#>

# Self-elevation mechanism
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Host "Script requires elevation. Attempting to restart with administrative privileges..." -ForegroundColor Yellow
    $arguments = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    if ($EnvFile) {
        $arguments += " -EnvFile `"$EnvFile`""
    }
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Set strict mode and error action
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize Script Variables
$script:logFile = Join-Path $PSScriptRoot "PanoptoUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:tempDir = Join-Path $env:TEMP "PanoptoUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Info','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:logFile -Value $logMessage
    
    switch ($Level) {
        'Info'    { Write-Host $logMessage }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
    }
}

function Initialize-Environment {
    try {
        Write-Log "Starting environment initialization"
        
        # Create temp directory if it doesn't exist
        if (-not (Test-Path $script:tempDir)) {
            New-Item -ItemType Directory -Path $script:tempDir | Out-Null
            Write-Log "Created temporary directory: $script:tempDir"
        }
        
        # Load .env file
        if (-not (Test-Path $EnvFile)) {
            throw "Required .env file not found at path: $EnvFile"
        }
        
        $envContent = Get-Content $EnvFile | Where-Object { $_ -match '^[^#]' }
        $script:config = @{}
        
        foreach ($line in $envContent) {
            if ($line -match '^\s*([^=]+)=(.*)$') {
                $script:config[$Matches[1].Trim()] = $Matches[2].Trim()
            }
        }
        
        # Validate required configuration values
        $requiredKeys = @(
            'RECORDER_VERSION',
            'REMOTE_RECORDER_VERSION',
            'RECORDER_URL',
            'REMOTE_RECORDER_URL',
            'RECORDER_PATH',
            'REMOTE_RECORDER_PATH'
        )
        
        foreach ($key in $requiredKeys) {
            if (-not $script:config.ContainsKey($key)) {
                throw "Missing required configuration key: $key"
            }
        }
        
        Write-Log "Environment initialization completed successfully"
    }
    catch {
        Write-Log "Failed to initialize environment: $_" -Level Error
        throw
    }
}

function Get-InstalledVersion {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        if (Test-Path $FilePath) {
            $version = (Get-Item $FilePath).VersionInfo.ProductVersion
            Write-Log "Retrieved version $version for $FilePath"
            return $version
        }
        Write-Log "Application not found at path: $FilePath" -Level Warning
        return $null
    }
    catch {
        Write-Log ("Error getting version for {0}: {1}" -f $FilePath, $_.Exception.Message) -Level Error
        return $null
    }
}

function Download-Installer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    try {
        Write-Log "Starting download from $Url"
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        
        Write-Log "Successfully downloaded installer to $OutputPath"
        return $true
    }
    catch {
        Write-Log "Download failed: $_" -Level Error
        return $false
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

function Install-Software {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InstallerPath,
        [Parameter(Mandatory=$true)]
        [string]$ProductName
    )
    
    try {
        Write-Log "Starting installation of $ProductName"
        
        $process = Start-Process -FilePath $InstallerPath -ArgumentList "/quiet", "/norestart" -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
        
        Write-Log "Successfully installed $ProductName"
        return $true
    }
    catch {
        Write-Log "Installation failed: $_" -Level Error
        return $false
    }
}

function Clean-Environment {
    try {
        Write-Log "Starting cleanup"
        
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force
            Write-Log "Removed temporary directory"
        }
        
        Write-Log "Cleanup completed successfully"
    }
    catch {
        Write-Log "Cleanup failed: $_" -Level Warning
    }
}

# Main execution block
try {
    Write-Log "Starting Panopto software update process"
    
    Initialize-Environment
    
    # Check and update Recorder
    $recorderVersion = Get-InstalledVersion -FilePath $script:config.RECORDER_PATH
    $installedRecorderVersion = if ($recorderVersion) { $recorderVersion } else { 'Not Installed' }
    Write-Log "Version check for Panopto Recorder - Required: $($script:config.RECORDER_VERSION), Installed: $installedRecorderVersion" -Level Info
    
    if ($recorderVersion -ne $script:config.RECORDER_VERSION) {
        Write-Log "Version mismatch detected for Panopto Recorder - Update needed" -Level Warning
        $recorderInstaller = Join-Path $script:tempDir "PanoptoRecorder.exe"
        if (Download-Installer -Url $script:config.RECORDER_URL -OutputPath $recorderInstaller) {
            Install-Software -InstallerPath $recorderInstaller -ProductName "Panopto Recorder"
        }
    } else {
        Write-Log "Panopto Recorder is up to date" -Level Info
    }
    
    # Check and update Remote Recorder
    $remoteRecorderVersion = Get-InstalledVersion -FilePath $script:config.REMOTE_RECORDER_PATH
    $installedRemoteVersion = if ($remoteRecorderVersion) { $remoteRecorderVersion } else { 'Not Installed' }
    Write-Log "Version check for Panopto Remote Recorder - Required: $($script:config.REMOTE_RECORDER_VERSION), Installed: $installedRemoteVersion" -Level Info
    
    if ($remoteRecorderVersion -ne $script:config.REMOTE_RECORDER_VERSION) {
        Write-Log "Version mismatch detected for Panopto Remote Recorder - Update needed" -Level Warning
        $remoteRecorderInstaller = Join-Path $script:tempDir "PanoptoRemoteRecorder.exe"
        if (Download-Installer -Url $script:config.REMOTE_RECORDER_URL -OutputPath $remoteRecorderInstaller) {
            Install-Software -InstallerPath $remoteRecorderInstaller -ProductName "Panopto Remote Recorder"
        }
    } else {
        Write-Log "Panopto Remote Recorder is up to date" -Level Info
    }
    
    Write-Log "Software update process completed successfully"
}
catch {
    Write-Log "Software update process failed: $_" -Level Error
    exit 1
}
finally {
    Clean-Environment
} 