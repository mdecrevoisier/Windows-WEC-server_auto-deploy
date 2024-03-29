# Windows Event Collector deployment toolkit
PowerShell script for fast Windows Event Collector server configuration.

## Project purpose
The scripts are intended to enhance the Windows Event Collector (WEC) server deployment. In short, it contains two PowerShell scripts that does the following actions:
* **1-Set-WEC-role**: enable the Windows Event Collector service, configure the WinRM service (with optional custom port) and fixes SDDL permissions on WinRM URL
* **2-Deploy-Toolkit**: import new event channels and crafted subscriptions to collect advanced Windows event logs from Windows Event Forwarding (WEF) clients. Moreover, it allows to automatically move each event channel to a dedicated disk and increase their default size for better processing.

## How to use the WEC toolkit
The scripts have to be executed on a future Windows Event collector server:
* 1-Configure your Windows Event Forwarding clients to target the required Windows Event Collector server (usually over GPO).
* 2-Download the package content.
* 3-Execute the script **1-Set-WEC-role** to configure the WEC server role.
* 5-Execute the script **2-Deploy-Toolkit** to import and configure all the event channels and subscriptions. 
* 7-Open the Windows Event Viewer and verify that your WEF clients are correctly reporting logs into the event channels.

## Demo overview
# 1-Set WEC role
![](/demo/1-Set-WEC-role.gif)

# 2-Deploy toolkit
![](/demo/2-Deploy-Toolkit.gif)

# 3-Event viewer overview
![](/demo/3-Event-viewer-overview.gif)

## Supported environment
The scripts have been tested on the following environments:
* Server 2008 R2
* Server 2012 R2
* Server 2016
* Server 2019

## Pending
[] Replace some PowerShell commands call with a direct "cmd /c" call
[] Add performance settings from [OTRF/Blacksmith](https://github.com/OTRF/Blacksmith/blob/master/resources/scripts/powershell/auditing/Configure-WEC.ps1)