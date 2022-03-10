 # Copyright 2021 Hewlett Packard Enterprise Development LP
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

# Specify the firmware update mode.  Allowed values:
# FirmwareAndOSDrivers - Updates the firmware and OS drivers without powering down the server hardware using Smart Update Tool.
# FirmwareOnly - Updates the firmware without powering down the server hardware using Smart Update Tool.
# FirmwareOnlyOfflineMode - Manages the firmware through HPE OneView. Selecting this option requires the server hardware to be powered down.
$FirmwareInstallationType = "FirmwareOnlyOfflineMode"

$BaselineInstallationModes = @{

    FirmwareAndOSDrivers    = "On";
    FirmwareOnly            = "On";
    FirmwareOnlyOfflineMode = "Off"

}

# Get list of server profiles for all Windows Prod systems
$ServerProfiles = Get-HPOVServerProfile -Name Win-Prod* -ErrorAction Stop

# Get the baseline needed
$FirmwareBaseline = Get-HPOVBaseline -SppName "HPE OneView Baseline based on DCS demo schematic. 2017 04 16" -ErrorAction Stop

# Collection to store generated tasks for monitoring later
$Tasks = New-Object System.Collections.ArrayList

$s = 0

# Update each profile with the baseline value and save
ForEach ($ServerProfile in $ServerProfiles)
{

    Write-Progress -Activity ("Update server {0}" -f $FirmwareInstallationType) -Status ("Processing server profile: {0}" -f $ServerProfile.name) -PercentComplete ($s + 1 / $ServerProfiles.Count)

    $Server = $null

    # Get the server hardware resource
    if ($null -ne $ServerProfile.serverHardwareUri)
    {

        $Server = Send-HPOVRequest -Uri $ServerProfile.serverHardwareUri

    }

    $ServerProfile.firmware.manageFirmware = $true
    $ServerProfile.firmware.firmwareBaselineUri = $FirmwareBaseline.Uri
    $ServerProfile.firmware.firmwareInstallType = $FirmwareInstallationType

    # Server power state should match the requested baseline installation mode, or the power state doesn't match (Off) the requested installation mode (On), and the installation mode is allowed (On), save the profile
    If ($Server.powerState -eq $BaselineInstallationModes[$FirmwareInstallationType] -or
        ($Server.powerState -ne $BaselineInstallationModes[$FirmwareInstallationType] -and $BaselineInstallationModes[$FirmwareInstallationType] -eq "On"))
    {

        Write-Progress -Activity ("Update server {0}" -f $FirmwareInstallationType) -Status ("Saving server profile: {0}" -f $ServerProfile.name) -PercentComplete ($s + 1 / $ServerProfiles.Count)

        # Save the server profile uisng async call, saving the task for monitoring later
        $Task = Save-HPOVServerProfile -InputObject $ServerProfile -Async

        [void]$Tasks.Add($Task)

    }

    # Server power (On) and requested installation type (Off) can't be supported.
    # If server power needs to be off, then a statement to change the power state of the server (Set-HPOVServerPower) to Off could be used.
    else
    {

        # Write error that server power state is On and needs to be powered off
        Write-Error ("The requested baseline installation type '{0}' does not support the server power state '{1}'.  Server power state must be {2} for the baseline to be deployed." -f $Server.powerState, $FirmwareInstallationType, $BaselineInstallationModes[$FirmwareInstallationType])

    }

    $s++

}

Write-Progress -Activity ("Update server {0}" -f $FirmwareInstallationType) -Completed

# Monitor the created/generated tasks to completion
$AllTaskResults = $Tasks | Wait-HPOVTaskComplete

# Build a report of tasks that completed with an "error" state
$AllTaskStatusReport = New-Object System.Collections.ArrayList

ForEach ($e in ($AllTaskResults | ? taskState -eq "Error"))
{

    $Report = [PSCustomObject]@{
        ResourceName                = $e.associatedResource.resourceName;
        TaskState                   = $e.taskState;
        TaskErrorMessage            = [String]::Join(" ", $e.taskErrors.message);
        TaskErrorRecommendedActions = [String]::Join(" ", $e.taskErrors.recommendedActions);
    }

    [void]$AllTaskStatusReport.Add($Report)

}

$AllTaskStatusReport | Format-Table -AutoSize -Wrap | Out-Host