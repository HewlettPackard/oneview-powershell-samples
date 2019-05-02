Param (
    $credential , 
    $hostname, 
    $AuthLoginDomain = "local", 
    $OneViewModule      = "HPOneView.410",
    [Boolean]$CreateBackupSupport)




# Check connection
if (-not ($credential))
{
    $credential = get-credential -message "Please provide **** admin credential***  to log to OneView...."
}

if (-not ($hostname))
{
    $hostname   = read-host "Please provide the FQDN name or IP address of OneView"
}

write-host -foreground CYAN  '#################################################'
write-host -foreground CYAN  "Connecting to OneView ... $hostname"
write-host -foreground CYAN  '##################################################'
$a = Connect-HPOVMgmt -hostname $hostname -Credential $cred -AuthLoginDomain $AuthLoginDomain

if ($CreateBackupSupport)
{
    # Create folder to host backup and Dump
  $currentFolder  = Split-Path $MyInvocation.MyCommand.Path
  $folder         = "$currentFolder\OV-Backup-Dump"

  if (-not (test-path $folder))
  {
    md $folder
  }

  write-host -foreground CYAN '1#  save the Appliance support dump to C:'
  New-HPOVSupportDump -location  $folder -type appliance


  write-host -foreground CYAN  '2# generate a new backup, and if a remote location is configured, will initiate the file transfer. If not configured, then the Cmdlet will download the file to the current working directory.'
  New-HPOVBackup

  write-host -foreground CYAN 'The backup file is..'
  Get-HPOVBackup

  write-host -foreground CYAN 'Downloading the backup file..'
  Save-HPOVBackup -location $folder
}

write-host
write-host -foreground CYAN '3# check composer health active/standy cluster'
Get-HPOVComposerNode | select ApplianceConnection,modelNumber,Name,Role,state,status

write-host -foreground CYAN '4# check appliance web server certificate expiration'
Get-HPOVApplianceCertificateStatus 
sleep -Seconds 5

write-host -foreground CYAN '5# Confirm no critical alerts on the uplinks or logical Enclosure or interconnect modules'
'Enclosure','InterconnectBay','Network'| % { get-hpovalert -Timespan (New-TimeSpan -Days 2) -HealthCategory $_   | where Severity -eq 'Critical' }


write-host  -foreground CYAN '6# Check all interconnect modules are in a configured state'
Get-HPOVInterconnect | format-table -auto name, state

write-host  -foreground CYAN '7# Check local login'
if ( (Get-HPOVLdap).allowLocalLogin )
{
  write-host "Local login is allowed"
}
else 
{
  write-host -foreground YELLOW "Local login is NOT allowed"  
}

write-host  -foreground CYAN '8# Check service access'
$enabled    = Send-HPOVRequest -uri /rest/appliance/settings/serviceaccess

if ( $enabled )
{
  write-host  "service access is enabled"
}
else 
{
  write-host -foreground YELLOW "service access is NOT enabled"
}

write-host  -foreground CYAN '9# Check SSH access'
$enabled    = Send-HPOVRequest -uri /rest/appliance/ssh-access

if ( $enabled )
{
  write-host  "SSH access is enabled"
}
else 
{
  write-host -foreground YELLOW "SSH is NOT enabled"
}


$connectionName   = $hostname
write-host  -foreground CYAN '10# Check LACP state for Image Streamer ports '
$listofLIs         = Get-HPOVLogicalInterconnect -ApplianceConnection $connectionName
foreach ($LI in $listofLIs)
{
    $LIname             = $LI.name
    $IClist             = $LI.interconnects | % { send-hpovrequest -uri $_ -hostname $connectionName}  
    foreach ($IC in $IClist)
    {
        
        $portList       = $IC.ports |  where {($_.porttype -eq 'Uplink')  -and (-not ([string]::IsNullorEmpty($_.associatedUplinkSetUri) )) }
        foreach ($port in $portList)
        {
            $uplsetName         = (Send-HPOVRequest -uri $port.associatedUplinkSetUri -hostname $connectionName).name
            if ($uplsetName -eq 'Image Streamer')
            {
              $portName           = $port.interconnectName + "," + $port.name
              $portStatus         = $port.portStatus + " " + $port.portStatusReason

              $portLAGstate       = ""
              if ($port.neighbor -ne $NULL )
              {
                  $portLAGstate   = "LACP Activity" 
              }
              write-host "$uplsetName,$portName,$portStatus,$portLAGstate"
            }

        }
    }  


}

Disconnect-HPOVMgmt