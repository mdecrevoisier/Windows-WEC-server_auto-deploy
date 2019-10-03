# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Author : Michel de CREVOISIER
### v1.50 - 2019-09-25
###
### Tested on: Server 2008 R2 (requires removal of <#Requires -RunAsAdministrator> line), Server 2012 R2, Server 2016 and Server 2019
### Script purpose: move event log files to another location
### Script steps:
###     1-Prompt for moving (or not) custom event logs to a separated hard drive
###     2-Stop dependant Windows services (NXLog and WEC)
###     3-Move event log files to a separated hard drive (if requested)
###     4-Start dependant Windows services (NXLog and WEC)
###


# Requires PowerShell console to run as an administrator (compatible with PowerShell v4 or higher only)
#Requires -RunAsAdministrator


###### 1-Prompt for moving (or not) custom event logs to a separated hard drive ######
write-host ""
write-host "1-Moving custom event log files to a separated hard drive?" -foregroundcolor "yellow"

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


###### 2-Stopping dependant services ######
# In case there's a third party agent for collecting logs, it shall be stopped. Here NXLog is used as an example. 

write-host ""
write-host "2-Stopping dependant services" -foregroundcolor "yellow"

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





###### 3-Move all event log files to a separated hard drive ######

$EventLogs = wevtutil enum-logs | select-string -pattern "WEC"
$wevtutil_init = "C:\Windows\System32\wevtutil.exe"

if ($Option_custom_location -eq "y") {

    write-host ""
    write-host "3-Moving custom event log files to path: $LogFolderPath"  -foregroundcolor "yellow"

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




###### 4-Starting dependant services ######
write-host ""
write-host "4-Starting dependant services" -foregroundcolor "yellow"

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



###### FINAL CONFIRMATION ######
write-host ""
write-host "################################################" -foregroundcolor "green" 
write-host " Event log files successfully moved"  -foregroundcolor "green" 
write-host "################################################" -foregroundcolor "green" 
write-host ""