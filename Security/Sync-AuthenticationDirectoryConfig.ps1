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
    Syncronize HPE OneView LDAP Authentication Directories.

    .DESCRIPTION
    Use this Cmdlet to syncronize a specific, or multiple Active Directory authentication directories across multiple connected appliances.

    .Parameter Source
    The HPOneView.Appliance.Connection object of the source appliance to syncronize with.

    .Parameter Destination
    One or more HPOneView.Appliance.Connection objects to syncronize directories to.

    .Parameter AuthenticationDirectory
    The name of the Authentication Directory to syncronize.
    
    .Parameter Credential
    PSCredential used to validate the authentication directory on the destination appliance.
    
    .Parameter ServiceAccountCredential
    PSCredential used to configure service account authentication directory(ies), specifically for two-factor authentication.

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
    PS C:\> .\Sync-AuthenticationDirectoryConfig.ps1 -Source $ConnectedSessions[0] -Destination $ConnectedSessions[1] -Credential $MyAdminCreds

    Syncronize all found directories from the source to destination appliance.

    .EXAMPLE
    PS C:\> Connect-HPOVMgmt -Hostname Appliance1.domain.com -Credential $MyAdminCreds
    PS C:\> Connect-HPOVMgmt -Hostname Appliance2.domain.com -Credential $MyAdminCreds
    PS C:\> .\Sync-AuthenticationDirectoryConfig.ps1 -Source $ConnectedSessions[0] -Destination $ConnectedSessions[1] -AuthenticationDirectory ad.domain.com -Credential $MyAdminCreds

    Sync a specific authentication directory.

    .EXAMPLE
    PS C:\> Connect-HPOVMgmt -Hostname Appliance1.domain.com -Credential $MyAdminCreds
    PS C:\> Connect-HPOVMgmt -Hostname Appliance2.domain.com -Credential $MyAdminCreds
    PS C:\> .\Sync-AuthenticationDirectoryConfig.ps1 -Source $ConnectedSessions[0] -Destination $ConnectedSessions[1] -AuthenticationDirectory ad.domain.com-2FA -Credential $MyAdminCreds -ServiceAccountCredential $ServiceAccountCreds

    Sync a specific two-factor authentication directory and provide the two-factor authenticateion service account.

#>
    
[CmdletBinding(DefaultParameterSetName = 'Default')]

