# ------------------ Parameters
Param (                    
        [string]$hostName                  = "", 
        [string]$userName                  = "", 
        [string]$password                  = "",
        [string]$authLoginDomain           = "local",
        [Boolean]$All                      = $false                          
      )


$CR             = "`n"
$COMMA          = ","




    # ------  Inventory thru iLO ( Gen8-9-10)
    Function Get-fwController-RAID-from-iLO (
        [string]$serverName,
        $iloSession
        )
    
        
    {
        $data = @()
        try {
            
            $systems= Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid '/redfish/v1/Systems'                                                                                                     
            foreach ($sys in $systems.Members.'@odata.id' )
            {
                if ($sys[-1] -eq '/')
                {
                    $arrayControllerOdataid =   $sys + 'SmartStorage/ArrayControllers'
                }
                else 
                {
                    $arrayControllerOdataid =   $sys + '/SmartStorage/ArrayControllers'
                }
    
                $arrayControllers       =   Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $arrayControllerOdataid
                foreach ($controllerOdataid in $arrayControllers.Members.'@odata.id')
                {
                    $controller         = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $controllerOdataid
                    $controllerFW       = $controller.FirmwareVersion.current.VersionString 
                    $controllerModel    = $controller.Model
    
                    # ---- Get Logical disks
                    $ldOdataid          = $controller.links.LogicalDrives.'@odata.id'
                    $logicalDrives      = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $ldOdataid
                    foreach ($driveOdataid in $logicalDrives.Members.'@odata.id')
                    {
                        $ld                  = Get-HPERedfishDataRaw -session $iloSession -DisableCertificateAuthentication  -odataid $driveOdataid
                        $raid                = $ld.Raid
                        $data               += "$controllerModel,$controllerFw,$raid"
    
                    }
    
                }
            }
    
        }
        catch
        {
            # add server to error list
            write-host -ForegroundColor Yellow "Cannot connect to server $serverName... Logging information in $errorFile"
            $serverName | out-file -FilePath $errorFile -Append
    
        }
    
        return $data
    }
    



$date           = (get-date).toString('MM_dd_yyyy') 

$fwInventory  = @("Server,serverModel,serverSN,controllerModel,controllerFirmware,RaidLevel")



### Connect to OneView
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred           = New-Object System.Management.Automation.PSCredential  -ArgumentList $userName, $securePassword


write-host -ForegroundColor Cyan "---- Connecting to OneView --> $hostName"
$connection     = Connect-HPOVMgmt -Hostname $hostName -loginAcknowledge:$true -AuthLoginDomain $authLoginDomain -Credential $cred
$connectionName = $connection.Name 



$outFile        = $connectionName + "_" + $date + "_ControllerFW_Raid_Inventory.csv"
$errorFile      = $connectionName + $date + "_errors.txt"



### Get Server
$Server_list = Get-HPOVServer  | where mpModel -notlike '*ilo3*'

foreach ($s in $Server_List)
{
    $data           = @()
    $sName          = $s.Name 
    $sName_noquote  = $sName
    $sModel         = $s.Model
    $sSN            = $s.SerialNumber

    $sName          = $sName -replace ", " , '-'
    $serverPrefix   = "$sName,$sModel,$sSN"

    if ($sName -like  "*$COMMA*")
    {
        $sName      = "`"" + $sName + "`"" 
    }

    if ($All)
    {   # Collect all servers Gen8 - Gen 9 - Gen10
        write-host "---- Collecting controller FW and RAID information on server ---> $sName_noquote"
        $iloSession = $s | get-HPOVilosso -iLORestSession
        $ilosession.rootUri = $ilosession.rootUri -replace 'rest','redfish'

        $data = Get-fwController-RAID-from-iLO   -serverName $sName -iloSession $iloSession 
    }
    else 
    {       # GEn10 only
        if ($sModel -like '*Gen10')
        {
            $lsUri      = $s.subResources.LocalStorage.uri
            if ($lsUri)
            {
                $lsData         = (send-HPOVRequest -uri $lsUri).data
                foreach($ls in $lsData)
                {
                    $controllerFw   = $ls.FirmwareVersion.current.versionString
                    $controllerModel = $ls.Model
                    $logicalDrives  = $ls.LogicalDrives
                    foreach ($ld in $logicalDrives)
                    {
                        $raid       = $ld.raid
                        $data       += "$controllerModel,$controllerFw,$raid"
                    }
                }
            }

        }
    }    

    if ($data)
    {
        $data           = $data | % {"$serverPrefix,$_"}
        $fwInventory    += $data 
    }
    else
    {
        write-host -foreground Yellow "      ------ server $sName is NOT Gen10 or No controller found on $sName...."
    }
}

$fwInventory | Out-File $outFile

write-host -foreground CYAN "FW and RAID Inventory on server complete --> file: $outFile $CR"




Disconnect-HPOVMgmt