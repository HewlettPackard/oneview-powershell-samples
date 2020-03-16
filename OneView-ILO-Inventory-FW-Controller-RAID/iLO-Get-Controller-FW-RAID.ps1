# ------------------ Parameters
Param (                    
        [string]$CSVfile,
        [Boolean]$All   = $False
      )







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




$CR             = "`n"
$COMMA          = ","


$fwInventory  = @("Server,serverModel,serverSN,controllerModel,controllerFirmware,RaidLevel")


$date           = (get-date).toString('MM_dd_yyyy') 
$outFile        = "iLO_" + $date + "_ControllerFW_Raid_Inventory.csv"
$errorFile      = "iLO_" + $date + "_errors.txt"


### Access CSV
if (test-path $CSVfile)
{
    $CSV        = import-csv $CSVFile
    foreach ($ilo in $CSV)
    {
        $data               = ""
        $iloName            = $ilo.iloName
        if ( ($iloName) -or ($iloName -notlike '#*')) 
        {
            $username       = $ilo.userName
            $securePassword = $ilo.password | ConvertTo-SecureString -AsPlainText -Force
            $cred           = New-Object System.Management.Automation.PSCredential  -ArgumentList $userName, $securePassword

            try 
            {
                ## Connect to iLO
                $iloSession     = Connect-HPERedfish -Address $iloName -Cred $cred -DisableCertificateAuthentication

                ## Get server name
                $systems= Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid '/redfish/v1/Systems'                                                                                                     
                foreach ($sysOdataid in $systems.Members.'@odata.id' )
                {
                    $computerSystem = Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid $sysOdataid
                    $sName          = $computerSystem.HostName
                    $sModel         = $computerSystem.Model
                    $sSN            = $computerSystem.SerialNumber
                    $serverPrefix   = "$sName,$sModel,$sSN"
                }
                
                if ($All)
                {
                    $genModel         = $true
                }
                else 
                {
                    $genModel         = $sModel -like '*Gen10'    
                }
                if ($genModel)
                {
                    write-host "---- Collecting controller FW and RAID information on server ---> $sName" 
                    $data = Get-fwController-RAID-from-iLO   -serverName $sName -iloSession $iloSession 
                    if ($data)
                    {
                        $data           = $data | % {"$serverPrefix,$_"}
                        $fwInventory    += $data
                    }
                    else
                    {
                        write-host -foreground Yellow "      ------ server $sName is NOT Gen10 or No controller found on $sName...."
                    }
                    Disconnect-HPERedfish -Session $iloSession -DisableCertificateAuthentication
                }
            }
            catch
            {
                # add ilo to error list
                write-host -ForegroundColor Yellow "Cannot connect to ilo $iloName... Logging information in $errorFile"
                $iloName | out-file -FilePath $errorFile -Append
        
            }
        }

    }

    $fwInventory | Out-File $outFile

    write-host -foreground CYAN "Inventory complete --> file: $outFile "
}
else 
{
    write-host -ForegroundColor YELLOW "Cannot find CSV file wih iLO information ---> $CSVFile . Skip inventory"
}

