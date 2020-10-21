# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Author : Michel de CREVOISIER
### v2.50 - 27/08/2020
###
### Tested on: Server 2008 R2 (requires removal of <#Requires -RunAsAdministrator>), Server 2012 R2, Server 2016 and Server 2019
### Script purpose: import custom channels and subscriptions to enhance Windows log collection
### Script steps:
###     1-Verify if configuration folders are present
###     2-Prompt for moving (or not) custom event logs to a separated hard drive
###     3-Stop dependant Windows services (NXLog and WEC)
###     4-Import custom channel structure
###     5-Move event log files to a separated hard drive (if requested)
###     6-Increase default log files size
###     7-Start relevant services (NXLog and Windows Collector)
###     8-Import custom subscriptions
###


# Requires PowerShell console to run as an administrator (compatible with PowerShell v4 or higher only)
#Requires -RunAsAdministrator


###### 1-Verify if configuration folders are present ######
write-host ""
write-host "1-Verifying configuration folders presence" -foregroundcolor "yellow"
if ((Test-Path windows-event-channels) -And (Test-Path wef-subscriptions_COMPACT) -And (Test-Path wef-subscriptions_STANDARD)){
    write-host "Configuration folders exist, continuing..." -foregroundcolor "green" 
}
else {
    Write-Host "Configuration folder(s) missing, aborting"  -foregroundcolor "red" 
    Break
}


###### 2-Prompt for moving (or not) custom event logs to a separated hard drive ######
write-host ""
write-host "3-Moving custom event log files to a separated hard drive?" -foregroundcolor "yellow"

# Prompt requesting for moving custom (or not) event log to a separated hard drive
$Option_custom_location = Read-Host -Prompt "It is recommended to move the new custom event log files to a separated hard drive. Would like to proceed with this recommended approach (y/n)?" 

if ($Option_custom_location -eq "y") {
    $LogFolderPath = Read-Host -Prompt "Enter the folder path located on a separated hard drive" 

    # if $LogFolderPath does not end with a "\", we had a it
    if ($LogFolderPath -notmatch '.+?\\$'){
        $LogFolderPath += '\'
        write-host $LogFolderPath
    }

    write-host "Verifying path..." -foregroundcolor "yellow" 
    if ((Test-Path $LogFolderPath) -And (Test-Path $LogFolderPath -PathType Container)){
        write-host "Path is valid, continuing..." -foregroundcolor "green" 
    }
    else {
        Write-Host "Path is not valid or does not exist, aborting"  -foregroundcolor "red" 
        Break
    }
}
else {
    write-host "Keeping custom event log files in the default location C:\Windows\System32\winevt\Logs\" -foregroundcolor "magenta" 
}



###### 3-Prompt for choosing standard or compact toolkit mode ######
write-host ""
write-host "2-Would you like to go with 'standard' or 'compact' toolkit mode?" -foregroundcolor "yellow"

# Prompt requesting for choosing the toolkit mode
$Option_toolkit_mode = Read-Host -Prompt "Standard mode is the default and most suitable mode for most organization with less than 500 source clients. 
In case of having more than 500 source clients reporting to this WEC collector, choose the compact mode. More informations in documentation, point 3.10.
Would like to go with 'standard'(s) or 'compact' (c) mode deployement (s/c)?" 

if ($Option_toolkit_mode -eq "s") {
    write-host "STANDARD mode selected" -foregroundcolor "green" 
    $Subscription_folder_path = "..\wef-subscriptions_STANDARD" 
}
elseif ($Option_toolkit_mode -eq "c") {
    write-host "COMPACT mode selected" -foregroundcolor "green" 
    $Subscription_folder_path = "..\wef-subscriptions_COMPACT" 
}
else {
    Write-Host "Unknown option provided, aborting"  -foregroundcolor "red" 
    Break
}



###### 4-Stopping dependant services ######
# In case there's a third party agent for collecting logs, it shall be stopped. Here NXLog is used as an example. 

write-host ""
write-host "4-Stopping dependant services" -foregroundcolor "yellow"

