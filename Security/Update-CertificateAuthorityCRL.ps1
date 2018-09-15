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
    Update expired certificate authority CRL.

    .DESCRIPTION
    Use this script to upload updated CRL's to both appliance built-in and administrator added certificate authorities.

    .Parameter ApplianceConnection
    One or more HPOneView.Appliance.Connection objects to syncronize directories to.

    .INPUTS
    None.  You cannot pipe objects to this cmdlet.

    .OUTPUTS
    HPOneView.Appliance.TaskResource
    Async task final status.

    .OUTPUTS
    HPOneView.Appliance.TrustedCertificateAuthority
    The updated certificate authority objects.

    .LINK
    Connect-HPOVMgmt

    .EXAMPLE
    PS C:\> Connect-HPOVMgmt -Hostname Appliance1.domain.com -Credential $MyAdminCreds
    PS C:\> Connect-HPOVMgmt -Hostname Appliance2.domain.com -Credential $MyAdminCreds
    PS C:\> .\Update-CertificateAuthorityCRL.ps1

    Update all certificate authorities with expired CRLs.

#>

[CmdletBinding (DefaultParameterSetName = 'Default')]

Param 
(

    [Parameter (Mandatory = $false, ParameterSetName = 'Default')]
    [HPOneView.Appliance.Connection[]]$ApplianceConnection = $ConnectedSessions

)

ForEach ($_Appliance in $ApplianceConnection)
{

    Try
    {
    
        # Get the certificate authorities
        $ExpiredCertCrls = Get-HPOVApplianceTrustedCertificate -CertificateAuthoritiesOnly -ApplianceConnection $_Appliance | ? Status -match "CRL Expired"
    
    }
    
    Catch
    {
    
        $PSCmdlet.ThrowTerminatingError($_)
    
    }

    $e = 1

    ForEach ($ExpiredCertCrl in $ExpiredCertCrls)
    {

        Write-Progress -Activity "Update Certificate Authority expired CRL" -Status ("Processing '{0}'" -f $ExpiredCertCrl.Name) -PercentComplete ($e / $ExpiredCertCrls.Count)

        Try
        {
    
            Update-HPOVApplianceTrustedAuthorityCrl -InputObject $ExpiredCertCrl -ApplianceConnection $ExpiredCertCrl.ApplianceConnection
    
        }
    
        Catch
        {
    
            $PSCmdlet.ThrowTerminatingError($_)
    
        }

        $e++

    }
    
    Write-Progress -Activity "Update Certificate Authority expired CRL" -Completed

    Get-HPOVApplianceTrustedCertificate -CertificateAuthoritiesOnly -ApplianceConnection $_Appliance   

}