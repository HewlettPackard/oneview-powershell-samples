
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

$HeaderText = "AlertTypeID|AlertDescription|snmpOID|CorrectiveAction|applianceConnection"

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
}

# ---------------- Modules import
#
import-module $OneViewModule 

$isImportExcelPresent   = (get-module -name "ImportExcel" -listavailable ) -ne $NULL
if (-not $isImportExcelPresent )
{   write-host -foreground YELLOW "Import Excel mopdule not found. Install the module with the command -->  install-module ImportExcel "}

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

$timeStamp          = get-date -format dd-MMM-yyyy

$OutFile            = "alert-snmp-$timeStamp.CSV"

$startDate          = $start.ToShortDateString()
$endDate            = $end.ToShortDateString()
Write-Host -ForegroundColor Cyan "CSV file -->     $OutFile  "
write-host -ForegroundColor CYAN "##NOTE: Delimiter used in the CSV file is '|' "

$scriptCode         =  New-Object System.Collections.ArrayList

foreach ($connection in $global:connectedSessions) 
{
Write-host -ForegroundColor CYAN "`nCollecting Alert from $StartDate to $endDate on OneView $connection ....`n"
if ( [string]::IsNullOrWhiteSpace($Severity))
{
$ListofAlerts   = get-hpovalert -ApplianceConnection $connection  -Start $Start -End $End | where {($_.Severity -eq 'Critical') -or ($_.Severity -eq 'Warning')}
}
else 
{
$ListofAlerts   = get-hpovalert -ApplianceConnection $connection -Start $Start -End $End -Severity $Severity
}

foreach ($alert in $ListofAlerts)
{
$alertDescription           = $alert.Description
$alertTypeID                = $alert.alertTypeID
$correctiveAction           = $alert.CorrectiveAction
$applianceConnection        = $alert.applianceConnection

foreach ($eventUri in $alert.associatedEventUris)
{
    if ($eventUri)
    {
        $ev      = send-HPOVRequest -uri $eventUri -hostname $connection.Name
        foreach ($evItem in $ev.eventDetails)
        {
            $eventName      = $evItem.eventItemName
            $eventSnmpOid   = $evItem.eventItemSnmpOid
            $value          = ""
            if ($eventName -match '^\d.')
            {
                $value              = "$alertTypeID|$alertDescription|$eventName|$correctiveAction|$applianceConnection"
                [void]$scriptCode.Add('{0}' -f $value)
            }
            else 
            {
                if ($eventSnmpOid -match '^\d.')
                {
                    $value          = "$alertTypeID|$alertDescription|$eventSnmpOid|$correctiveAction"
                    [void]$scriptCode.Add('{0}' -f $value) 
                }

            }

        }
    }
}
}
}

# ----- Write to file
$scriptCode = $scriptCode.ToArray() 
Out-ToScriptFile -Outfile $outFile 

# --------------- Create Excel File
#
if ($isImportExcelPresent)
{
$excelFile  = (Dir $outFile).BaseName + ".xlsx"
import-csv -delimiter '|' $outFile | export-Excel -Path $excelFile -WorksheetName "snmp"
}

write-host -ForegroundColor Cyan "-----------------------------------------------------"
write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
write-host -ForegroundColor Cyan "-----------------------------------------------------"

Disconnect-HPOVMgmt -ApplianceConnection $global:connectedSessions