# Stop Event log collector service
write-host ""
write-host "Stopping Event collector service" -foregroundcolor "Magenta"
Stop-Service Wecsvc

# Ensure that collector service is stopped
if (((Get-Service -Name wecsvc).Status) -ne "Stopped") {
    Write-Host "Collector Service not stopped, aborting"  -foregroundcolor "red" 
    Break
}

# Stop NXLog service (if exists)
$nxlog_service = "nxlog"
if (Get-Service $nxlog_service -ErrorAction SilentlyContinue) {
    if (((Get-Service -Name $nxlog_service).Status) -ne "Stopped") {
        write-host "Stopping NXLog service" -foregroundcolor "Magenta"
        Stop-Service $nxlog_service
        
        # Ensure that NXLog service is stopped
        if (((Get-Service -Name $nxlog_service).Status) -ne "Stopped") {
            Write-Host "NXLog Service not stopped, aborting"  -foregroundcolor "red" 
            Break
        }
    }
}



###### 5-Import custom channel structure ######
write-host ""
write-host "5-Importing custom channel structure" -foregroundcolor "yellow"


# Unload the current Event Channel structure (if existing)
if (Test-Path C:\windows\system32\CustomEventChannels.man){
    write-host ""
    write-host "Unloading default channel structure" -foregroundcolor "Magenta"
    wevtutil uninstall-manifest C:\windows\system32\CustomEventChannels.man
    write-host "Successfully unloaded channel structure" -foregroundcolor "green" 
}

# Overwrite channel structure files
write-host ""
write-host "Copying custom channel structure files" -foregroundcolor "Magenta"
Set-Location "windows-event-channels"
if ((Test-Path CustomEventChannels.dll) -And (Test-Path CustomEventChannels.man)){
    Copy-Item CustomEventChannels.dll C:\Windows\system32\
    Copy-Item CustomEventChannels.man C:\Windows\system32\
}
else {
    Write-Host "Source files missing, aborting"  -foregroundcolor "red" 
	Break
}

# Load the new Event channel structure
write-host ""
write-host "Loading custom channel structure" -foregroundcolor "Magenta"
wevtutil im C:\windows\system32\CustomEventChannels.man
write-host "Successfully loaded channel structure" -foregroundcolor "green" 


###### 6-Move all event log files to a separated hard drive ######

$EventLogs = wevtutil enum-logs | select-string -pattern "WEC"
$wevtutil_init = "C:\Windows\System32\wevtutil.exe"

if ($Option_custom_location -eq "y") {

    write-host ""
    write-host "4-Moving custom event log files to path: $LogFolderPath"  -foregroundcolor "yellow"

    foreach($EventLog in $EventLogs)
    {
        $full_path = $LogFolderPath + $EventLog + ".evtx"
        $wevtutil_arg_move = "sl $EventLog /lfn:$full_path"
        $wevtutil_exec_move = Start-Process $wevtutil_init -ArgumentList $wevtutil_arg_move -NoNewWindow -PassThru -Wait
        if ($wevtutil_exec_move.ExitCode -eq 0) {
                write-host "$EventLog event log successfully moved" -foregroundcolor "green" 
            }
            else {
                Write-Host "WEVTUTIL Exitcode:" $wevtutil_exec_move.ExitCode  -foregroundcolor "red" 
                }
    }
}


###### 7-Increasing custom event log file size ######
write-host ""
write-host "7-Increasing custom event log file size" -foregroundcolor "yellow"

# 6.1 Increase all custom event log file size to 128MB
write-host ""
write-host "   7.1-Increasing all log files size to 128 MB" -foregroundcolor "yellow"
foreach($EventLog in $EventLogs)
{
    $log_size_default = 134217728 # 128MB defined in KB
    $wevtutil_arg_size = "sl $EventLog /ms:$log_size_default"
    $wevtutil_exec_size = Start-Process $wevtutil_init -ArgumentList $wevtutil_arg_size -NoNewWindow -PassThru -Wait
    if ($wevtutil_exec_size.ExitCode -eq 0) {
            write-host "$EventLog event log size was successfully increased to $log_size_default Bytes" -foregroundcolor "green" 
        }
        else {
            Write-Host "WEVTUTIL failed to resied the event log:" $wevtutil_exec_size.ExitCode  -foregroundcolor "red" 
            }
}

