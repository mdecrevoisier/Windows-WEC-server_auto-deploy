# Windows Event Collector deployment script
PowerShell script for fast Windows Event Collector server configuration together with Palantir toolset.

## Script purpose
The scripts are intended to enhance the Windows Event Collector (WEC) server deployment together with the toolset provided by Palantir. In short, it contains two PowerShell scripts that does the following actions:
* **Set-WEC-role**: enable the Windows Event Collector service, configure the WinRM service (with optional custom port) and fixes SDDL permissions on WinRM URL
* **Deploy-Toolkit**: import new event channels and crafted subscriptions to collect advanced Windows event logs from Windows Event Forwarding (WEF) clients. Moreover, it allows to automatically move each event channel to a dedicated disk and increase their default size for better processing.

## How to use the scripts
The scripts have to be executed on a future Windows Event collector server:
* 1-Configure your Windows Event Forwarding clients to target the required Windows Event Collector server (usually over GPO).
* 2-Download the PowerShell scripts (+ the CSV configuration file) provided in this repository.
* 3-Download the repository from [Palantir](https://github.com/palantir/windows-event-forwarding.git) and place its content into the previously downloaded repository.
* 4-Execute the script **Set-WEC-role** to configure the WEC server role.
* 5-Execute the script **Deploy-Toolkit** to import and configure all the event channels and subscriptions from Palantir. 
* 7-Open the Windows Event Viewer and verify that your WEF clients are correctly reporting logs into the event channels.

## Demo overview
# Set WEC role
![](/demo/1-Set-WEC-role.gif)

# Deploy toolkit
![](/demo/2-Deploy-Toolkit.gif)

## Supported environment
The scripts have been tested on the following environments:
* Server 2008 R2
* Server 2012 R2
* Server 2016
* Server 2019
