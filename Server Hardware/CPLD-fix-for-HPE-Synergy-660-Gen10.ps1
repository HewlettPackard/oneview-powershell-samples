<#

This PowerShell script updates the CPLD component of all HPE Synergy 660 Gen10 managed by HPE OneView impacted by the CPLD issue.
Any servers already running the updated CPLD will be ignored.

Customer advisory: HPE Synergy 660 Gen10 Compute Modules - CPLD Update Required to Prevent Unexpected Power Off of Server
https://support.hpe.com/hpesc/public/docDisplay?docId=emr_na-a00121347en_us

Note:
All servers should be powered on at either RBSU or the server OS prior to the CPLD flash so during the execution, the script asks for each impacted/turned off server if it can be powered on or not.
If you decide not to power on a server, the CPLD update will not take place and the server will be skipped. 

Note: 
All servers must be restarted to activate the CPLD update so during the execution, the script asks for each impacted server if you want to restart the server gracefully or not.
If you decide not to restart a server, the CPLD update will not take place and the reboot will have to be initiated manually outside this script to activate the update.

Note:
For reporting purposes, 3 lists are displayed at the end of the script execution: 
 - A list of servers (if any) that must be restarted for the CPLD flash activation. For each server, you will need to follow the instructions in steps 6 and following of the Customer Advisory.
 - A list of servers (if any) that have not been updated because they are down.
 - A list of servers (if any) that have not been updated because they faced a CPLD component update issue

Output sample:
-------------------------------------------------------------------------------------------------------
Please enter the OneView password: ********
6 x Synergy 660 Gen10 server(s) impacted by the CPLD issue found!
Frame4, bay 1
Frame4, bay 2
Frame4, bay 3
Frame4, bay 4
Frame4, bay 5
Frame4, bay 6
Starting the CPLD update procedure...
Transcript started, output file is Y:\_Scripts\GitHub_HPE-Synergy-OneView-demos\Powershell\Compute\CPLD_upgrade_report.txt

Frame4, bay 1 - Server is already running CPLD version 0x1D! Skipping this server !

Frame4, bay 2 - Server is already running CPLD version 0x1D! Skipping this server !

Frame4, bay 3 - Server is already running CPLD version 0x1D! Skipping this server !

Frame4, bay 4 - Server is already running CPLD version 0x1D! Skipping this server !

Frame4, bay 5 (192.168.3.194 - ILOCZ214106HK.lj.lab – esx7-12) - CPLD update in progress...
Frame4, bay 5 (192.168.3.194 - ILOCZ214106HK.lj.lab - esx7-12) - Server is off - Do you want to power it on to update the CPLD component [y or n]?: n
Frame4, bay 5 (192.168.3.194 - ILOCZ214106HK.lj.lab - esx7-12) - The update of the CPLD cannot be completed, you will need to restart the server to activate the new version of the CPLD...

Frame4, bay 6 (192.168.3.195 - ILOCZ212406GH.lj.lab - Unnamed) - CPLD update in progress...
Frame4, bay 6 (192.168.3.195 - ILOCZ212406GH.lj.lab - Unnamed) - Do you want to initiate the shutdown to activate the CPLD update [y or n]?: y
Frame4, bay 6 - Wait for the server to be removed and re-added to OneView...
Frame4, bay 6 - Wait for the Add task to complete...
Frame4, bay 6 - Wait for the Server Profile apply task to complete...
Frame4, bay 6 - The server is unable to power on, resetting iLO...
Frame4, bay 6 - iLO reset in progress...
Frame4, bay 6 - Powering on server...
Frame4, bay 6 - Wait for POST to complete...
Frame4, bay 6 - Server has been successfully updated with CPLD version 0x1D and is back online!

The following servers have not been updated and should be rebooted to activate the new CPLD version:
Frame4, bay 5

Operation completed ! Hit return to close:
--------------------------------------------------------------------------------------------------------------------


Requirements: 
- Latest HPEOneView PowerShell library
- HPE iLO PowerShell Cmdlets (install-module HPEiLOCmdlets)
- OneView administrator account


 Date:  April 2022
 Version:  1.1

   
#################################################################################
#        (C) Copyright 2022 Hewlett Packard Enterprise Development LP           #
#################################################################################
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
#################################################################################
#>

# VARIABLES

# Location of the CPLD components, you can download it from https://support.hpe.com/hpesc/public/swd/detail?swItemId=MTX_c723ef1c122240978a887d6806
$CPDL_Location = "C:\\HPE\\CPLD_SY660_Gen10_V1D1D.fwpkg" 


# HPE OneView 
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"

# Report to be generated in the execution directory
$report = "CPLD_upgrade_report.txt"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }

# HPE iLO PowerShell Cmdlets 
# If (-not (get-module HPEiLOCmdlets -ListAvailable )) { Install-Module -Name HPEiLOCmdlets -scope Allusers -Force }

############################################################################################################################################

