### Author : Michel de CREVOISIER
### v1.50 - 2019-08-26
###
### Tested on: Server 2008 R2 (requires removal of <#Requires -RunAsAdministrator> line), Server 2012 R2, Server 2016 and Server 2019
### Script purpose: configure a Windows host as a Windows collector
### Script steps:
###     1-Enable Windows Event Collector Service
###     2-Configure WinRM service
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
}


###### 2-Configure WinRM service  ######
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
}

###### FINAL CONFIRMATION ######
write-host ""
write-host "#########################################" -foregroundcolor "green" 
write-host " WEC server role successfully configured" -foregroundcolor "green" 
write-host "#########################################" -foregroundcolor "green" 
write-host ""