###  Connect to OPneView 'master'
Connect-HPOVMgmt -Hostname <master-IP-Address> -username administrator -Password <password>

## Generate network scripts
Get-HPOVNetWork | ConvertTo-HPOVPowerShellScript > net.ps1

## Generate network set scripts
Get-HPOVNetworkSet | ConvertTo-HPOVPowerShellScript > netset.ps1

## Generate LIG scripts
Get-HPOVLogicalInterconnectGroup | ConvertTo-HPOVPowerShellScript > lig.ps1

## Generate EG scripts
Get-HPOVEnclosureGroup | ConvertTo-HPOVPowerShellScript > eg.ps1

## Generate le scripts
Get-HPOVLogicalEnclosure | ConvertTo-HPOVPowerShellScript > le.ps1
# Review the le.ps1 and match the enclosures to your destination environment

## Generate server profile template scripts
Get-HPOVServerProfileTemplate | ConvertTo-HPOVPowerShellScript > spt.ps1

## Generate server profile scripts
Get-HPOVServerProfile | ConvertTo-HPOVPowerShellScript > sp.ps1

## Disconnect from the master environment
Disconnect-HPOVMgmt

## Connect to the destination environment
Connect-HPOVMgmt -Hostname <destination-IP-Address> -username administrator -Password <password>

## Run scripts to configure the destination environment
.\net.ps1
.\netset.ps1
.\lig.ps1
.\eg.ps1
.\le.ps1
.\spt.ps1
.\sp.ps1

## Disconnect from the destination environment
Disconnect-HPOVMgmt