 # Copyright 2020 Hewlett Packard Enterprise Development LP
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
$thisTemplate               = Get-HPOVServerProfileTemplate -name $template -ErrorAction Stop

if ($NULL -ne $thisTemplate)
{
        $thisBaseline       = Get-HPOVBaseline -SppName $newBaseline
        if ($NULL -ne $thisBaseline)
        {
            $baselineUri    = $thisBaseline.uri
            $thisTemplate.firmware.firmwareBaselineUri = $baselineUri
            Send-HPOVRequest -uri $thisTemplate.uri -body $thisTemplate -method PUT
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