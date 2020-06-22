
##############################################################################
# MaintenanceMode-Samples.ps1
#
# Sample script to manage server maintenance mode in OneVIew 5.20 and newer.
#
#   VERSION 1.0
#
# (C) Copyright 2013-2020 Hewlett Packard Enterprise Development LP
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

# Get list of servers (with sample output)
Get-HPOVServer

# Name          ServerName          Status Power Serial Number Model        ROM                    iLO       Server
#                                                                                                            Profile
# ----          ----------          ------ ----- ------------- -----        ---                    ---       ------------
# Encl1, bay 1                      OK     Off   SGH100X7RN    BL660c Gen9  I38 v1.30 08/03/2014   iLO4 2.50 No Profile
# Encl1, bay 11                     OK     Off   SGH100X4RN    BL460c Gen9  I36 v1.30 08/26/2014   iLO4 2.50 No Profile
# Encl1, bay 12                     OK     Off   SGH101X4RN    BL460c Gen9  I36 v1.30 08/26/2014   iLO4 2.50 No Profile
# Encl1, bay 13                     OK     Off   SGH102X4RN    BL460c Gen9  I36 v1.30 08/26/2014   iLO4 2.50 No Profile
# Encl1, bay 14                     OK     Off   SGH103X4RN    BL460c Gen9  I36 v1.30 08/26/2014   iLO4 2.50 No Profile
# Encl1, bay 15                     OK     Off   SGH104X4RN    BL460c Gen9  I36 v1.30 08/26/2014   iLO4 2.50 No Profile
# Encl1, bay 16                     OK     Off   SGH105X4RN    BL460c Gen9  I36 v1.30 08/26/2014   iLO4 2.50 No Profile
# Encl1, bay 2                      OK     Off   SGH101X7RN    BL660c Gen9  I38 v1.30 08/03/2014   iLO4 2.50 No Profile
# Encl1, bay 3  linux               OK     Off   SGH100X2RN    BL460c Gen10 I41 v1.00 (07/05/2016) iLO5 1.40 No Profile
# Encl1, bay 4  linux               OK     Off   SGH103X2RN    BL460c Gen10 I41 v1.00 (07/05/2016) iLO5 1.40 No Profile
# Encl1, bay 5  Server-5.domain.com OK     Off   SGH100X8RN    BL460c Gen8  I31 v1.30 09/30/2011   iLO4 2.50 No Profile
# Encl1, bay 6  Server-6.domain.com OK     Off   SGH101X8RN    BL460c Gen8  I31 v1.30 09/30/2011   iLO4 2.50 No Profile
# Encl1, bay 7  Server-7.domain.com OK     Off   SGH102X8RN    BL460c Gen8  I31 v1.30 09/30/2011   iLO4 2.50 No Profile
# Encl1, bay 8  Server-8.domain.com OK     Off   SGH103X8RN    BL460c Gen8  I31 v1.30 09/30/2011   iLO4 2.50 No Profile

# Get list of servers in maintenance mode
Get-HPOVServer -MaintenanceMode $true

# No servers are in maintenance mode, as the return is null

# Get specific server, and put it into maintenance mode, with async task completion
Get-HPOVServer -Name 'Encl1, bay 1' | Enter-HPOVClusterNodeMaintenanceMode

# Appliance            Name                    Owner         Created               Duration TaskState PercentComplete
# ---------            ----                    -----         -------               -------- --------- ---------------
# appliance.domain.com Enable maintenance mode Administrator 6/22/2020 10:47:14 AM 00:00:00 Completed 100

# Get list of servers in maintenance mode (with sample output)
Get-HPOVServer -MaintenanceMode $true

# Name         ServerName Status Power Serial Number Model       ROM                  iLO       Server Profile License
# ----         ---------- ------ ----- ------------- -----       ---                  ---       -------------- -------
# Encl1, bay 1            OK     Off   SGH100X7RN    BL660c Gen9 I38 v1.30 08/03/2014 iLO4 2.50 No Profile     OneView

# Get available scopes (with sample output)
Get-HPOVScope

# Appliance            Name          Description Members
# ---------            ----          ----------- -------
# appliance.domain.com Site A Admins             {Dev VLAN 101-A, Dev VLAN 101-B, Dev VLAN 102-A, Dev VLAN 102-B...}

# Show the members of the scope
(Get-HPOVScope -Name 'Site A Admins').Members

# Name           Type
# ----           ----
# Dev VLAN 101-A EthernetNetwork
# Dev VLAN 101-B EthernetNetwork
# Dev VLAN 102-A EthernetNetwork
# Dev VLAN 102-B EthernetNetwork
# Dev VLAN 103-A EthernetNetwork
# Dev VLAN 103-B EthernetNetwork
# Dev VLAN 104-A EthernetNetwork
# Dev VLAN 104-B EthernetNetwork
# Dev VLAN 105-A EthernetNetwork
# Dev VLAN 105-B EthernetNetwork
# Encl1, bay 1   ServerHardware
# Encl1, bay 11  ServerHardware
# Encl1, bay 12  ServerHardware
# Encl1, bay 13  ServerHardware

# Process the scope resource, and put servers into maintenance mode
Get-HPOVScope -Name 'Site A Admins' | Enable-HPOVMaintenanceMode -confirm:$false

# Get list of servers that are in maintenance mode
Get-HPOVServer -MaintenanceMode $true

# Name          ServerName Status Power Serial Number Model       ROM                  iLO       Server Profile License
# ----          ---------- ------ ----- ------------- -----       ---                  ---       -------------- -------
# Encl1, bay 1             OK     Off   SGH100X7RN    BL660c Gen9 I38 v1.30 08/03/2014 iLO4 2.50 No Profile     OneView
# Encl1, bay 11            OK     Off   SGH100X4RN    BL460c Gen9 I36 v1.30 08/26/2014 iLO4 2.50 No Profile     OneView
# Encl1, bay 12            OK     Off   SGH101X4RN    BL460c Gen9 I36 v1.30 08/26/2014 iLO4 2.50 No Profile     OneView
# Encl1, bay 13            OK     Off   SGH102X4RN    BL460c Gen9 I36 v1.30 08/26/2014 iLO4 2.50 No Profile     OneView

# Disable maintenance mode for the servers within the scope, using async method
Get-HPOVScope -Name 'Site A Admins' | Disable-HPOVMaintenanceMode -Async -confirm:$false