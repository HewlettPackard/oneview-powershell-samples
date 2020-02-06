# ------------------ Parameters
Param (                    
        [string]$CSVfile,

        [string]$interfaceType             = 'All',
        [string]$mediaType                 = 'All'
      )





      Function Get-disk-from-iLO (
        [string]$serverName,
        [string]$interfaceType, 
        [string]$mediaType,
    
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
    
                                $data   += "$interface,$media,$model,$sn,$fw,$ssdUsage,$powerOnHours"
                        
                            }
    
                        }
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


$diskInventory  = @("Server,serverModel,serverSN,Interface,MediaType,SerialNumber,firmware,ssdEnduranceUtilizationPercentage,powerOnHours")


$date           = (get-date).toString('MM_dd_yyyy') 
$outFile        = "iLO_" + $date + "_disk_Inventory.csv"
$errorFile      = "iLO_" + $date + "_errors.txt"

## Set Message
$diskMessage    = ""
$diskMessage    = if ($interfaceType -ne 'All') { $interfaceType }     else {'SAS or SATA '}
$diskMessage   += if ($mediaType -ne 'All')     { "/ $mediaType "}     else {'/ SSD or HDD '}

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
                write-host "---- Collecting disks information on server ---> $sName"
                $data = Get-disk-from-iLO -serverName $sName -iloSession $iloSession -iloName $iloName -interfaceType $interfaceType -mediaType $mediaType   
                if ($data)
                {
                    $data           = $data | % {"$serverPrefix,$_"}
                    $diskInventory += $data
                }
                else
                {
                    write-host -foreground Yellow "      ------ No $diskMessage disk found on $iloName ...."
                }
                Disconnect-HPERedfish -Session $iloSession -DisableCertificateAuthentication
            }
            catch
            {
                # add ilo to error list
                write-host -ForegroundColor Yellow "Cannot connect to ilo $iloName... Logging information in $errorFile"
                $iloName | out-file -FilePath $errorFile -Append
        
            }
        }

    }

    $diskInventory | Out-File $outFile

    write-host -foreground CYAN "Inventory complete --> file: $outFile "
}
else 
{
    write-host -ForegroundColor YELLOW "Cannot find CSV file wih iLO information ---> $CSVFile . Skip inventory"
}

