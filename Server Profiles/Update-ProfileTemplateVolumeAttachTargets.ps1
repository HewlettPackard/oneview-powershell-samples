# Script to change the SAN storage ports from Auto to specific TargetPorts within a server profile template.
# Script assumes two FC connections, and the FC connections are named.

# Specify the new target ports needed, per connection
$FCConnection1TargetPortWWIDs = "20:23:00:02:AC:01:BD:6B", "21:23:00:02:AC:01:BD:6B"
$FCConnection2TargetPortWWIDs = "22:24:00:02:AC:01:BD:6B", "23:24:00:02:AC:01:BD:6B"
$FCConnect1Name = "SAN_A"
$FCConnect2Name = "SAN_B"

$SPT = Get-HPOVServerProfileTemplate -Name "My SPT Name"

# Make a backup
$SptToUpdate = $SPT.PSObject.Copy()

# Figure out FC connection ID's
$Connection1 = $SptToUpdate.connectionSettings.connections | ? { $_.functionType -eq 'FibreChannel' -and $_.name -eq $FCConnect1Name }
$Connection2 = $SptToUpdate.connectionSettings.connections | ? { $_.functionType -eq 'FibreChannel' -and $_.name -eq $FCConnect2Name }

# Update all first connection paths
$SptToUpdate.sanStorage.volumeAttachments | ForEach-Object {

    ($_.storagePaths | ? connectionId -eq $Connection1.id) | Add-Member -NotePropertyName targetSelector -NotePropertyValue 'TargetPorts' -Force
    ($_.storagePaths | ? connectionId -eq $Connection1.id) | Add-Member -NotePropertyName targets -NotePropertyValue @()

    ForEach ($TargetWWID in $FCConnection1TargetPortWWIDs)
    {

        $_.storagePaths.targets += @{name = $TargetWWID }

    }

}

# Update all second connection paths
$SptToUpdate.sanStorage.volumeAttachments | ForEach-Object {

    ($_.storagePaths | ? connectionId -eq $Connection2.id) | Add-Member -NotePropertyName targetSelector -NotePropertyValue 'TargetPorts' -Force
    ($_.storagePaths | ? connectionId -eq $Connection2.id) | Add-Member -NotePropertyName targets -NotePropertyValue @()

    ForEach ($TargetWWID in $FCConnection2TargetPortWWIDs)
    {

        $_.storagePaths.targets += @{name = $TargetWWID }

    }

}

Save-HPOVServerProfileTemplate -InputObject $SptToUpdate

## Uncomment below to restore the original SPT
# $SPT.eTag = '*/*'
# Save-HPOVServerProfileTemplate -InputObject $SPT