Param 
(

    # Source appliance connection
    [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
    [HPOneView.Appliance.Connection]$Source,

    # One or more appliance connections to sync to
    [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
    [HPOneView.Appliance.Connection[]]$Destination,

    # Limit to only sync this specific authentication directory instead of all.
    [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
    [Object]$AuthenticationDirectory,

    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
    [PSCredential]$ServiceAccountCredential

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
    
    # Helper function to sync PKI issuing and root certificates
    function WalkCertTree ($Cert, $CertCollection, $ApplianceDestination)
    {

        "Checking if certificate authority '{0}' is present to the appliance destination '{1}'." -f $Cert.Name, $ApplianceDestination | Write-Verbose

        # Cert is likely an issuing cert authority
        if ($Cert.Certificate.Subject -eq $Cert.Certificate.Issuer)
        {

            # If not in the appliance trust store, add
            if (-not (Get-HPOVApplianceTrustedCertificate -Name $Cert.Name -ApplianceConnection $ApplianceDestination -ErrorAction SilentlyContinue))
            {

                "Adding certificate authority '{0}' to the destination." -f $Cert.Certificate.Subject | Write-Verbose

                Add-HPOVApplianceTrustedCertificate -CertObject $Cert.Certificate -ApplianceConnection $ApplianceDestination | Out-Null

            }

            else
            {
            
                "Certificate authority '{0}' is present on the destination appliance {1}." -f $Cert.Name, $ApplianceDestination | Write-Verbose
            
            }

        }

        # There is a chain present, and need to walk
        else
        {

            $_IssuerName = ($Cert.Certificate.Issuer.Split(","))[0].Replace("CN=", $null)

            $_Issuer = $CertCollection | ? Name -eq $_IssuerName

            "Parsing the certificate chain for '{0}'.  Walking to '{1}' issuer." -f $Cert.Certificate.Subject, $_Issuer.Name | Write-Verbose
    
            WalkCertTree -Cert $_Issuer -CertCollection ($CertCollection | ? Name -ne $_Issuer.Name) -ApplianceDestination $ApplianceDestination

            Add-HPOVApplianceTrustedCertificate -CertObject $Cert.Certificate -ApplianceConnection $Cert.ApplianceConnection | Out-Null
    
        }

    }

    function Sync-CertificateAuthorityCerts
    {

        [CmdletBinding(DefaultParameterSetName = 'Default')]

        Param 
        (

            # Source appliance connection
            [Parameter(Mandatory, ParameterSetName = 'Default')]
            [HPOneView.Appliance.Connection]$ApplianceDestination

        )

        "Syncing non-builtin CA cert authority certificates with '{0}' appliance." -f $ApplianceDestination | Write-Verbose

        $_BuiltInCertAuthorityCerts = @(

            "VeriSign Class 3 Public Primary Certification Authority - G5",
            "VeriSign Universal Root Certification Authority",
            "Symantec Class 3 Secure Server CA - G4",
            "Symantec Class 3 Secure Server SHA256 SSL CA",
            "DigiCert Global CA G2",
            "DigiCert Global Root G2"

        )

        Try
        {
    
            $_BaseCerts = Get-HPOVApplianceTrustedCertificate -CertificateAuthoritiesOnly -ApplianceConnection $Source -ErrorAction SilentlyContinue

            $_CertsToReplicateCol = New-Object System.Collections.ArrayList

            # Prune the certs list to exclude appliance included known cert authorities
            ForEach ($_CertName in (Compare-Object -ReferenceObject $_BuiltInCertAuthorityCerts -DifferenceObject $_BaseCerts.Name -PassThru))
            {

                $_CertToReplicate = $_BaseCerts | ? Name -eq $_CertName

                [void]$_CertsToReplicateCol.Add($_CertToReplicate)

            }

            $_CertToReplicate = $null

            ForEach ($_CertToReplicate in $_CertsToReplicateCol)
            {

                WalkCertTree -Cert $_CertToReplicate -CertCollection ($_CertsToReplicateCol | ? Name -ne $_CertToReplicate.Name) -ApplianceDestination $ApplianceDestination

            }
    
        }
    
        Catch
        {
    
            $PSCmdlet.ThrowTerminatingError($_)
    
        }

    }

}

Process 
{

    if (-not $PSBoundParameters['Source'])
    {

        $Source = $ConnectedSessions | ? Default

    }

    if (-not $PSBoundParameters['Destination'])
    {

        if (-not ($ConnectedSessions | ? { -not $_.Default }))
        {

            Throw 'Not connected to multiple appliances, or unable to identify non-default appliance connection in $ConnectedSessions global variable.'

        }

        $Destination = $ConnectedSessions | ? { -not $_.Default }

        "Destination set to: {0}" -f $Destination.Name | Write-Verbose
        
    }

    if (-not $PSBoundParameters['AuthenticationDirectory'])
    {

        Try
        {
    
            $_AuthDirectories = Get-HPOVLdapDirectory -ApplianceConnection $Source
    
        }
    
        Catch
        {
    
            $PSCmdlet.ThrowTerminatingError($_)
    
        }

    }

    else
    {
    
        Try
        {
    
            $_AuthDirectories = Get-HPOVLdapDirectory -Name $AuthenticationDirectory -ApplianceConnection $Source
    
        }
    
        Catch
        {
    
            $PSCmdlet.ThrowTerminatingError($_)
    
        }
    
    }

    ForEach ($_Appliance in $Destination)
    {

        ForEach ($_Directory in $_AuthDirectories)
        {

            "Processing source directory: {0}" -f $_Directory.Name | Write-Verbose

            # Directory does not exist in destination
            if (-not (Get-HPOVLdapDirectory -Name $_Directory.name -ErrorAction SilentlyContinue -ApplianceConnection $_Appliance))
            {

                "Authentication directory '{0}' does not exist in the destination appliance '{1}'." -f $_Directory.Name, $_Appliance | Write-Verbose

                Try
                {

                    $_Servers = New-Object System.Collections.ArrayList                   

                    # Loop through all servers
                    ForEach ($_DirectoryServer in $_Directory.directoryServers)
                    {

                        "Processing authentication directory server '{0}'." -f $_DirectoryServer.directoryServerIpAddress | Write-Verbose

                        $_Params = @{
                            Hostname = $_DirectoryServer.directoryServerIpAddress;
                            SSLPort  = $_DirectoryServer.directoryServerSSLPortNumber
                        }

                        # If the server object contains the directory server cert, let's add it
                        if (-not [System.String]::IsNullOrWhiteSpace($_DirectoryServer.directoryServerCertificateBase64Data))
                        {

                            "Directory server certificate is explicitly trusted." | Write-Verbose

                            $_Params.Add("Certificate", $_DirectoryServer.directoryServerCertificateBase64Data)
                            $_Params.Add("TrustLeafCertificate", $True)

                        }

                        # Let's verify the issuing CA cert has been added to the target appliance first
                        else
                        {

                            "Directory server certificate is implicitly trusted.  Calling Sync-CertificateAuthorityCerts." | Write-Verbose

                            Try
                            {
                            
                                Sync-CertificateAuthorityCerts -ApplianceDestination $_Appliance
                            
                            }
                            
                            Catch
                            {
                            
                                $PSCmdlet.ThrowTerminatingError($_)
                            
                            }                                

                        }

                        $_Server = New-HPOVLdapServer @_Params

                        [void]$_Servers.Add($_Server)

                    }

                    $_Params = @{
                        
                        Name                = $_Directory.Name;
                        AD                  = $true;
                        BaseDN              = $_Directory.baseDN;
                        Servers             = $_Servers;
                        Credential          = $null;
                        ApplianceConnection = $_Appliance

                    }

                    if ($_Directory.directoryBindingType -eq "SERVICE_ACCOUNT" -and -not $PSBoundParameters['ServiceAccountCredential'])
                    {

                        Throw ("The source directory '{0}' is configured with a Service Account, and the -ServiceAccountCredential was not provided." -f $_Directory.name)

                    }

                    elseif ($_Directory.directoryBindingType -eq "SERVICE_ACCOUNT" -and $PSBoundParameters['ServiceAccountCredential'])
                    {

                        $_Params.Credential = $ServiceAccountCredential
                        $_Params.Add("ServiceAccount", $True)

                    }

                    else
                    {
                    
                        $_Params.Credential = $Credential
                    
                    }

                    "Submitting request." | Write-Verbose
                    
                    New-HPOVLdapDirectory @_Params -verbose
                
                }
                
                Catch
                {
                
                    $PSCmdlet.ThrowTerminatingError($_)
                
                }

            }

            else
            {
            
                "Directory already exists on destination appliance.  Not syncing." | Write-Verbose
            
            }

        }

    }    

}

End 
{

    # Done.

}

