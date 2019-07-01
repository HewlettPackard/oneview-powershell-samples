# Copyright 2019 Hewlett Packard Enterprise Development LP
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

<#

    .SYNOPSIS
    Modify an existing uplink set within a Logical Interconnect Group.

    .DESCRIPTION
    Use this Cmdlet to update the associated netwok resources within the specified uplink set.

    .Parameter NetworksToAdd
    Collection of networks to add to the uplink set.

    .Parameter NetworksToRemove
    Collection of networks to remove to the uplink set.

    .Parameter InputObject
    The logical interconnect resource needing to be modified.
    
    .Parameter UplinkSetName
    The uplink set resource name within the provivded logical interconnect group to be modified.
    
    .INPUTS
    HPOneView.Networking.LogicalInterconnectGroup
    The logical interconnect group resource to modify.

    .OUTPUTS
    HPOneView.Appliance.TaskResource
    The Async task object to update the resource.

    .LINK
    Connect-HPOVMgmt

    .LINK
    Get-HPOVLogicalInterconnectGroup

    .LINK
    Get-HPOVNetwork

    .EXAMPLE
    PS C:\> $NetsToRemove = Get-HPOVNetwork -Name UDEV_NET*
    PS C:\> $NetsToAdd = Get-HPOVNetwork -Name SAAS_APPS*
    PS C:\> $LIG = Get-HPOVLogicalInterconnectGroup -Name Prod-Lig1
    PS C:\> Update-UplinkSetNetworks.ps1 -NetworksToAdd $NetsToAdd -NetworksToRemove $NetsToRemove -InputObject $LIG -UplinkSetName GDO-Nets-Uplink1

    Update the provided uplink set within the logical interconnect group with the networks to both add and remove.

#>
[CmdletBinding(DefaultParameterSetName = 'Default')]

Param 
(

    [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
    [Object[]]$NetworksToAdd,

    [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
    [Object[]]$NetworksToRemove,

    [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Default')]
    [Alias('LogicalInterconnectGroup')]
    [Object]$InputObject,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [String]$UplinkSetName

)

Begin 
{

    $MinimumModuleSupport = "HPOneView.4*"

    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Data.Entity")

    # Validate the required PowerShell modules/libraries are available on this PC
    if (-not (Get-Module $MinimumModuleSupport))
    {

        $ErrorRecord = New-Object Management.Automation.ErrorRecord (New-Object System.Data.ObjectNotFoundException "Unable to find required HPOneView module library.  Please install a supported HPOneView PowerShell library on this PC."), 'HPOneViewModuleObjectNotFound', 'ObjectNotFound' , "HPOneViewModule"
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)

    }

    if (-not $PSBoundParameters['NetworksToAdd'] -and -not $PSBoundParameters['NetworksToRemove'])
    {

        $ExceptionMessage = 'You must specify either -NetworksToAdd or -NetworksToRemove, or both parameters.'
        $ErrorRecord = New-Object Management.Automation.ErrorRecord (New-Object System.Exception($ExceptionMessage)), 'InvalidParameterUse', 'InvalidOperation' , "ParameterValidation"
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)

    }

}

Process 
{

    $_LigToModify = $InputObject.PSObject.Copy()

    # Process remove networks first:
    ForEach ($Net in $NetsToRemove)
    {
        # Update the Array without the network URI, effectively removing it from the uplink set.
        ($_LigToModify.uplinkSets | % name -eq $UplinkSetName).NetworkUris = ($_LigToModify.uplinkSets | % name -eq $UplinkSetName).NetworkUris -ne $Net.uri

    }

    # Process add networks:
    ForEach ($Net in $NetsToAdd)
    {

        # Check if the network exists already.
        if (($_LigToModify.uplinkSets | % name -eq $UplinkSetName).NetworkUris -NotContains $Net.uri)
        {

            ($_LigToModify.uplinkSets | % name -eq $UplinkSetName).NetworkUris += $Net.uri

        }

    }

    # Save the LIG to the API:
    Set-HPOVResource -InputObject $_LigToModify | Wait-HPOVTaskComplete

}

End
{

    # Done.

}