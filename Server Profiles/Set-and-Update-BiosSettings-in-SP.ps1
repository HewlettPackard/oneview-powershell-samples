# Updating to support newer Cmdlets, and the OneView 5.30 library naming convention of the Cmdlets
$SPName = 'Prf1'

# ----------------- Get serverprofile
$serverprofile                        = Get-OVServerProfile -Name $SPName

# ------------------- BIOS Attribute
write-host -foreground CYAN ' Enable BIOS and configure first settings......'

$biosSettings                   = @(
    @{id='NumaGroupSizeOpt';value='Clustered'},
    @{id='MinProcIdlePower';value='NoCStates'},
    @{id='IntelUpiPowerManagement';value='Disabled'},
    @{id='WorkloadProfile';value='Virtualization-MaxPerformance'}

    )

$currentBios                        = $serverprofile.Bios
$currentBios.manageBios             = $True
$currentBios.overriddenSettings     = $biosSettings


# ----------------- Update biosSettings
Save-OVServerProfile -InputObject $serverprofile | Wait-OVTaskComplete | fl *


# ----------------- Add second set of Bios Settins
write-host -foreground CYAN ' Wait 5 seconds for SP to update and then get the latest version of SP .....'
sleep -Seconds 5
# ---- Refresh the sserverprofile
$serverprofile              = Get-OVServerProfile -Name $SPName
$currentBios                = $serverprofile.Bios
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
Save-OVServerProfile -InputObject $serverprofile | Wait-OVTaskComplete | fl *

# A reboot of the server is required for the BIOS settings to be applied.  Add your reboot server logic here.