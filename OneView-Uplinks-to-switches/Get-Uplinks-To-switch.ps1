
Param ( [string]$OVApplianceIP      ="",
        [string]$OVlistCSV          = "",
        [PScredential]$OVcredential = $Null,
        [string]$OVAdminName        ="", 
        [string]$OVAdminPassword    ="",
        [string]$OVAuthDomain       = "local",

        [string]$OneViewModule      = "HPOneView.410",  

        [dateTime]$Start              = (get-date -day 1) ,
        [dateTime]$End                = (get-date) , 
        [string]$Severity           = ''                 # default will be critical and warning

)
#$ErrorActionPreference = 'SilentlyContinue'
$DoubleQuote    = '"'
$CRLF           = "`r`n"
$Delimiter      = "\"   # Delimiter for CSV profile file
$SepHash        = ";"   # USe for multiple values fields
$Sep            = ";"
$hash           = '@'
$SepChar        = '|'
$CRLF           = "`r`n"
$OpenDelim      = "{"
$CloseDelim     = "}" 
$CR             = "`n"
$Comma          = ','
$Equal          = '='
$Dot            = '.'
$Underscore     = '_'

$Syn12K                   = 'SY12000' # Synergy enclosure type

Function Prepare-OutFile ([string]$Outfile)
{

$filename   = $outFile.Split($Delimiter)[-1]
$ovObject   = $filename.Split($Dot)[0] 

New-Item $OutFile -ItemType file -Force -ErrorAction Stop | Out-Null

$HeaderText = "switch|IP|OneView|interConnect|uplinkSet|port|portID"
$worksheetName = "uplinks-to-switch"

write-host -ForegroundColor Cyan "CSV file --> $((dir $outFile).FullName)"
Set-content -path $outFile -Value $HeaderText
}

Function Out-ToScriptFile ([string]$Outfile)
{
    if ($ScriptCode)
    {
        Prepare-OutFile -outfile $OutFile
        Add-Content -Path $OutFile -Value $ScriptCode
    } 
    else 
    {
        write-host -foreground YELLOW "No data found. Skip generating CSV file...."    
    }
}

# ---------------- Modules import
#
import-module $OneViewModule 

$isImportExcelPresent   = (get-module -name "ImportExcel" -listavailable ) -ne $NULL
if (-not $isImportExcelPresent )
{   write-host -foreground YELLOW "Import Excel module not found. Install the module with the command -->  install-module ImportExcel "}

# ---------------- Connect to OneView appliance
#
$ScriptDir          = Split-Path $script:MyInvocation.MyCommand.Path
# ---------------- Connect to OneView appliance
#
write-host -ForegroundColor Cyan "-----------------------------------------------------"
write-host -ForegroundColor Cyan "Connect to OneView appliance..."
write-host -ForegroundColor Cyan "-----------------------------------------------------"
if (-not $OVcredential)
{
$OVcredential  = get-credential -message "Provide  credential to access the Oneview environment..."
}
if ([string]::IsNullOrEmpty($OVlistCSV) -or (-not (test-path -path $OVlistCSV)) )
{
Connect-HPOVMgmt -appliance $OVApplianceIP -Credential $OVcredential 
}
else 
{
$OVlistCSV      = $OVlistCSV.Split($Delimiter)[-1]
$OVlistCSV      = "$ScriptDir\$OVlistCSV"

type $OVlistCSV | % { Connect-HPOVMgmt -Hostname $_ -Credential $OVcredential }    
}

# ---------------------------
#  Generate Output files

$timeStamp          = [DateTime]::Now.ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ss.ff.fffZzzz').Replace(':','')

$OutFile            = "uplink-to-switch-$timeStamp.CSV"

$startDate          = $start.ToShortDateString()
$endDate            = $end.ToShortDateString()
#Write-Host -ForegroundColor Cyan "CSV file -->     $OutFile  "
write-host -ForegroundColor CYAN "##NOTE: Delimiter used in the CSV file is '|' "

$scriptCode         =  New-Object System.Collections.ArrayList
$F8partNumber       = '794502-B23'   # VC F8 40GB
$uplinkSetName      = ""

foreach ($connection in $global:connectedSessions) 
{
    Write-host -ForegroundColor CYAN "`nGetting uplinks on Interconnects of OneView $connection ....`n"

    $connectionName         = $connection.Name
    $ListofInterconnects   = get-hpovInterConnect  -ApplianceConnection $connection  | where partNumber -match $F8partNumber 

    foreach ($IC in $ListofInterconnects)
    {
        $ICname                 = $IC.Name
        $listofPorts            = $IC.Ports | where portType -eq 'Uplink' | where portstatus -eq 'Linked' #| where associatedUplinkSetUri -ne $NULL


        foreach ($port in $listofPorts)
        {
            if ($port.associatedUplinkSetUri)
            {
                $uplinkSetName = (Send-HPOVRequest -uri $port.associatedUplinkSetUri -hostname $connectionName).Name
                $remotePortID   = $port.neighbor.remotePortID

                if ($uplinksetName -notlike '*Image*Streamer*') 
                {

                    $portName       = $port.name
                    Start-Sleep -Milliseconds 10
                    $remoteIP       = $port.neighbor.remoteMgmtAddress
                    $remoteSystem   = $port.neighbor.remoteSystemName

                    # --- Write value
                                        # "switch|IP|OneView|interConnect|uplinkSet|port|portID"
                    $value          = "$remoteSystem|$remoteIP|$connectionName|$ICname|$uplinkSetName|$portName|$remotePortID"
                    [void]$scriptCode.Add('{0}' -f $value)
                }


            }
        }


    }
}

# --- Write to file
$scriptCode = $scriptCode.ToArray() 
Out-ToScriptFile -Outfile $outFile 

# --------------- Create Excel File
#
if ($isImportExcelPresent)
{
    if (test-path $Outfile)
    {
        $excelFile  = (Dir $outFile).BaseName + ".xlsx"
        import-csv -delimiter '|' $outFile | export-Excel -Path $excelFile -WorksheetName $worksheetName
    }
}

write-host -ForegroundColor Cyan "-----------------------------------------------------"
write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
write-host -ForegroundColor Cyan "-----------------------------------------------------"

Disconnect-HPOVMgmt -ApplianceConnection $global:connectedSessions



