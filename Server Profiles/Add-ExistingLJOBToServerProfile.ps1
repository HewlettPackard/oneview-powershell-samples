##############################################################################
# Add-ExistingLJOBToServerProfile.ps1
#
# Script to attach an existing HPE Synergy SAS Logical JBOD resource to an
# existing server profile resource.
#
# Used with HPE OneView 5.00 PowerShell library
#
#   VERSION 1.1
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

    sasLogicalJBOD ([object]$ExistingLJBOD, [int]$NextLogicalID, [string]$DeviceSlot, [Bool]$IsPersistent)
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

# Get our server profile
$prf1 = Get-HPOVServerProfile -Name prf1

# Get the logical JBOD
$NewLD1 = Get-HPOVLogicalJBOD -name "data1 (3210)"

# Get the current LJBOD drive ID's so we can figure out the next available
$ExistingIDs = $prf1.localStorage.sasLogicalJBODs.id

$NextLogicalID = ($ExistingIDs | Measure-Object -Maximum).Maximum + 1

$MezzDeviceID = "Mezz 1"
$IsPersistent = $True

# Attach a new LJBOD object to the server profile
$prf1.localStorage.sasLogicalJBODs += [sasLogicalJBOD]::new($NewLD1, $NextLogicalID, $MezzDeviceID, $IsPersistent)

# Save the server profile object
Save-HPOVServerProfile -InputObject $prf1