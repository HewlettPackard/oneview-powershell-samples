


# ----------------- Get SPT
$spt                        = get-HPOVserverprofileTemplate -name 'BFS'

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
Set-HPOVResource -InputObject $spt | Wait-HPOVTaskComplete | fl *


# ----------------- Add second set of Bios Settins
write-host -foreground CYAN ' Wait 5 seconds for SPT to update and then get the latest version of SPT .....'
sleep -Seconds 5
# ---- Refresh the sspt
$spt                        = get-HPOVserverprofileTemplate -name 'BFS'
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
Set-HPOVResource -InputObject $spt | Wait-HPOVTaskComplete | fl *

          


