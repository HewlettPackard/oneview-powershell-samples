##############################################################################
# CreateServerProfilesFromTemplatesFromServerCollection.ps1
#
# Example script to demonstrate finding the number of requested BL or SY servers, 
# ensuring they are uniquely located to spread the cluster nodes across multiple
# enclosures/frames.  Then, create a server profile for each available server
# resource.
#
#   VERSION 1.0
#
# (C) Copyright 2013-2019 Hewlett Packard Enterprise Development LP 
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

$ApplianceHostname = "appliance.lab.local"
if (-not (get-module HPOneview.420)) 
{

    Import-Module HPOneView.420

}

if (-not ($ConnectedSessions | ? Name -eq $ApplianceHostname))
{

    Write-Host "Connecting to appliance."
    $MyConnection = Connect-HPOVMgmt -Hostname $ApplianceHostname -Credential $HPOVPSCredential

}

# View the connected HPE OneView appliances from the library by displaying the global $ConnectedSessions variable
$ConnectedSessions | Out-Host

pause

# Get list of configured Logical Enclosures
Get-HPOVLogicalEnclosure | Out-Host

Pause

# Now view what enclosures have been imported
Get-HPOVEnclosure | Out-Host

pause

# Now list all the servers that have been imported with their current state
Get-HPOVServer | out-Host

pause

# Next, show the avialble servers from the available Server Hardware Type
$TotalNumberOfServers = 6
$ServerProfileTemplate = Get-HPOVServerProfileTemplate -Name 'Hypervisor Node Template'

$ServerProfileTemplate | Out-Host

Pause

# Get list of available servers without server profiles and match the server hardware type
$AvailableServers = Get-HPOVServer -InputObject $ServerProfileTemplate -NoProfile

# Example output of variable
# C:\> $AvailableServers
# Name         ServerName           Status  Power Serial Number Model       ROM                  iLO       Server Profile
# ----         ----------           ------  ----- ------------- -----       ---                  ---       --------------
# Encl1, bay 5 Server-5.domain.com  Warning Off   SGH100X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl1, bay 6 Server-6.domain.com  Warning Off   SGH101X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl1, bay 7 Server-7.domain.com  Warning Off   SGH102X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl1, bay 8 Server-8.domain.com  Warning Off   SGH103X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl2, bay 3 Server-17.domain.com Warning Off   SGH104X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl2, bay 4 Server-18.domain.com Warning Off   SGH105X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl2, bay 5 Server-19.domain.com Warning Off   SGH106X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl2, bay 6 Server-20.domain.com Warning Off   SGH107X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl2, bay 7 Server-21.domain.com Warning Off   SGH108X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl2, bay 8 Server-22.domain.com Warning Off   SGH109X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile

# Get list of unique server locations, which map to Enclosures/Frames.
$ServerLocations = $AvailableServers | group -Property locationUri | select -Expand Name

# Create a collection to store server objects that will be deployed.  Very well could have used $ServersToDeploy = @(), but the += operator is a slower process.
$ServersToDeploy = New-Object System.Collections.ArrayList

Do
{

    ForEach ($_Location in $ServerLocations)
    {

        $ServerToAdd = $AvailableServers | % locationUri -eq $_Location | select -First 1

        [Void]$ServersToDeploy.Add($ServerToAdd)

        $AvailableServers = $AvailableServers | % uri -ne $ServerToAdd.uri

        # Break out if we have reached the max number of servers we need.
        if ($ServersToDeploy.Count -eq $TotalNumberOfServers)
        {

            break

        }

    }

} Until ($ServersToDeploy.Count -ge $TotalNumberOfServers)

# Final list of servers to deploy
# C:\> $ServersToDeploy
# 
# Name         ServerName           Status  Power Serial Number Model       ROM                  iLO       Server Profile
# ----         ----------           ------  ----- ------------- -----       ---                  ---       --------------
# Encl1, bay 5 Server-5.domain.com  Warning Off   SGH100X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl2, bay 3 Server-17.domain.com Warning Off   SGH104X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl1, bay 6 Server-6.domain.com  Warning Off   SGH101X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl2, bay 4 Server-18.domain.com Warning Off   SGH105X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl1, bay 7 Server-7.domain.com  Warning Off   SGH102X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl2, bay 5 Server-19.domain.com Warning Off   SGH106X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile

# Updated list of available servers
# C:\> $AvailableServers
# 
# Name         ServerName           Status  Power Serial Number Model       ROM                  iLO       Server Profile
# ----         ----------           ------  ----- ------------- -----       ---                  ---       --------------
# Encl1, bay 8 Server-8.domain.com  Warning Off   SGH103X8RN    BL460c Gen8 I31 v1.30 09/30/2011 iLO4 2.55 No Profile
# Encl2, bay 6 Server-20.domain.com Warning Off   SGH107X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl2, bay 7 Server-21.domain.com Warning Off   SGH108X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile
# Encl2, bay 8 Server-22.domain.com Warning Off   SGH109X8RN    BL460c Gen8 I31 v1.30            iLO4 2.55 No Profile

# Make sure servers are powered off
$ServersToDeploy | Stop-HPOVServer -Confirm:$false | Wait-HPOVTaskComplete | out-Host

# Create the number of Servers from the $svr collection
For ($s = 1; $s -le $ServersToDeploy.count; $s++) 
{

    New-HPOVServerProfile -Name "Prod-HypClusNode-0$s" -Assignment Server -Server $ServersToDeploy[($s - 1)] -ServerProfileTemplate $ServerProfileTemplate -Async

}

Get-HPOVTask -State Running | Wait-HPOVTaskComplete