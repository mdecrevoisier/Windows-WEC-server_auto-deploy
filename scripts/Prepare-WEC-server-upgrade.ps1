# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Author : Michel de CREVOISIER
### v1.00 - 2020/01/24
###
### Tested on: Server 2008 R2 (requires removal of <#Requires -RunAsAdministrator>), Server 2012 R2, Server 2016 and Server 2019
### Script purpose: remove all existing subscriptions in order to allow fresh toolkit installation
### Script steps:
###     1-Prompt for upgrade confirmation
###     2-Disable existing subscriptions
###     3-Delete all subscriptions


# Requires PowerShell console to run as an administrator (compatible with PowerShell v4 or higher only)
#Requires -RunAsAdministrator



###### 0-Important notes ######
write-host ""
write-host "########################## Please read those important notes ######################################" -foregroundcolor "green" 
write-host ""
write-host "     -WEC server will stop collecting logs during this operation"  -foregroundcolor "red" 
write-host "     -All existing subscriptions will be deleted (uses wecutil gs <subscription> /f:xml >> <subscription>.xml to export a subscription)"  -foregroundcolor "red" 
write-host "     -Once this operation is done, excecute script 2_Deploy-Toolkit to proceed with the toolkit installation"  -foregroundcolor "red" 
write-host ""
write-host "###################################################################################################" -foregroundcolor "green" 
write-host ""

###### 1-Prompt for confirmation upgrade ######
write-host ""
write-host "1-WEC toolkit upgrade preparation" -foregroundcolor "yellow"

# Prompt requesting for a confirmation
$Option_upgrade = Read-Host -Prompt "Confirm to proceed with WEC server preparation before upgrade (y/n)?" 

if ($Option_upgrade -eq "y") {
    Write-Host "Proceeding with upgrade preparation"  -foregroundcolor "green" 
    }
else {
    write-host "Upgrade preparation cancelled" -foregroundcolor "red" 
    Break
}


###### 2-Disable existing subscriptions ######
write-host ""
write-host "2-Disable existing subscriptions" -foregroundcolor "yellow"

# Init variables
$wecutil_init = "C:\Windows\System32\wecutil.exe"
$existing_subscriptions = wecutil.exe es

ForEach ($Subscription in $existing_subscriptions)
{
    write-host "Attempting to disable subscription: $Subscription" -foregroundcolor "yellow" 
    $wecutil_arg1 = "set-subscription $Subscription /e:False"
    $wecutil_exec1 = Start-Process $wecutil_init -ArgumentList $wecutil_arg1 -NoNewWindow -PassThru -Wait
    if ($wecutil_exec1.ExitCode -eq 0) {
        write-host "$Subscription subscription successfully disabled" -foregroundcolor "green" 
    }
    else {
        Write-Host "WECUTIL Exitcode:" $wecutil_exec1.ExitCode  -foregroundcolor "red" 
        }
}


###### 3-Delete all existing subscriptions ######
write-host ""
write-host "3-Delete all existing subscriptions" -foregroundcolor "yellow"

ForEach ($Subscription in $existing_subscriptions)
{
    write-host "Attempting to delete subscription: $Subscription" -foregroundcolor "yellow" 
    $wecutil_arg3 = "delete-subscription $Subscription"
    $wecutil_exec3 = Start-Process $wecutil_init -ArgumentList $wecutil_arg3 -NoNewWindow -PassThru -Wait
    if ($wecutil_exec3.ExitCode -eq 0) {
        write-host "$Subscription subscription successfully deleted" -foregroundcolor "green" 
    }
    else {
        Write-Host "WECUTIL Exitcode:" $wecutil_exec2.ExitCode  -foregroundcolor "red" 
        }
}


###### FINAL CONFIRMATION ######
write-host ""
write-host "#####################################################" -foregroundcolor "green" 
write-host "     WEC server successfully prepared for upgrade"  -foregroundcolor "green" 
write-host " Proceed now with script '2_Deploy-Toolkit' execution"  -foregroundcolor "red" 
write-host "#####################################################" -foregroundcolor "green" 
write-host ""