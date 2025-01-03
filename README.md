# Panopto Version Checker & Updater

A PowerShell utility that checks and updates Panopto software installations across Windows machines. The tool verifies installed versions of Panopto Recorder and Remote Recorder against specified versions and performs updates when needed.

## Features

- Version checking for Panopto applications
- Detailed version information including:
  - Current installed versions
  - Required versions
  - Installation status
- Installation handling
- Logging
- Error handling

## Prerequisites

- Windows 11 or later
- PowerShell 5.1 or later
- Administrative privileges
- Network access to Panopto download servers

## Configuration

The script uses a `.env` file for configuration. **Important**: Panopto administrators must manually update this file with the current version numbers and download URLs available from their Panopto server:

```ini
# Required versions - Update these with current version numbers from Panopto
RECORDER_VERSION=12.0.4.00087
REMOTE_RECORDER_VERSION=12.0.4.00087

# Installation paths
RECORDER_PATH=C:\Program Files\Panopto\Recorder\Recorder.exe
REMOTE_RECORDER_PATH=C:\Program Files\Panopto\Remote Recorder\RemoteRecorder.exe

# Download URLs - Update these with current download URLs from Panopto
RECORDER_URL=https://your-panopto-server/download/recorder
REMOTE_RECORDER_URL=https://your-panopto-server/download/remote-recorder
```

To update the configuration:
1. Log into your Panopto server's admin interface
2. Locate the current version numbers and download URLs for both applications
3. Update the `.env` file with these values
4. Run the script to apply updates

## Usage

Run the script with administrative privileges after updating the `.env` file with current version information:

```powershell
.\Update-PanoptoSoftware.ps1
```

## Output

The script generates a timestamped log file containing:
- Version checks
- Installation attempts
- Success/failure status
- Error messages

## Example Output
```
[2024-01-20 10:15:30] [Info] Version check for Panopto Recorder - Required: 12.0.4.00087, Installed: 12.0.4.00087
[2024-01-20 10:15:30] [Info] Panopto Recorder is up to date
[2024-01-20 10:15:31] [Info] Version check for Panopto Remote Recorder - Required: 12.0.4.00087, Installed: 12.0.4.00087
[2024-01-20 10:15:31] [Info] Panopto Remote Recorder is up to date
```

## Notes

- This script requires manual updates to the `.env` file with current version information
- Version numbers and download URLs must be obtained from your Panopto administrator or server
- The script performs silent installations to avoid user interruption
- Includes error handling for network and installation issues
- Creates detailed logs for troubleshooting
- Cleans up temporary files after execution
- Requires administrative privileges for installation

## Error Handling

The script includes comprehensive error handling for:
- Network connectivity issues
- Installation failures
- File system errors
- Version mismatches
- Missing configuration

## License

[MIT License](LICENSE)