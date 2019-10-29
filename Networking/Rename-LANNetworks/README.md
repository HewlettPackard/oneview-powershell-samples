### Overview

The PowerShell script `Rename-LANnetworks` renames Ethernet connections on a Windows OS server using names defined in HP OneView Ethernet networks.

#### Use case

When you install the Windows OS on a given BL server, Windows enumerates the NICs present on the system and name the network connection as `Ethernet Connection ##`.

If your Blade server is managed by OneView, you may have already create networks in the appliance and follow a naming standard for your virtual networks. It would be great if Ethernet connections were named with the same naming convention.

#### Pre-requisites

* HP OneView appliance v1.20 or above
* Enclosure managed by HP OneView
* At least the Server Administrator role to access HP OneView
* PowerShell v3.0 or greater
* [HP OneView PowerShell 1.20 Library] (https://github.com/HewlettPackard/POSH-HPOneView/releases) installed

#### Description

The script is executed locally on the Blade server after the OS installation completed.

It performs the following tasks:

* Use a WMI query to collect the Serial Number of the server (`Win32_BIOS`)
* Connect to the HP OneView appliance
* Using the Serial Number as search key, locate the Blade Server.
* Collect all network connections of this Blade
* Locate the name and MAC address of the network connection
* Rename the Ethernet connection with name of Ethernet network using MAC address as Index key

The script is executed locally on the Blade server after the OS installation completed.

#### PowerShell script

Log in to the Blade Server after the installation. Execute the script as follow:

<pre>.\Rename-LANnetworks.ps1 -OVApplianceIP 10.254.1.20  OVAdminName this_user  OVAdminPassword this_password  OneViewModule HPOneView.120</pre>

<img src="https://raw.githubusercontent.com/wiki/HewlettPackard/POSH-HPOneView/Examples/icon_download.png"/>[Download Script Source] (https://github.com/HewlettPackard/POSH-HPOneView/wiki/Examples/Rename-LANnetworks.zip)