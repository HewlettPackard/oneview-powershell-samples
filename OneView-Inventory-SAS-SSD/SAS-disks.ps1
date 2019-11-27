

### Connect to OneView
$cred = get-credential -UserName administrator -message "Provide password"
Connect-HPOVMgmt -hostname  '<OV-IP-here>' -credential $cred

$data       = @()
$CR         = "`n"
$data       = "Server,Interface,Model,SerialNumber" + $CR

### Get Server
$Server_list = Get-HPOVServer

foreach ($s in $Server_List)
{
    $name          = "`'" + $s.Name + "`'" 
    $lStorageUri   = $s.subResources.LocalStorage.uri
    $lStorage      = send-HPOVRequest -uri $lStorageUri

    foreach ($pd in $lStorage.data.PhysicalDrives)
    {
        if (($pd.InterfaceType -eq 'SAS') -and ($pd.MediaType -eq 'SSD'))
        {
            $sn         = $pd.serialNumber
            $interface  = $pd.InterfaceType
            $model      = $pd.Model
            if ($sn)
            {
                $data   += "$name,$interface,$model,$sn" + $CR
            }
        }
    }

}

write-host " Inventory of SAS SSD disks ....."
$data

Disconnect-HPOVMgmt