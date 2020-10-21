# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Author : Michel de CREVOISIER
### v2.51 - 03/09/2020
###
### Tested on: Server 2008 R2 (requires removal of <#Requires -RunAsAdministrator> line), Server 2012 R2, Server 2016 and Server 2019
### Script purpose: configure a Windows host as a Windows collector server
### Script steps:
###     1-Enable Windows Event Collector service
###     2-Enable Windows Remote Management service
###     3-Prompt for switching (or not) to a custom port and create appropriate firewall rule
###     4-Fixes ACL permissions on WinRM URLs (https://support.microsoft.com/en-us/help/4494462/events-not-forwarded-if-the-collector-runs-windows-server-2019-or-2016)
###         4.1-Verify if WEC servers run Server 2016 or higher
###         4.2-Stop relavant services (NXLog agent, Collector and WinRM)
###         4.3-Delete and replace ACLs
###         4.4-Start relevant services (NXLog agent, Windows Collector and WinRM)
###


# Requires PowerShell console to run as an administrator (compatible with PowerShell v4 or higher only)
#Requires -RunAsAdministrator


###### 1-Enable Windows Event Collector Service ######
write-host ""
write-host "1-Enabling Windows Event collector service" -foregroundcolor "yellow"
$wecutil_init = "C:\Windows\System32\wecutil.exe"
$wecutil_arg = "qc -q"

# Start wecutil with args and reports
$wecutil_exec = Start-Process $wecutil_init -ArgumentList $wecutil_arg -NoNewWindow -PassThru -Wait
if ($wecutil_exec.ExitCode -eq 0) {
    write-host "Windows Event collector service successfully configured" -foregroundcolor "green" 
}
else {
    Write-Host "Windows Event collector configuration failure:" $wecutil_exec.ExitCode  -foregroundcolor "red" 
    Break
}



###### 2-Configure Windows Remote Management service ######
write-host ""
write-host "2-Configuring WinRM service" -foregroundcolor "yellow"
$winrm_init = "C:\Windows\System32\winrm.cmd"
$winrm_arg = "qc -q"

# Verifies WinRM is set to 'Automatic Startup' or sets it
if (((Get-Service -Name WinRM).StartType) -ne "Automatic") { Set-Service -Name WinRM -StartupType Automatic }

# Starts WinRM with Args
$winrm_exec = Start-Process $winrm_init -ArgumentList $winrm_arg -NoNewWindow -PassThru -Wait
if ($winrm_exec.ExitCode -eq 0) {
    write-host "WinRM Service service successfully configured" -foregroundcolor "green" 
}
else {
    Write-Host "WinRM Service configuration failure:" $winrm_exec.ExitCode -foregroundcolor "red" 
    Break
}



###### 3-Prompt for switching (or not) to a custom port and create appropriate firewall rule ######
write-host ""
write-host "3-Would you like to keep the default port (TCP 5985) or use a custom TCP port for the WinRM listener on the WEC server?" -foregroundcolor "yellow"

# Prompt requesting for choosing the port
$option_port_custom = Read-Host -Prompt "Changing the default WinRM port may allow to easily identify traffic related to log transport and also to apply traffic shaping rules (QoS). If you choose a customer port, the subscription manager target port defined in the GPO will need to be adjusted. Would you like to use a custom port (y/n)?" 

if ($option_port_custom -eq "y") {
    write-host ""
    write-host "CUSTOM port selected" -foregroundcolor "green" 

    # 3.1 Prompting for default port
    $winrm_port = Read-Host -Prompt "Enter the custom WinRM port (should be higher than > 1024, <65535 and not in use on this server)" 

    # 3.2 Verifying if provided port is valid
    if (($winrm_port -ge 1025) -and ($winrm_port -le 65535)) {
        write-host ""
        write-host "Valid port provided" -foregroundcolor "green" 
    }
    else {
        write-host ""
        Write-Host "Unvalid port provided, aborting"  -foregroundcolor "red" 
        Break
    }

    # 3.3 Changing to custom port
    $winrm_arg = "winrm set winrm/config/Listener?Address=*+Transport=HTTP '@{Port=""$winrm_port""}'"
    Invoke-Expression $winrm_arg

    # 3.4 Deleting former firewall rule in case previous config exists
    $wec_rule_name = "WinRM custom for WEC server"
    Remove-NetFirewallRule -DisplayName $wec_rule_name -ErrorAction Ignore

    # 3.5 Creating new firewall rule
    New-NetFirewallRule -DisplayName  $wec_rule_name -Direction Inbound -LocalPort $winrm_port -Protocol TCP -Action Allow | out-null
    write-host ""
    write-host "Custom firewall rule for WinRM successfully created" -foregroundcolor "green" 
}
elseif ($option_port_custom -eq "n") {
    write-host ""
    write-host "Keeping DEFAULT configuration" -foregroundcolor "green" 
    $winrm_port=5985
}
else {
    write-host ""
    Write-Host "Unknown option provided, aborting"  -foregroundcolor "red" 
    Break
}



###### 4-Updating SDDL permissions on WinRM listener (if necessary) ######
write-host ""
write-host "4.1-Verifying if WEC servers run Server 2016 or higher" -foregroundcolor "yellow"

# Get version
$os_version = (Get-CimInstance Win32_OperatingSystem).version
# Server 2012 R2 = version number 6.3
# Server 2016 = version number v10.x
# Server 2019 = version number v10.x

if ($os_version -ge 10) {
    write-host "Windows Server 2016 or higher detected. WinRM permissions need to be rewritten." -foregroundcolor "green" 

    ###### 4.2-Stopping dependant services ######

    write-host ""
    write-host "4.2-Stopping dependant services" -foregroundcolor "yellow"

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


    ###### 4.3-Cleaning and setting proper ACLs for WinRM service ######

    write-host ""
    write-host "4.3-Cleaning and setting proper ACLs for WinRM service" -foregroundcolor "yellow"

    ## We delete existing URLs for WinRM
    write-host ""
    write-host "Deleting existing ACLs for WinRM" -foregroundcolor "Magenta"
    cmd.exe /c "netsh http delete urlacl url=http://+:$winrm_port/wsman/"

    write-host ""
    write-host "Setting proper ACLs for WinRM" -foregroundcolor "Magenta"
    cmd.exe /c "netsh http add urlacl url=http://+:$winrm_port/wsman/ sddl=D:(A;;GX;;;S-1-5-80-569256582-2953403351-2909559716-1301513147-412116970)(A;;GX;;;S-1-5-80-4059739203-877974739-1245631912-527174227-2996563517)"

    write-host ""
    write-host "Checking added ACLs" -foregroundcolor "Magenta"
    $serviceUrlHttp = "http://+:$winrm_port/wsman/"
    cmd.exe /c "netsh http show urlacl url=$serviceUrlHttp"


    ###### 4.4-Starting dependant services ######
    write-host ""
    write-host "4.4-Starting dependant services" -foregroundcolor "yellow"

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
}
else {
    Write-Host "Windows Server 2012 R2 or lower detected, no permissions changes required."  -foregroundcolor "yellow" 
}



###### FINAL CONFIRMATION ######
write-host ""
write-host "#########################################" -foregroundcolor "green" 
write-host " WEC server role successfully configured" -foregroundcolor "green" 
write-host "#########################################" -foregroundcolor "green" 
write-host ""