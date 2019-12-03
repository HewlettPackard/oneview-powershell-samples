# ------------------ Parameters
Param (                    
        [string]$hostName                  = "", 
        [string]$userName                  = "", 
        [string]$password                  = "",
        [string]$authLoginDomain           = "local",

        [string]$interfaceType             = 'All',
        [string]$mediaType                 = 'All'
      )


$CR             = "`n"
$COMMA          = ","

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
        $interfaceFilter     = if ($interfaceType -ne 'All')    {$pd.deviceInterface -eq $interfaceType}  else {$true}
        $mediaFilter         = if ($mediaType -ne 'All')        {$pd.driveMedia -eq $mediaType}          else {$true}
        if ($interfaceFilter -and $mediaFilter )
        {
            $interface      = $pd.deviceInterface
            $media          = $pd.driveMedia
            $name           = $pd.Name
            $sn             = $pd.serialNumber
            $model          = $pd.model
            $fw             = $pd.firmwareVersion
            if ($sn)
            {
                $data      += "$name,$interface,$media,$model,$sn,$fw"
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
                $data   += "$name,$interface,$model,$sn,$fw" 
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
                $pd                  = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $diskOdataid
                $interfaceFilter     = if ($interfaceType -ne 'All')    {$pd.InterfaceType -eq $interfaceType}  else {$true}
                $mediaFilter         = if ($mediaType -ne 'All')        {$pd.mediaType -eq $mediaType}          else {$true}

                if ($interfaceFilter -and $mediaFilter )
                {
                    $sn              = $pd.serialNumber
                    $interface       = $pd.InterfaceType
                    $media           = $pd.mediaType
                    $model           = $pd.Model
                    $fw              = $pd.firmwareversion.current.versionstring
                    $ssdPercentUsage = [int]$pd.SSDEnduranceUtilizationPercentage
                    $ph              = $pd.PowerOnHours
                    if ($sn)
                    {
                        $powerOnHours   = $ssdUsage = ""
                        if ($media -eq 'SSD') 
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
                            $ssdUsage       = "$ssdPercentUsage%"
                        }

                        $data   += "$serverName,$interface,$media,$model,$sn,$fw,$ssdUsage,$powerOnHours"
                   
                    }

                }
            }

        }
    }
    return $data
}



$date           = (get-date).toString('MM_dd_yyyy') 


$diskInventory  = @("Server,Interface,MediaType,Model,SerialNumber,firmware,ssdEnduranceUtilizationPercentage,powerOnHours")
$d3940Inventory = @("diskLocation,Interface,MediaType,Model,SerialNumber,firmware")


### Connect to OneView
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred           = New-Object System.Management.Automation.PSCredential  -ArgumentList $userName, $securePassword


write-host -ForegroundColor Cyan "---- Connecting to OneView --> $hostName"
$connection     = Connect-HPOVMgmt -Hostname $hostName -loginAcknowledge:$true -AuthLoginDomain $authLoginDomain -Credential $cred
$connectionName = $connection.Name 



$outFile        = $connectionName + "_" + $date + "_disk_Inventory.csv"
$d3940outFile   = $connectionName + "_" + "d3940_" + $date + "_disk_Inventory.csv"



## Get D3940

if ($connection.ApplianceType -eq 'Composer')
{
    $d3940_list   = Get-HPOVDriveEnclosure
    if ($d3940_list) 
    {
        foreach ($d3940 in $d3940_list)
        {
            $driveEnclosureName     = $d3940.Name
            write-host "---- Collecting disks information on d3940  --> $driveEnclosureName "
            $data            = D3940-get-disk -DriveEnclosure $d3940  -interfaceType $interfaceType -mediaType $mediaType
            if ($data)
            {
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
}
else 
{
    write-host -foreground Yellow " The appliance is not a Synergy Composer. Skip D3940 inventory ......$CR" 
}

## Set Message
$diskMessage    = ""
$diskMessage    = if ($interfaceType -ne 'All') { $interfaceType }     else {'SAS or SATA '}
$diskMessage   += if ($mediaType -ne 'All')     { "/ $mediaType "}     else {'/ SSD or HDD '}

### Get Server
$Server_list = Get-HPOVServer

foreach ($s in $Server_List)
{
    $data           = @()
    $sName          = $s.Name 
    $sName_noquote  = $sName

    if ($sName -like  "*$COMMA*")
    {
        $sName      = "`"" + $sName + "`"" 
    }

    write-host "---- Collecting disks information on server ---> $sName_noquote"
    $iloSession = $s | get-HPOVilosso -iLORestSession
    $ilosession.rootUri = $ilosession.rootUri -replace 'rest','redfish'

    $data = Get-disk-from-iLO -serverName $sName -iloSession $iloSession -interfaceType $interfaceType -mediaType $mediaType   

    if ($data)
    {

        $diskInventory += $data
    }
    else
    {
        write-host -foreground Yellow "      ------ No $diskMessage disk found on $sName...."
    }
}

$diskInventory | Out-File $outFile

write-host -foreground CYAN "Disk Inventory on server complete --> file: $outFile $CR"




Disconnect-HPOVMgmt