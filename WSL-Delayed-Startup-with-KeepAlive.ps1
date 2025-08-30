# File: WSL-Delayed-Startup-with-KeepAlive.ps1

# --- Build configurations ---
# Note: Adjust these variables as needed
$taskName = "WSL Delayed Startup"
$distro   = "Ubuntu"    # <-- change if needed: run `wsl -l -v` to confirm
$delay    = "PT2M"      # <-- ISO8601: PT2M = 2 minutes (single configuration)

# --- Helper function to convert ISO8601 to seconds ---
function Convert-ISO8601ToSeconds {
    param([string]$iso8601)
    
    # Simple parser for PT format (e.g., PT2M, PT30S, PT1H30M)
    if ($iso8601 -match '^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$') {
        $hours = if ($matches[1]) { [int]$matches[1] } else { 0 }
        $minutes = if ($matches[2]) { [int]$matches[2] } else { 0 }
        $seconds = if ($matches[3]) { [int]$matches[3] } else { 0 }
        return ($hours * 3600) + ($minutes * 60) + $seconds
    }
    
    # Fallback to configured delaySeconds if parsing fails
    Write-Warning "Could not parse delay '$iso8601', using fallback delay of $delaySeconds seconds"
    return $delaySeconds
}

# --- Build scheduled task ---
# 1) Check if OS supports task delays first
$trigger = New-ScheduledTaskTrigger -AtLogOn
$delaySupported = $false

try { 
    $trigger.Delay = $delay
    $delaySupported = $true
    Write-Host "OS supports task delay - using native delay: $delay" -ForegroundColor Cyan
} catch { 
    Write-Host "OS does not support task delay - will use Start-Sleep fallback" -ForegroundColor Yellow
}

# 2) Action: Use PowerShell to start WSL with hidden window
# Note: Using Start-Process with -WindowStyle Hidden to avoid flashing console window

# 2.A) Build the PowerShell arguments - include Start-Sleep only if delay is not supported
$command = @"
Start-Process ``
  -FilePath wsl.exe ``
  -ArgumentList '--distribution', '$distro', '--exec', 'sleep', 'infinity' ``
  -WindowStyle Hidden
"@
$psArguments = "/c start /min powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -EncodedCommand"

if (-not $delaySupported) {
    # Native delay supported - no need for Start-Sleep
    $parsedDelaySeconds = Convert-ISO8601ToSeconds -iso8601 $delay
    $command = "[System.Threading.Thread]::Sleep($parsedDelaySeconds * 1000); $command"
}

# 2.B) Encode the command as Base64
$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

# 2.C) Build the scheduled task action
$action = New-ScheduledTaskAction `
  -Execute "cmd.exe" `
  -Argument "$psArguments $encodedCommand"

# 3) Principal: run under current user, only when logged on (interactive)
# Note: RunLevel Limited to avoid UAC prompts
$principal = New-ScheduledTaskPrincipal -UserId $env:UserName -LogonType Interactive -RunLevel Limited

# 4) Settings: Help ensure the task runs smoothly under various conditions
# Note: flags are set to allow:
#       Running on battery
#       Don't stop if going on battery
#       Start the task as soon as possible if it was missed
#       Ignore new instances if the task is already running
$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -MultipleInstances IgnoreNew `
  -Hidden

# --- Remove old task ---
# Note: Unregistering the task if it already exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  Write-Host "Removed existing task '$taskName'" -ForegroundColor Yellow
}

# --- Register the newly-built task ---
# Note: This will create the task if it doesn't exist, or update it if it does
Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Principal $principal `
  -Settings $settings `
  -Description "Start WSL with KeepAlive infinity sleep after delay post-logon to eliminate effect on startup speed. Uses native delay if supported, otherwise Thread Sleep fallback."

# --- Confirmation Message ---
$delayMethod = if ($delaySupported) { "native OS delay ($delay)" } else { "Thread Sleep fallback ($parsedDelaySeconds seconds)" }
Write-Host "Task '$taskName' registered successfully using $delayMethod!" -ForegroundColor Green
Write-Host "The task will start WSL distribution '$distro' after user logon." -ForegroundColor Green