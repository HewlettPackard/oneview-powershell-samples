# ------------------ Parameters
Param (                    
        [string]$CSVfile,

        [string]$interfaceType             = 'SAS',
        [string]$mediaType                 = 'SSD'
      )



Function Get-disk (
    [string]$serverName,
    [string]$iloName,
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
                        $data   += "$serverName,$iloName,$interface,$model,$sn,$fw" + $CR
                   
                    }
                }
            }

        }
    }

    return $data
}

Function Get-disk-from-iLO (
    [string]$serverName,
    [string]$iloName,
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

                        $data   += "$serverName,$iloName,$interface,$model,$sn,$fw,$ssdPercentUsage%,$powerOnHours" + $CR
                   
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
$diskInventory  = "Server,iloName,Interface,Model,SerialNumber,firmware,ssdEnduranceUtilizationPercentage,powerOnHours" + $CR


$date           = (get-date).toString('MM_dd_yyyy') 
$outFile        = "iLO_" + $date + "_disk_Inventory.csv"


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


            ## Connect to iLO
            $iloSession     = Connect-HPERedfish -Address $iloName -Cred $cred -DisableCertificateAuthentication

            ## Get server name
            $systems= Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid '/redfish/v1/Systems'                                                                                                     
            foreach ($sysOdataid in $systems.Members.'@odata.id' )
            {
                $computerSystem = Get-HPERedfishDataRaw  -session $iloSession -DisableCertificateAuthentication  -odataid $sysOdataid
                $sName          = $computerSystem.HostName
            }
            write-host "---- Collecting disk of type $interfaceType-$mediaType on server ---> $sName"
            $data = Get-disk-from-iLO -serverName $sName -iloSession $iloSession -iloName $iloName -interfaceType $interfaceType -mediaType $mediaType   
            if ($data)
            {
                $diskInventory += $data
            }
            else
            {
                write-host -foreground Yellow "      ------ No $interfaceType/$mediaType disk found on $iloName ...."
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

