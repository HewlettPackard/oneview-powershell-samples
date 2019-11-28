# ------------------ Parameters
Param (                    
        [string]$hostName                  = "", 
        [string]$userName                  = "", 
        [string]$password                  = "",
        [string]$authLoginDomain           = "local",

        [string]$interfaceType             = 'SAS',
        [string]$mediaType                 = 'SSD'
      )


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


# ------ Gen 8/9 Inventory
Function Gen89-get-disk (
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
                    $sn         = $pd.serialNumber
                    $interface  = $pd.InterfaceType
                    $model      = $pd.Model
                    $fw         = $pd.firmwareversion.current.versionstring
                    if ($sn)
                    {
                        $data   += "$serverName,$interface,$model,$sn,$fw" + $CR
                   
                    }
                }
            }

        }
    }

    return $data
}

$CR             = "`n"
$COMMA          = ","

$diskInventory  = @()
$diskInventory  = "Server,Interface,Model,SerialNumber,firmware" + $CR

$date           = (get-date).toString('MM_dd_yyyy') 
$outFile        = $connectionName + "_" + $date + "_disk_Inventory.csv"


### Connect to OneView
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred           = New-Object System.Management.Automation.PSCredential  -ArgumentList $userName, $securePassword


write-host -ForegroundColor Cyan "----- Connecting to OneView --> $hostName"
$connection     = Connect-HPOVMgmt -Hostname $hostName -loginAcknowledge:$true -AuthLoginDomain $authLoginDomain -Credential $cred
$connectionName = $connection.Name 



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

    $sModel     = $s.shortModel
    if ($sModel -like '*Gen10*')
    {
        $data = Gen10-get-disk -server $s -serverName $sName  -interfaceType $interfaceType -mediaType $mediaType
        if ($data)
        {
            $diskInventory += $data
        }
    }
    else # Gen8 or Gen9
    {
        $iloSession = $s | get-HPOVilosso -iLORestSession
        $ilosession.rootUri = $ilosession.rootUri -replace 'rest','redfish'

        $data = Gen89-get-disk -serverName $sName -iloSession $iloSession -interfaceType $interfaceType -mediaType $mediaType   
        if ($data)
        {
            $diskInventory += $data
        }
    }

}

$diskInventory | Out-File $outFile

write-host -foreground CYAN "Inventory complete --> file: $outFile "

Disconnect-HPOVMgmt