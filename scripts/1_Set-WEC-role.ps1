# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Author : Michel de CREVOISIER
### v1.51 - 2019-11-22
###
### Tested on: Server 2008 R2 (requires removal of <#Requires -RunAsAdministrator>), Server 2012 R2, Server 2016 and Server 2019
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
