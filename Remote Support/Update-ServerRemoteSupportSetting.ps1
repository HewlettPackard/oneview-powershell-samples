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

# // TODO: Documentation
<#

    .SYNOPSIS
    Create Active Directory Security Group and add to HPE OneView.

    .DESCRIPTION
    Use this script to help create Active Directory Domain Global security group(s) and then add to the specified HPE OneView appliances.  If the group does not exist in Active Directory, it will be created in the OU specified.

    In order to create the AD domain global security group, your 

    .Parameter GroupName
    The Active Directory Domain Global Security Group name.

    .Parameter Role
    One or more roles to associate the authentication directory group with.

    .Parameter CreateADGroup
    Use to specify if the AD group should be created within Active Directory.  If group is not found, a terminating error is generated.
    
    .Parameter OrganizationUnitDN
    Specify the target organization unit's Distinguished Name to where the group will be created.
    
    .Parameter AuthenticationDirectory
    One or more HPE OneView authentication directories from Get-HPOVLdapDirectory.  Can support multiple appliance connections.
    
    .Parameter Credential
    PSCredential used to validate the authentication directory security group from HPE OneView, not the Microsoft Active Directory Cmdlets.

    .INPUTS
    None.  You cannot pipe objects to this cmdlet.

    .OUTPUTS
    HPOneView.Appliance.AuthenticationDirectory
    The newly created authentication directory on the target appliance.

    .LINK
    Connect-HPOVMgmt

    .LINK
    Get-HPOVLdapDirectory

    .EXAMPLE
    PS C:\> Connect-HPOVMgmt -Hostname Appliance1.domain.com -Credential $MyAdminCreds
    PS C:\> Connect-HPOVMgmt -Hostname Appliance2.domain.com -Credential $MyAdminCreds
    PS C:\> $Directories = Get-HPOVLdapDirectory mydomain.com -ApplianceConnection $ConnectedSessions
    PS C:\> $ConnectedSessions[0].ApplianceSecurityRoles
    Infrastructure administrator
    Read only
    Backup administrator
    Scope operator
    Scope administrator
    Network administrator
    Server administrator
    Storage administrator
    Server firmware operator
    Software administrator
    Server profile operator
    Server profile administrator
    Server profile architect

    PS C:\> $Role = "Server administrator"
    PS C:\> .\Add-ActiveDirectoryGroupToSecurity.ps1 -GroupName ServerAdmins -CreateAdGroup -OrganizationUnitDN "OU=Groups,OU=Admins,OU=Corp,DC=Domain,DC=local" -AuthenticationDirectory $Directories -Credential $MyAdminCreds

    Add and create the specific Active Directory security group to the specified appliance directories, with the specific role.

    .EXAMPLE
    PS C:\> Connect-HPOVMgmt -Hostname Appliance1.domain.com -Credential $MyAdminCreds
    PS C:\> Connect-HPOVMgmt -Hostname Appliance2.domain.com -Credential $MyAdminCreds
    PS C:\> $Directories = Get-HPOVLdapDirectory mydomain.com -ApplianceConnection $ConnectedSessions
    PS C:\> $ConnectedSessions[0].ApplianceSecurityRoles
    Infrastructure administrator
    Read only
    Backup administrator
    Scope operator
    Scope administrator
    Network administrator
    Server administrator
    Storage administrator
    Server firmware operator
    Software administrator
    Server profile operator
    Server profile administrator
    Server profile architect

    PS C:\> $Role = "Server administrator"
    PS C:\> .\Add-ActiveDirectoryGroupToSecurity.ps1 -GroupName ServerAdmins -AuthenticationDirectory $Directories -Credential $MyAdminCreds

    Add and specific existing Active Directory security group to the specified appliance directories, with the specific role.

#>
[CmdletBinding(DefaultParameterSetName = 'Default')]

Param 
(

    # Parameter help description
    [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Default')]
    [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Disable')]
    [Object[]]$Servers,

    [Parameter(Mandatory, ParameterSetName = 'Disable')]
    [Switch]$Disable,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [Switch]$Enable,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [Object]$PrimaryContact,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [Object]$SecondaryContact

)

$MinimumModuleSupport = "HPOneView.4*"

Begin 
{

    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Data.Entity")

    # Validate the required PowerShell modules/libraries are available on this PC
    if (-not (Get-Module $MinimumModuleSupport))
    {

        $ErrorRecord = New-Object Management.Automation.ErrorRecord (New-Object System.Data.ObjectNotFoundException "Unable to find required HPOneView module library.  Please install a supported HPOneView PowerShell library on this PC."), 'HPOneViewModuleObjectNotFound', 'ObjectNotFound' , "HPOneViewModule"
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)

    }

}

Process 
{

    ForEach ($_Server in $Servers)
    {
        $Params = @{

            InputObject    = $_Server

        }

        If ($PSBoundParameters['Disable'])
        {

            $Params.Add('Disable', $Disable.IsPresent)

        }

        else
        {

            $Params.Add('PrimaryContact', $PrimaryContact)
            $Params.Add('PrimaryContact', $Enabled.IsPresent)

            if ($PSBoundParameters['SecondaryContact'])
            {

                $Params.Add('SecondaryContact', $SecondaryContact)

            }

        }

        Try
        {
        
            Set-HPOVRemoteSupportSetting @Params
        
        }
        
        Catch
        {
        
            $PSCmdlet.WriteError($_)
        
        }

    }
    
}

End 
{

    # Done.

}