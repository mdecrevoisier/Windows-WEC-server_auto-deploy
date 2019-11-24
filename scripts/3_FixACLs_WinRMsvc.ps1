# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Author : Michel de CREVOISIER
### v1.51 - 2019-11-25
###
### Tested and applies only to: Server 2016 and Server 2019
### Script purpose: 
###         1. Fixes ACL permissions in case the collector service is configured to run in a separated process for performance reasons
###         2. Fix a new behavior in Server 2019 (with >3.5GB RAM) where svchost processes runs WinRM and WecSvc in separated processes
###         Source: https://support.microsoft.com/en-us/help/4494462/events-not-forwarded-if-the-collector-runs-windows-server-2019-or-2016
### Script steps:
###     1-Verify if WEC servers run Server 2016 or higher
###     2-Stop relavant services (NXLog agent, Collector and WinRM)
###     3-Delete and replace ACLs
###     4-Start relavant services (NXLog agent, Collector and WinRM)


# Requires PowerShell console to run as an administrator (compatible with PowerShell v4 or higher only)
#Requires -RunAsAdministrator


###### 1-Verify if WEC servers run Server 2016 or higher ######
write-host ""
write-host "1-Verifying if WEC servers run Server 2016 or higher" -foregroundcolor "yellow"

# Get version
$os_version = (Get-CimInstance Win32_OperatingSystem).version
# Server 2012 R2 = version number 6.3
# Server 2016 = version number v10.x
# Server 2019 = version number v10.x

if ($os_version -ge 10) {
    write-host "Compatible server version detected, continuing ..." -foregroundcolor "green" 
}
else {
    Write-Host "Incompatible server version detected, aborting"  -foregroundcolor "red" 
    Break
}


###### 2-Stopping dependant services ######

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

# Stop WinRM service
write-host ""
write-host "Stopping WinRM service" -foregroundcolor "Magenta"
Stop-Service WinRM

# Ensure that WinRM service is stopped
if (((Get-Service -Name WinRM).Status) -ne "Stopped") {
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


###### 3-Cleaning and setting proper ACLs for WinRM service ######

write-host ""
write-host "3-Cleaning and setting proper ACLs for WinRM service" -foregroundcolor "yellow"

## We delete existing URLs for WinRM
write-host ""
write-host "Deleting existing ACLs for WinRM" -foregroundcolor "Magenta"
cmd.exe /c "netsh http delete urlacl url=http://+:5985/wsman/"

write-host ""
write-host "Setting proper ACLs for WinRM" -foregroundcolor "Magenta"
cmd.exe /c "netsh http add urlacl url=http://+:5985/wsman/ sddl=D:(A;;GX;;;S-1-5-80-569256582-2953403351-2909559716-1301513147-412116970)(A;;GX;;;S-1-5-80-4059739203-877974739-1245631912-527174227-2996563517)"

write-host ""
write-host "Checking added ACLs" -foregroundcolor "Magenta"
$serviceUrlHttp = "http://+:5985/wsman/"
cmd.exe /c "netsh http show urlacl url=$serviceUrlHttp"


###### 4-Starting dependant services ######
write-host ""
write-host "4-Starting dependant services" -foregroundcolor "yellow"

## We start the WEC service 
write-host ""
write-host "Starting Event collector service" -foregroundcolor "Magenta"

Start-service Wecsvc
if (((Get-Service -Name wecsvc).Status) -ne "Running") {
    Write-Host "Collector Service not started, aborting"  -foregroundcolor "red" 
}
else {
    write-host "Collector service successfully started, continuing..." -foregroundcolor "green" 
}

## We start the WinRM service 
write-host ""
write-host "Starting WinRM  service" -foregroundcolor "Magenta"

Start-service WinRM
if (((Get-Service -Name WinRM).Status) -ne "Running") {
    Write-Host "WinRM service not started, aborting"  -foregroundcolor "red" 
}
else {
    write-host "WinRM service successfully started, continuing..." -foregroundcolor "green" 
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
write-host " ACLs on WinRM service successfully fixed"  -foregroundcolor "green" 
write-host "################################################" -foregroundcolor "green" 
write-host ""