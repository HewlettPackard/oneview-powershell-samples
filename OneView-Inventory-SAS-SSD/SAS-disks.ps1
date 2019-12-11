


### Connect to DR OneView
$cred = get-credential -UserName administrator -message "Provide password"
Connect-HPOVMgmt -hostname  10.62.128.52 -credential $cred

$data       = @()
$CR         = "`n"
$data       = "Server,Model,SerialNumber" + $CR

### Get Server
$Server_list = Get-HPOVServer

foreach ($s in $Server_List)
{
    $name          = "`'" + $s.Name + "`'" 
    $lStorageUri   = $s.subResources.LocalStorage.uri
    $lStorage      = send-HPOVRequest -uri $lStorageUri

    foreach ($pd in $lStorage.data.PhysicalDrives)
    {
        if (($pd.InterfaceType -eq 'SATA') -and ($pd.MediaType -eq 'SSD'))
        {
            $sn     = $pd.serialNumber
            $model  = $pd.Model
            if ($sn)
            {
                $data   += "$name,$model,$sn" + $CR
            }
        }
    }

}

write-host " Inventory of SAS SSD disks ....."
$data

Disconnect-HPOVMgmt