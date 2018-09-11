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

<#

    .SYNOPSIS
    Create an HPE Synergy Server Profile from Template and specifying OS Deployment Plan Attributes.

    .DESCRIPTION
    This sample script demonstrates necessary steps to configure OS Deployment Attributes when deploying a new server profile from a server profile template that contains an HPE Synergy Image Streamer OS Deployment Plan.

    .INPUTS
    None.  You cannot pipe objects to this cmdlet.

    .OUTPUTS
    HPOneView.Appliance.TaskResource

    .LINK
    Connect-HPOVMgmt

    .LINK
    Get-HPOVServerProfileTemplate

    .LINK
    Get-HPOVServer

    .LINK
    Get-HPOVOSDeploymentPlan

    .LINK
    Get-HPOVOSDeploymentPlanAttribute

    .LINK
    New-HPOVServerProfile

#>

$ServerProfileName = "My Host 1"

# Get the Server Profile Template Object
$ServerProfileTemplate = Get-HPOVServerProfileTemplate -Name TestingTemplate1 -ErrorAction Stop

# Get the first available server based on the template configuration
$Server = Get-HPOVServer -InputObject $ServerProfileTemplate -NoProfile | Select -First 1

# Get the ManagementNIC.connectionSettings object
$ManagementNIC = $ServerProfileTemplate.connectionSettings.connections | ? connectionName -eq "Management NIC"

# Get the OS Deployment Plan
$OSDeploymentPlan = Get-HPOVOSDeploymentPlan -Name $OSDeploymentPlanName -ErrorAction Stop

# Get the associated deployment plan attributes
$OSDeploymentAttributes = Get-HPOVOSDeploymentPlanAttribute -InputObject $OSDeploymentPlan -ErrorAction Stop

# Management NIC
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.connectionid").value = $ManagementNIC.connectionid
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.networkuri").value   = $ManagementNIC.networkUri
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.dhcp").value         = $false
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.constraint").value   = 'userspecified'
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.ipaddress").value    = '192.168.19.200'
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.netmask").value      = '255.255.255.0'
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.gateway").value      = '192.168.19.1'
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.dns1").value         = '192.168.19.11'
($OSDeploymentAttributes | Where-Object name -eq "ManagementNIC.dns2").value         = '192.168.19.12'

# Set Hostname
($OSDeploymentAttributes | Where-Object name -eq "Hostname").value = $ServerProfileName

# Set root password, in clear text here, as OneView does not support secure string data types
($OSDeploymentAttributes | Where-Object name -eq "Password").value = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

$ParamHash = @{
                
    Name                       = $ServerProfileName;
    AssignmentType             = "Server";
    Server                     = $Server;
    ServerProfileTemplate      = $ServerProfileTemplate;
    OSDeploymentPlanAttributes = $OSDeploymentAttributes
    
}            

$Results = New-HPOVServerProfile @ParamHash