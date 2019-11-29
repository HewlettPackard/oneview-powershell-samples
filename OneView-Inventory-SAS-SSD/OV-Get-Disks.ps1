# ------------------ Parameters
Param (                    
        [string]$hostName                  = "", 
        [string]$userName                  = "", 
        [string]$password                  = "",
        [string]$authLoginDomain           = "local",

        [string]$interfaceType             = 'SAS',
        [string]$mediaType                 = 'SSD'
      )

# ---- D3940 Inventory
Function D3940-get-disk(
    $DriveEnclosure,
    [string]$interfaceType, 
    [string]$mediaType

)
{
    $data   = @()

    $driveBays      = $driveEnclosure.driveBays
    foreach ($pd in $driveBays.drive)
    {
        if (($pd.deviceInterface -eq $interfaceType) -and ($pd.driveMedia -eq $mediaType))  
        {
            $interface      = $pd.deviceInterface
            $name           = $pd.Name
            $sn             = $pd.serialNumber
            $model          = $pd.model
            $fw             = $pd.firmwareVersion
            if ($sn)
            {
                $data      += "$name,$interface,$model,$sn,$fw" + $CR
            }

        }      
    }

    return $data

}

# ---- Gen10 inventory 
Function Gen10-get-disk (
    [string]$serverName,
    [string]$interfaceType, 
    [string]$mediaType,

    $server
    )
{

    $data = @()
    $lStorageUri   = $server.subResources.LocalStorage.uri
    $lStorage      = send-HPOVRequest -uri $lStorageUri

    foreach ($pd in $lStorage.data.PhysicalDrives)
    {
        if (($pd.InterfaceType -eq $interfaceType) -and ($pd.MediaType -eq $mediaType))
        {
            $sn         = $pd.serialNumber
            $interface  = $pd.InterfaceType
            $model      = $pd.Model
            $fw         = $pd.firmwareversion.current.versionstring
            if ($sn)
            {
                $data   += "$name,$interface,$model,$sn,$fw" + $CR
            }
        }
    }

    return $data
}


# ------  Inventory thru iLO ( Gen8-9-10)
Function Get-disk-from-iLO (
    [string]$serverName,
    [string]$interfaceType, 
    [string]$mediaType,

    $iloSession
    )

    
{
    $data = @()
    $systems= Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid '/redfish/v1/Systems'                                                                                                     
    foreach ($sys in $systems.Members.'@odata.id' )
    {
        $arrayControllerOdataid =   $sys + 'SmartStorage/ArrayControllers'
        $arrayControllers       =   Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $arrayControllerOdataid
        foreach ($controllerOdataid in $arrayControllers.Members.'@odata.id')
        {
            $controller         = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $controllerOdataid
            $ddOdataid          = $controller.links.PhysicalDrives.'@odata.id'
            $diskDrives         = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $ddOdataid
            foreach ($diskOdataid in $diskDrives.Members.'@odata.id')
            {
                $pd             = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $diskOdataid
                if (($pd.InterfaceType -eq $interfaceType) -and ($pd.MediaType -eq $mediaType))
                {
                    $sn              = $pd.serialNumber
                    $interface       = $pd.InterfaceType
                    $model           = $pd.Model
                    $fw              = $pd.firmwareversion.current.versionstring
                    $ssdPercentUsage = [int]$pd.SSDEnduranceUtilizationPercentage
                    $ph              = $pd.PowerOnHours
                    if ($sn)
                    {
                        $years = $months = $days = 0
                        if ($ph)
                        {
                            # Calculate poweronHours
                            $tp         = new-timespan -hours $ph 
                            $days       = [int]($tp.days)
                            $hours      = [int]($tp.hours)
                            $years      = [math]::floor($days / 365)  
                            $m          = $days % 365
                            $months     = [math]::floor($m / 30)
                            $days       = $m % 30

                        }
                        $powerOnHours   = "$years years-$months months-$days days-$hours hours"

                        $data   += "$serverName,$interface,$model,$sn,$fw,$ssdPercentUsage%,$powerOnHours" + $CR
                   
                    }
                }
            }

        }
    }

    return $data
}

$CR             = "`n"
$COMMA          = ","

$date           = (get-date).toString('MM_dd_yyyy') 
$diskInventory  = @()
$d3940Inventory = @()

$diskInventory  = "Server,Interface,Model,SerialNumber,firmware,ssdEnduranceUtilizationPercentage,powerOnHours" + $CR
$d3940Inventory = "diskLocation,,Interface,Model,SerialNumber,firmware" + $CR


### Connect to OneView
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred           = New-Object System.Management.Automation.PSCredential  -ArgumentList $userName, $securePassword


write-host -ForegroundColor Cyan "---- Connecting to OneView --> $hostName"
$connection     = Connect-HPOVMgmt -Hostname $hostName -loginAcknowledge:$true -AuthLoginDomain $authLoginDomain -Credential $cred
$connectionName = $connection.Name 



$outFile        = $connectionName + "_" + $date + "_disk_Inventory.csv"
$d3940outFile   = "d3940_" + $date + "_disk_Inventory.csv"



## Get D3940
$d3940_list   = Get-HPOVDriveEnclosure
if ($d3940_list) 
{
    foreach ($d3940 in $d3940_list)
    {
        $driveEnclosureName     = $d3940.Name
        write-host "---- Collecting disk of type $interfaceType-$mediaType on d3940  --> $driveEnclosureName "
        $data            = D3940-get-disk -DriveEnclosure $d3940  -interfaceType $interfaceType -mediaType $mediaType
        if ($data)
        {
            $data             = $data | % {$_.TrimStart()}
            $d3940Inventory  += $data 
        }

    }
    $d3940Inventory  | Out-File $d3940outFile 
    write-host -foreground CYAN "Disk Inventory on d3940 complete --> file: $d3940outFile $CR"
}
else 
{
    write-host -foreground Yellow " No D3940 found. Skip inventory ......$CR"    
}

### Get Server
$Server_list = Get-HPOVServer

foreach ($s in $Server_List)
{
    $sName          = $s.Name 
    if ($sName -like  "*$COMMA*")
    {
        $sName      = "`"" + $sName + "`"" 
    }

    write-host "---- Collecting disk of type $interfaceType-$mediaType on server ---> $sName"
    $iloSession = $s | get-HPOVilosso -iLORestSession
    $ilosession.rootUri = $ilosession.rootUri -replace 'rest','redfish'

    $data = Get-disk-from-iLO -serverName $sName -iloSession $iloSession -interfaceType $interfaceType -mediaType $mediaType   

    if ($data)
    {
        $data           = $data | % {$_.TrimStart()}
        $diskInventory += $data
    }
}

$diskInventory | Out-File $outFile

write-host -foreground CYAN "Disk Inventory on server complete --> file: $outFile $CR"




Disconnect-HPOVMgmt