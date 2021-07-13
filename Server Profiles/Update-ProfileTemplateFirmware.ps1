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

# Use Case:
# To update firmware on Synergy compute modules, you usually update profile template with a new SPP baseline.
# Then apply modified template to profiles
# This script demonstrates how to update profile template with new SPP
#

$template                   = "NCS ESXi 6.5 Server Profile Template"
$newBaseline                = "HPE Synergy Custom SPP 201903 2019 06 12, 2019.06.12.00"

# Get profile template
$thisTemplate               = Get-OVServerProfileTemplate -name $template -ErrorAction Stop

if ($NULL -ne $thisTemplate)
{
        $thisBaseline       = Get-OVBaseline -SppName $newBaseline
        if ($NULL -ne $thisBaseline)
        {

            if (-not $thisTemplate.firmware.manageFirmware)
            {

                $thisTemplate.firmware.manageFirmware = $true

            }

            $baselineUri    = $thisBaseline.uri
            $thisTemplate.firmware.firmwareBaselineUri = $baselineUri

            # Uncomment the following to change the installation method
            ## You can change the following value to "FirmwareOnly" for iSUT online firmware only, or
            ## "FirmwareOnlyOfflineMode" for offline firmware only mode.
            # $thisTemplate.firmware.firmwareInstallType = "FirmwareAndOSDrivers"

            ## By default, firmware is not force installed.  Use this to force the re-installation and/or
            ## downgrade of firmware.
            # $thisTemplate.firmware.forceInstallFirmware = $true

            ## Use the following setting to change the activation type.  Activation is rebooting the host
            ## when needed to complete the installation of a component.  You can change the value to
            ## "Scheduled" in order to set a schedule within the server profile.
            # $thisTemplate.firmware.firmwareActivationType = "Immediate"

            Save-OVServerProfileTemplate -InputObject | Wait-OVTaskComplete

        }
        else
        {

            -ForegroundColor YELLOW "New baseline --> $newBaseline does not exist. Skip modifying template..."

        }
}

else
{

    write-host -ForegroundColor YELLOW "Template --> $template does not exist. Skip modifying it..."

}


# Get the list of servers profiles that are no longer compliant, and asynchronously update them

$tasks = @()
ForEach ($Server in (Get-OVServerProfile -NotCompliant))
{

    $tasks += Update-OVServerProfile -InputObject $Server -Async

}