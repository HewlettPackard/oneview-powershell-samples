##############################################################################
# Add-ExistingLJOBToServerProfile.ps1
#
# Script to create and attach two new HPE Synergy SAS Logical JBOD resources
# to an existing server profile.
#
# Used with HPE OneView 5.00 PowerShell library
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

class sasLogicalJBOD
{

    [int]$id = $null;
    [string]$deviceSlot = "Mezz 1";
    [string]$name = $null;
    [string]$description = $null;
    [int]$numPhysicalDrives = $null;
    [string]$driveMinSizeGB = $null;
    [string]$driveMaxSizeGB = $null;
    [string]$driveTechnology = $null;
    [bool]$eraseData = $null;
    [bool]$persistent = $true;
    [string]$sasLogicalJBODUri = $null;

    sasLogicalJBODs ([object]$ExistingLJBOD, [int]$NextLogicalID, [string]$DeviceSlot, [Bool]$IsPersistent)
    {

        # This is used to put the driveTechnology property to the correct value later in the script
        $TextInfo = (Get-Culture -Name en-US).TextInfo

        $this.id = $NextLogicalID;
        $this.deviceSlot = $DeviceSlot;
        $this.name = $ExistingLJBOD.name;
        $this.description = $ExistingLJBOD.description;
        $this.numPhysicalDrives = $ExistingLJBOD.NumberOfDrives;
        $this.driveMinSizeGB = $ExistingLJBOD.MinSize;
        $this.driveMaxSizeGB = $ExistingLJBOD.MaxSize;
        $this.driveTechnology = ($TextInfo.ToTitleCase($ExistingLJBOD.Interface.ToLower()) + $TextInfo.ToTitleCase($ExistingLJBOD.Media.ToLower()));
        $this.eraseData = $ExistingLJBOD.EraseDataOnDelete;
        $this.persistent = $IsPersistent;
        $this.sasLogicalJBODUri = $ExistingLJBOD.Uri

    }

}

# Some config variables
$ProfileName          = "prf1"
$SasLIName            = 'SAS LI Name'
$MezzDeviceID         = "Mezz 1"
$MinimumDriveCapacity = 2000
$DriveType            = "SASSSD"
$IsPersistent         = $True

# Get our server profile
$prf1 = Get-HPOVServerProfile -Name $ProfileName -ErrorAction Stop

# Figure out drive types and availability, looking for greater than 2TB SAS drives from drive enclosure attached to a specific SAS Logical Interconnect
$SasLI = Get-HPOVSasLogicalInterconnect -Name $SasLIName -ErrorAction Stop
$AvailableDrives = Get-HPOVAvailableDriveType -InputObject $SasLI | ? { $_.Capacity -gt $MinimumDriveCapacity -and $_.Type -eq $DriveType }

# Create new Logical JBODs
1..2 | ForEach-Object { New-HPOVLogicalJBOD -InputObject $SasLI `
                                            -Name ($prf1.name + " LJBOD$_") `
                                            -DriveType $AvailableDrives.Type `
                                            -MinDriveSize $AvailableDrives.Capacity `
                                            -NumberofDrives 2 `
                                            -EraseDataOnDelete $False }

# Get the unattached, non-error state and available LJBODs
$NewLogicalJBODs = Get-HPOVLogicalJBOD -Name "$($prf1.name)*" | ? { [String]::IsNullOrEmpty($_.UsedBy) -and $_.State -eq 'Configured' }

# Attach a new LJBOD objects to the server profile
ForEach ($JBOD in $NewLogicalJBODs)
{

    # Get the current LJBOD drive ID's so we can figure out the next available
    $ExistingIDs = $prf1.localStorage.sasLogicalJBODs.id

    $NextLogicalID = ($ExistingIDs | Measure-Object -Maximum).Maximum + 1

    $prf1.localStorage.sasLogicalJBODs += [sasLogicalJBOD]::new($JBOD, $NextLogicalID, $MezzDeviceID, $IsPersistent)

}

# Save the server profile object
Save-HPOVServerProfile -InputObject $prf1