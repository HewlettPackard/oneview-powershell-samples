## -------------------------------------------------------------------------------------------------------------
##
##
##      Description: Rename Local Area Connection with Virtual COnnect networks
##
## DISCLAIMER
## The sample scripts are not supported under any HP standard support program or service.
## The sample scripts are provided AS IS without warranty of any kind.
## HP further disclaims all implied warranties including, without limitation, any implied
## warranties of merchantability or of fitness for a particular purpose.
##
##
## Scenario
##     	Use OneView to get VC network names and rename Windows LAN names
##
##
## Input parameters:
##         OVApplianceIP      : Address of OneView appliance
##         OVAdminName        : name of OneView administrator
##         OVAdminPassword    : password of OneView administrator
##         OneViewModule      ; OneView PS modules - Minimum is HPOneView 1.20
##
##
## History:
##         March-2015: v1.0 - Initial release
##
## Contact: Dung.HoangKhac@hp.com


Param ( [string]$OVApplianceIP="10.254.1.20",
        [string]$OVAdminName="Administrator",
        [string]$OVAdminPassword="P@ssword1",
        [string]$OneViewModule = "HPOneView.120" # "C:\OneView\PowerShell\HPOneView.120.psm1"

       )

# -------------------------------------------------------------------------------------------------------------
#
#                  Main Entry
#
#
# -------------------------------------------------------------------------------------------------------------


# -----------------------------------
#    Always reload module

$LoadedModule = get-module $OneviewModule
if ($LoadedModule -ne $NULL)
{
    remove-module $OneviewModule
}

import-module $OneViewModule

$NetInfoArray =@()

# ---------------------------
# Get list of adapters with current name and MAC

$ListofAdapters = get-netadapter
foreach ($adapter in $ListofAdapters)
{
    $netinfo            = new-object -type psobject -Property @{MAC="";Oldnetname="";Newnetname=""}
    $netinfo.OldNetName = $adapter.Name
    $netinfo.MAC        = $adapter.macAddress -replace "-",":"

    $netInfoArray += $NetInfo
}

# -----------------------------
#  Get Serial Number

$ThisSN = (Get-WmiObject Win32_BIOS).SerialNumber.Trim()


# ---------------------------
# Connect to OneView appliance

write-host "`n Connect to the OneView appliance..."
Connect-HPOVMgmt -appliance $OVApplianceIP -user $OVAdminName -password $OVAdminPassword



# ----------------------------
# Find server using Serial Number

$ThisServer      = Get-HPOVServer | where SerialNumber -eq $ThisSN

# ----------------------------
# Get MAC address and network name from OneView

$spUri           = $ThisServer.ServerProfileUri

if (($spUri -ne $NULL) -and ($spUri.Startswith('/')) )
{
    $ThisProfile      = send-HPOVRequest -uri $spUri
    $Connections      = $ThisProfile.Connections | where FunctionType -eq "Ethernet"

    foreach ($conn in $Connections)
    {
       $ThisNetInfo            = $netinfoArray | where MAC -eq $($conn.mac)
       $ThisVCNet              = send-HPOVRequest $($conn.networkUri)

        $ThisNetInfo.NewNetName = $ThisVCnet.name
    }


}

# ---------------------------
#  Rename LAN network

foreach ($netinfo in $NetInfoArray)
{
    write-host -foreground Cyan "Renaming network $($netinfo.OldNetName) to new name --> $($netinfo.NewNetName)"

    rename-netadapter -name $netinfo.OldNetName -NewName $netinfo.NewNetName
}

Disconnect-HPOVMgmt
