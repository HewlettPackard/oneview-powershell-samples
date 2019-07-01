 # Copyright 2018 Hewlett Packard Enterprise Development LP
 #
 # Licensed under the Apache License, Version 2.0 (the "License"); you may
 # not use this file except in compliance with the License. You may obtain
 # a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 # WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 # License for the specific language governing permissions and limitations
 # under the License.
 
# Specify the firmware update mode.  Allowed values:
# FirmwareAndOSDrivers - Updates the firmware and OS drivers without powering down the server hardware using Smart Update Tool. 
# FirmwareOnly - Updates the firmware without powering down the server hardware using Smart Update Tool. 
# FirmwareOnlyOfflineMode - Manages the firmware through HPE OneView. Selecting this option requires the server hardware to be powered down. 
# -------------- Attributes for ServerProfileTemplate "UEFI Boot Template"
$name                       = "UEFI Boot Template"
$shtName                    = "SY 480 Gen10 1"
$sht                        = Get-HPOVServerHardwareType -Name $shtName
$egName                     = "EG 3 frames"
$eg                         = Get-HPOVEnclosureGroup -Name $egName
$affinity                   = "Bay"
# -------------- Attributes for BIOS Boot Mode settings
$manageboot                 = $True
$biosBootMode               = "UEFI"
$secureBoot                 = "Disabled"
# -------------- Attributes for BIOS order settings
$bootOrder                  = "PXE"
# -------------- Attributes for BIOS settings
$biosSettings               = @(
	@{id = 'Ipv4PrimaryDNS'; value = '192.168.101.1'},
	@{id = 'Ipv4Gateway'; value = '192.168.101.1'},
	@{id = 'Dhcpv4'; value = 'Disabled'},
	@{id = 'Ipv4SubnetMask'; value = '255.255.255.0'},
	@{id = 'Ipv4Address'; value = '192.168.101.215'},
	@{id = 'UrlBootFile'; value = 'http://192.168.101.23/isos/rhel7.6.iso'}
)
# -------------- Attributes for advanced settings
New-HPOVServerProfileTemplate -Name $name -ServerHardwareType $sht -EnclosureGroup $eg -Affinity $affinity  -ManageConnections $False -ManageBoot:$manageboot -BootMode $biosBootMode -SecureBoot $secureBoot -BootOrder $bootOrder -Bios -BiosSettings $biosSettings -HideUnusedFlexNics $true
