C:\Users\clynch\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
##############################################################################
# Server_Profile_Template_Multiconnection_Sample.ps1
#
# Example script to demonstrate creating a Server Profile Template
# with the following:
#
# - HPE Synery 480 Gen 10
# - Set BootMode to UEFIOptimized
# - Set PXEBootPolicy to IPv4
# - Configure 2 NICs in assigned to the Management VLAN
# - Configure 2 NICs for VM connectivity
# - Configure 2 HBAs for Shared Storage connectivity
# - Local Storage
# - Firmware management
#
# Then create a Server Profile from the Template, assigning to a specific
# server.
#
#   VERSION 4.0
#
# (C) Copyright 2013-2018 Hewlett Packard Enterprise Development LP 
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>
##############################################################################

if (-not (get-module HPOneview.400)) 
{

    lsvn400

}

if (-not ($ConnectedSessions | ? Name -eq "hpov7.doctors-lab.local"))
{

    Write-Host "Connecting to appliance."
    $MyConnection = Connect-HPOVMgmt -Hostname hpov7.doctors-lab.local -Credential $HPOVPSCredential

}

# View the connected HPE OneView appliances from the library by displaying the global $ConnectedSessions variable
$ConnectedSessions | Out-Host

pause

Get-HPOVLogicalEnclosure | Out-Host

# Now view what enclosures have been imported
Get-HPOVEnclosure | Out-Host

pause

# Now list all the servers that have been imported with their current state
Get-HPOVServer | out-Host

pause

# Next, show the avialble servers from the available Server Hardware Type
$SY480Gen10SHT = Get-HPOVServerHardwareType -name "SY 480 Gen10 1" -ErrorAction Stop
Get-HPOVServer -ServerHardwareType $SY480Gen10SHT -NoProfile | out-Host

$TemplateName        = "Hypervisor Cluster Node Template v1"
$TemplateDescription = "Corp standard hypervisor cluster node, version 1.0"
$eg                  = Get-HPOVEnclosureGroup -Name "DCS Synergy Default EG" -ErrorAction Stop 
$Baseline            = Get-HPOVBaseline -File SPP_2017_10_20171215_for_HPE_Synergy_Z7550-96455.iso
$con1                = Get-HPOVNetwork -Name "Management Network (VLAN1)" -ErrorAction Stop | New-HPOVServerProfileConnection -ConnectionID 1 -Name 'Management Network (VLAN1) Connection 1' -Bootable -Priority Primary
$con2                = Get-HPOVNetwork -Name "Management Network (VLAN1)" -ErrorAction Stop | New-HPOVServerProfileConnection -ConnectionID 2 -Name 'Management Network (VLAN1) Connection 2'
$con3                = Get-HPOVNetworkSet -Name 'Prod NetSet1' -ErrorAction Stop | New-HPOVProfileConnection -ConnectionId 3 -Name 'VM Traffic Connection 3'
$con4                = Get-HPOVNetworkSet -Name 'Prod NetSet1' -ErrorAction Stop | New-HPOVProfileConnection -ConnectionId 4 -Name 'VM Traffic Connection 4'
$con5                = Get-HPOVNetwork -Name "SAN A" -ErrorAction Stop | New-HPOVServerProfileConnection -ConnectionID 5 -Name 'Prod Fabric A Connection 5'
$con6                = Get-HPOVNetwork -Name "SAN B" -ErrorAction Stop | New-HPOVServerProfileConnection -ConnectionID 6 -Name 'Prod Fabric B Connection 6'
$LogicalDisk1        = New-HPOVServerProfileLogicalDisk -Name 'Disk 1' -RAID RAID1
$StorageController   = New-HPOVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk1

$params = @{
	Name               = $TemplateName;
	Description        = $TemplateDescription;
	ServerHardwareType = $SY480Gen10SHT;
	EnclosureGroup     = $eg;
	Connections        = $con1, $con2, $con3 ,$con4, $con5, $con6;
	Firmware           = $true;
	Baseline           = $Baseline;
	FirmwareMode       = 'FirmwareAndSoftware'
	BootMode           = "UEFIOptimized";
	PxeBootPolicy      = "IPv4";
	ManageBoot         = $True;
	BootOrder          = "HardDisk";
	LocalStorage       = $True;
	StorageController  = $StorageController;
	HideUnusedFlexnics = $True
}

# Create Server Profile Template
New-HPOVServerProfileTemplate @params | Wait-HPOVTaskComplete

# Get the created Server Profile Template
$spt = Get-HPOVServerProfileTemplate -Name $TemplateName -ErrorAction Stop
$spt | Out-Host

pause

# Create Server Profile from Server Profile Template, searching for a SY480 Gen10 server with at least 4 CPU and 512GB of RAM
Get-HPOVServer -ServerHardwareType $SY480Gen10SHT -NoProfile -ErrorAction Stop | ? { ($_.processorCount * $_.processorCoreCount) -ge 4 -and $_.memoryMb -ge (512 * 1024) } | Select -First 2 -OutVariable svr | out-Host

pause 

# Make sure servers are powered off
$svr | Stop-HPOVServer -Confirm:$false | Wait-HPOVTaskComplete | out-Host

# Create the number of Servers from the $svr collection
1..($svr.Count) | % {

	New-HPOVServerProfile -Name "Prod-HypClusNode-0$_" -Assignment Server -Server $svr[($_ - 1)] -ServerProfileTemplate $spt -Async

}

Get-HPOVTask -State Running | Wait-HPOVTaskComplete