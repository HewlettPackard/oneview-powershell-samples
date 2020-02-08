$cred = get-credential
Connect-HPOVMgmt -hostname <OV-IP> -cred  $cred
$profileList = Get-HPOVServerProfile 
$header     = "server,firmware,schedule"
write-host $header
foreach ($sp in $profileList)
{
    $fw          		= $sp.firmware
    $serverUri          = $sp.serverhardwareUri
    $server             = (send-hpovrequest -uri $serverUri).Name

    $isFwManaged 		= $fw.manageFirmware
    if ($isFwManaged)
    {
        $fwActivation   	= $fw.firmwareActivationType
        $fwSchedule     	= $fw.firmwareScheduleDateTime
        $fwUri              = $fw.firmwareBaselineUri
        $fwBaselineName     = (send-hpovrequest -uri $fwUri).name

        if ($fwActivation -eq 'Scheduled')
        {
            $schedule       = ([DateTime]$fwSchedule).ToString()
            write-host "$server,$fwBaselineName,$Schedule"
        }
    }
}
Disconnect-HPOVMgmt