# 6.2-Increasing high usage log files to higher size
write-host ""
write-host "   7.2-Increasing high usage log files to higher size" -foregroundcolor "yellow"

# Verify CSV path
write-host ""
write-host "Verifying CSV file..." -foregroundcolor "yellow" 
$CSV_file = "custom_log_size_settings.csv"
    if ((Test-Path $CSV_file) -And (Test-Path $CSV_file -PathType leaf)){
        write-host "CSV file is valid, continuing..." -foregroundcolor "green" 
        write-host ""
    }
    else {
        Write-Host "CSV file is not valid or does not exist, aborting"  -foregroundcolor "red" 
        Break
    }

# Import CSV file and increase size
$Imported_CSV_file = Import-Csv $CSV_file
ForEach ($item in $Imported_CSV_file){ 
    $EventLog = $($item.Log_name)
    $High_Log_Size = $($item.Log_size_in_Bytes)

    # Increase size
    $wevtutil_arg_size = "sl $EventLog /ms:$High_Log_Size"
    $wevtutil_exec_size = Start-Process $wevtutil_init -ArgumentList $wevtutil_arg_size -NoNewWindow -PassThru -Wait
    if ($wevtutil_exec_size.ExitCode -eq 0) {
            write-host "$EventLog event log size was successfully increased to $High_Log_Size Bytes" -foregroundcolor "green" 
        }
        else {
            Write-Host "WEVTUTIL failed to resied the event log:" $wevtutil_exec_size.ExitCode  -foregroundcolor "red" 
            }


}


###### 8-Starting dependant services ######
write-host ""
write-host "8-Starting dependant services" -foregroundcolor "yellow"

## We start the WEC service before importing the subscriptions
write-host ""
write-host "Starting Event collector service" -foregroundcolor "Magenta"

Start-service Wecsvc
if (((Get-Service -Name wecsvc).Status) -ne "Running") {
    Write-Host "Collector Service not started, aborting"  -foregroundcolor "red" 
}
else {
    write-host "Collector service successfully started, continuing..." -foregroundcolor "green" 
}

## We start the NXLog service
if (Get-Service $nxlog_service -ErrorAction SilentlyContinue) {
    write-host ""
    write-host "Starting NXLog service" -foregroundcolor "Magenta"

    Start-service $nxlog_service
    if (((Get-Service -Name $nxlog_service).Status) -ne "Running") {
        Write-Host "NXLog service could not be started. Requires manual start"  -foregroundcolor "red" 
        write-host ""
    }
    else {
        write-host "NXLog service successfully started, continuing..." -foregroundcolor "green" 
        write-host ""
    }
}


###### 9-Importing WEC subscriptions ######
write-host ""
write-host "9-Importing WEC subscriptions" -foregroundcolor "yellow"

#Import all XML subscriptions
Set-Location $Subscription_folder_path
$wecutil_init = "C:\Windows\System32\wecutil.exe"

ForEach ($Subscription in Get-ChildItem *.xml)
{
    write-host "Attempting to import subscription: $Subscription" -foregroundcolor "yellow"
    $wecutil_arg2 = "create-subscription $Subscription"
    $wecutil_exec2 = Start-Process $wecutil_init -ArgumentList $wecutil_arg2 -NoNewWindow -PassThru -Wait
    if ($wecutil_exec2.ExitCode -eq 0) {
        write-host "$Subscription subscription successfully imported" -foregroundcolor "green" 
    }
    else {
        Write-Host "WECUTIL Exitcode:" $wecutil_exec2.ExitCode  -foregroundcolor "red" 
        }
}



###### FINAL CONFIRMATION ######
write-host ""
write-host "################################################" -foregroundcolor "green" 
write-host " WEC toolkit deployment successfully performed"  -foregroundcolor "green" 
write-host "################################################" -foregroundcolor "green" 
write-host ""