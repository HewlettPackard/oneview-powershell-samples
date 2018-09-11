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
    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [Parameter(Mandatory, ParameterSetName = 'CreateADGroup')]
    [String]$GroupName,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [Parameter(Mandatory, ParameterSetName = 'CreateADGroup')]
    [String[]]$Role,

    [Parameter(Mandatory, ParameterSetName = 'CreateADGroup')]
    [Switch]$CreateADGroup,

    [Parameter(Mandatory, ParameterSetName = 'CreateADGroup')]
    [String]$OrganizationUnitDN,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [Parameter(Mandatory, ParameterSetName = 'CreateADGroup')]
    [Object]$AuthenticationDirectory,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [Parameter(Mandatory, ParameterSetName = 'CreateADGroup')]
    [PSCredential]$Credential

)

Begin 
{

    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Data.Entity")

    # Validate the required PowerShell modules/libraries are available on this PC
    if (-not (Get-Module HPOneView*))
    {

        $ErrorRecord = New-Object Management.Automation.ErrorRecord (New-Object System.Data.ObjectNotFoundException "Unable to find required HPOneView module library.  Please install a supported HPOneView PowerShell library on this PC."), 'HPOneViewModuleObjectNotFound', 'ObjectNotFound' , "HPOneViewModule"
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)

    }

    Import-Module ActiveDirectory -ErrorAction SilentlyContinue

    if (-not(Get-Module ActiveDirectory))
    {

        $ErrorRecord = New-Object Management.Automation.ErrorRecord (New-Object System.Data.ObjectNotFoundException "Unable to find required ActiveDirectory PowerShell module."), 'ActiveDirectoryModuleObjectNotFound', 'ObjectNotFound' , "ActiveDirectory"
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)

    }

}

Process 
{

    # Create the security group if it doesn't exist in AD
    Try 
    { 
        
        $_ADGroup = Get-ADGroup $GroupName
    
    } 
    
    Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] 
    { 
        
        If (-not $PSBoundParameters['CreateADGroup'])
        {

            $PSCmdlet.ThrowTerminatingError($_)

        }

        else
        {
        
            Try
            {

                # Create the directory group. Does not return an object.
                New-ADGroup -Name $GroupName -SamAccountName $GroupName -GroupCategory Security -GroupScope Global -DisplayName $GroupName -Path $OrganizationUnitDN
                
                # Get the newly created group
                $_ADGroup = Get-ADGroup $GroupName

            }

            Catch
            {

                $PSCmdlet.ThrowTerminatingError($_)

            }            
        
        }
    
    } 
    
    Catch 
    { 

        $PSCmdlet.ThrowTerminatingError($_)

    }

    # Create the Group in OneView
    ForEach ($_AuthDirectory in $AuthenticationDirectory)
    {

        Try
        {
        
            # Get the auth directory group from the directory to add
            $_ADGroup = Show-HPOVLdapGroups -Directory $_AuthDirectory -GroupName $GroupName -Credential $Credential -ApplianceConnection $_AuthDirectory.ApplianceConnection

            # Add the directory group to the appliance and specified authentication directory
            New-HPOVLdapGroup -Directory $_AuthDirectory -Group $_ADGroup -Roles $Role -Credential $Credential -ApplianceConnection $_AuthDirectory.ApplianceConnection -verbose

        }
        
        Catch
        {
        
            $PSCmdlet.ThrowTerminatingError($_)
        
        }

    }
    
}

End 
{

    # Done.

}