if (! $ConnectedSessions) {

    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
    
    $credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

    try {
        Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
        return
    }
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


# Added these lines to avoid the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."
# due to an invalid Remote Certificate
add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


#######################################################################################################################
$impactedservers = @()

# Retrieve all Computes impacted by the CPLD issue

$Computes = Get-OVServer | ? model -eq "Synergy 660 Gen10" 

foreach ($compute in $Computes) {
    
    $serialnumber = $compute.SerialNumber
    $scope = $serialnumber.SubString(3, 3)

    if ($scope -in 116..210 ) {
        # Write-Host "$($compute.name) is impacted!"
        $impactedservers += $compute.name
    }
}

if (! $impactedservers) {
    write-host "No vulnerable Synergy 660 Gen10 found! Exiting... "
    Disconnect-OVMgmt
    exit
}
else {
    write-host "$($impactedservers.count) x Synergy 660 Gen10 server(s) impacted by the CPLD issue found!"
    $impactedservers | Out-Host
    write-host "Starting the CPLD update procedure..."
}

#######################################################################################################################

# $impactedservers = "Frame4, bay 2", "Frame4, bay 3"

# Starting transcription to save the output of the script in the defined file, saved in the execution directory
$directorypath = Split-Path $MyInvocation.MyCommand.Path
Start-Transcript -path $directorypath\$report -append

$getdate = [datetime]::Now

# Setting up arrays to store the various server states for reporting purposes
$serverstoreboot = @()
$serversoff = @()
$serversfailure = @()

# Running updates on each impacted compute
ForEach ($server in $impactedservers) {
    
    $compute = Get-OVServer -name $server

    # Capture of the SSO Session Key
    $iloSession = $compute | Get-OVIloSso -IloRestSession
    $ilosessionkey = $iloSession."X-Auth-Token"
    # Capture iLO information
    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
    $Ilohostname = $compute  | % { $_.mpHostInfo.mpHostName }
    $serverName = $compute  | % serverName
    if (! $serverName) { $serverName = "Unnamed" }
    $serverpowerstatus = $compute.powerState


    # Checking CPLD current version
    $serverFirmwareInventoryUri = ($compute).serverFirmwareInventoryUri
    $cpldversion = ((send-ovrequest -uri $serverFirmwareInventoryUri).components | ? componentName -match "System Programmable Logic Device").componentVersion
       
    if ( $cpldversion -eq "0x1D") {
        Write-Host "`n$server - server is already running CPLD version 0x1D! Skipping this server !" -ForegroundColor Yellow
        continue
    }
    else {
        Write-Host "`n$server ($iloIP - $Ilohostname - $serverName) - CPLD update in progress..."
        # Procedure if server is off
        if ($serverpowerstatus -eq "off" ) {
            do {
                $powerup = read-host "$server ($iloIP - $Ilohostname - $serverName) - Server is off - Do you want to power it on to update the CPLD component [y or n]?"
            } until ($powerup -match '^[yn]+$')
        
            if ($powerup -eq "y") {      

                Start-OVServer $compute
            
                # wait end of POST
                $headerilo = @{ } 
                $headerilo["X-Auth-Token"] = $ilosessionkey 
        
                do {
                    $system = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Systems/1/" -Headers $headerilo -Method GET -UseBasicParsing 
                    write-host "$server - Waiting for POST to complete..."
                    sleep 5 
                } until (($system.Content | ConvertFrom-Json).oem.hpe.PostState -match "InPostDiscoveryComplete")

            }
            else {
                write-host "$server ($iloIP - $Ilohostname - $serverName) - The update of the CPLD cannot be completed as the server is off !"
                $serversoff += $server
                continue
            }        
        }

        # Updating the CPLD component using HPEiLOCmdlets

        # Connection to iLO
        $connection = Connect-HPEiLO -Address $iloIP -XAuthToken $ilosessionkey -DisableCertificateAuthentication

        try {
            $task = Update-HPEiLOFirmware -Location $CPDL_Location -Connection $connection -Confirm:$False -Force 
            #$($task.statusinfo.message)"
        }
        catch {
            Write-Host -ForegroundColor Red "$server ($iloIP - $Ilohostname - $serverName) - CPLD update failure! Canceling server!" 
            $serversfailure += $server
            continue
        }
    
        # Waiting for the CPDL firmware update success task to appear in the iLO event log
        do {

            $taskresult = (Get-HPEiLOEventLog -Connection $connection).EventLog | ? { $_.Message -match "firmware update success" -and [datetime]$_.created -gt $getdate }
            sleep 2

        } until ($taskresult)     

        # Asking if server can be turned off to activate the CPLD update
        # This command will request a "Momentary Press" request to initiate a server to shutdown gracefully.
    
        do {
            $powerdown = read-host "$server ($iloIP - $Ilohostname - $serverName) - Do you want to initiate the shutdown to activate the CPLD update [y or n]?"
        } until ($powerdown -match '^[yn]+$')

   
        if ($powerdown -eq "n") {
            write-host "$server ($iloIP - $Ilohostname - $serverName) - The update of the CPLD cannot be completed, you will need to restart the server to activate the new version of the CPLD..."
            $serverstoreboot += $server
        }
        else {
        
            # Turning off the server triggers a power-cycle and removes the server from OneView. The server will return once the power-cycle is complete
            Get-OVServer -Name $server | Stop-OVServer -Confirm:$false | Wait-OVTaskComplete
            sleep 10

            # Waiting for the server to be removed from OneView and then returned
            do {
                sleep 10
                $serverback = Get-OVServer -Name $server -ErrorAction SilentlyContinue
                write-host "$server - Wait for the server to be removed and re-added to OneView..."
            } until ( $serverback)

        
            do {
                sleep 5
                # Waiting for a new Add task to be created and completed 
                $serveraddtask = Get-OVServer -Name $server |  Get-OVTask -name add | ? { [datetime]$_.created -gt $getdate -and $_.taskstate -eq "Completed" }
                write-host "$server - Wait for the Add task to complete..."
            } until ($serveraddtask)

            sleep 20

            # If a profile is applied, we need to wait for the profile apply action to complete
            if ((Get-OVServer -Name $server).serverProfileUri  ) {
                do {
                    sleep 5
                    # Wait for the profile apply to complete
                    $serveraddtask = Get-OVServer -Name $server |  Get-OVTask | ? name -match "Apply profile" | ? { [datetime]$_.created -gt $getdate -and $_.taskstate -eq "Completed" }
                    write-host "$server - Wait for the Server Profile apply task to complete..."
                } until ($serveraddtask)
            }
       
            $compute = Get-OVServer -name $server
            
            # Powering on the server
            $powerONtask = $compute | Start-OVServer | Wait-OVTaskComplete

            sleep 5

            # If the server cannot be powered on, we need to reset the iLO 
            if ($powerONtask.taskstate -ne "Completed") {

                write-host "$server - The server is unable to power on, resetting iLO..."
            
                # Reconnecting to iLO (required after the Add task)
                $ilosessionkey = ($compute | Get-OVIloSso -IloRestSession)."X-Auth-Token"
                $connection = Connect-HPEiLO -Address $iloIP -XAuthToken $ilosessionkey -DisableCertificateAuthentication
            
                # Resetting iLO
                # Triggers a power-cycle and removes the server from OneView. The server will return once the power-cycle is complete
                $resetilo = Reset-HPEiLO -Connection $connection -Device iLO -Confirm:$False
                write-host "$server - iLO reset in progress..."

                # Waiting iLO reset to complete
                sleep 60 

                # Wait for an iLO connection to be granted
                do {
                    sleep 5
                    $ilosessionkey = ($compute | Get-OVIloSso -IloRestSession -ErrorAction Continue)."X-Auth-Token"
                } until ($ilosessionkey)
            
                sleep 15 # Sleep may be too short... can be adjusted.                
            
                # Turning on $server if off
                $serverpowerstate = Get-OVServer -Name $server | % powerState

                if ($serverpowerstate -eq "off") {
                    write-host "$server - Powering on server..."
                    $powerONtask = $compute | Start-OVServer | Wait-OVTaskComplete
                }
            }

            # Waiting end of POST
            # Retrieving iLO session key again (required after the iLO reset task)
            $ilosessionkey = (  Get-OVServer -name $server | Get-OVIloSso -IloRestSession)."X-Auth-Token"
           
            $headerilo = @{ } 
            $headerilo["X-Auth-Token"] = $ilosessionkey 
        
            do {
                $system = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Systems/1/" -Headers $headerilo -Method GET -UseBasicParsing 
                write-host "$server - Wait for POST to complete..."
                sleep 5 
            } until (($system.Content | ConvertFrom-Json).oem.hpe.PostState -match "InPostDiscoveryComplete")

            # Waiting for iLO to update the firmware information
            sleep 70 # Sleep may not be long enough... can be adjusted.

            # Checking CPLD update version
            $serverFirmwareInventoryUri = ($compute).serverFirmwareInventoryUri
            $cpldversion = ((send-ovrequest -uri $serverFirmwareInventoryUri).components | ? componentName -match "System Programmable Logic Device").componentVersion
        
            if ( $cpldversion -eq "0x1D") {
                Write-Host "$server - Server has been successfully updated with CPLD version 0x1D and is back online!" -ForegroundColor Yellow
            }
            else {
                Write-Host "$server - An error occurred ! Server is running CPLD version $($cpldversion) and not 0x1D! " -ForegroundColor Red
            }
        }
    }
}

if ($serverstoreboot) {
    write-host "`nThe following servers have not been updated and should be rebooted to activate the new CPLD version:"
    $serverstoreboot
}

if ($serversoff) {
    write-host "`nThe following servers have not been updated because they are down:"
    $serversoff
}

if ($serversfailure) {
    write-host "`nThe following servers have not been updated because they faced a CPLD component update issue:"
    $serversfailure
}

Read-Host -Prompt "`nOperation completed ! Hit return to close" 

Disconnect-OVMgmt   
Stop-Transcript