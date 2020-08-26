# Updating to support newer Cmdlets, and the OneView 5.30 library naming convention of the Cmdlets
$SPTName = 'BFS'

# ----------------- Get SPT
$spt                        = Get-OVServerProfileTemplate -Name $SPTName

# ------------------- BIOS Attribute
write-host -foreground CYAN ' Enable BIOS and configure first settings......'

$biosSettings                   = @(
    @{id='NumaGroupSizeOpt';value='Clustered'},
    @{id='MinProcIdlePower';value='NoCStates'},
    @{id='IntelUpiPowerManagement';value='Disabled'},
    @{id='WorkloadProfile';value='Virtualization-MaxPerformance'}

    )

$currentBios                        = $spt.Bios
$currentBios.complianceControl      = 'Checked'
$currentBios.manageBios             = $True
$currentBios.overriddenSettings     = $biosSettings


# ----------------- Update biosSettings
Save-OVServerProfileTemplate -InputObject $spt | Wait-OVTaskComplete | fl *


# ----------------- Add second set of Bios Settins
write-host -foreground CYAN ' Wait 5 seconds for SPT to update and then get the latest version of SPT .....'
sleep -Seconds 5
# ---- Refresh the sspt
$spt                        = Get-OVServerProfileTemplate -Name $SPTName
$currentBios                = $spt.Bios
$updatedBiosSettings        = @()

foreach ($setting in $currentBios.overriddenSettings)
{
    $updatedBiosSettings    += $setting
}


$biosSettings2                  = @(
    @{id='EnergyEfficientTurbo';value='Disabled'},
    @{id='UncoreFreqScaling';value='Maximum'},
    @{id='PowerRegulator';value='StaticHighPerf'},
    @{id='MinProcIdlePkgState';value='NoState'},
    @{id='EnergyPerfBias';value='MaxPerf'},
    @{id='SubNumaClustering';value='Enabled'},
    @{id='CollabPowerControl';value='Disabled'}
)



foreach ($newsetting in $biosSettings2)
{
    $updatedBiosSettings     += $newsetting
}

$currentBios.overriddenSettings = $updatedBiosSettings

write-host -foreground CYAN ' Add 2nd set of BIOS settings .....'
# ----------------- Update biosSettings
Save-OVServerProfileTemplate -InputObject $spt | Wait-OVTaskComplete | fl *

# Get the list of Server Profiles associated, and those that are marked as NotCompliant
Get-OVServerProfile -InputObject $SPT -NonCompliant

# See what will change with the associated server profiles if an update from template operation were performed
Get-OVServerProfile -InputObject $SPT -NonCompliant | Update-OVServerProfile -WhatIf

# Now, update the associated server profiles to be consistent/compliant with the associated server profile template without confirmation and asynchronously
$Tasks = Get-OVServerProfile -InputObject $SPT -NonCompliant | Update-OVServerProfile -Confirm:$false -Async