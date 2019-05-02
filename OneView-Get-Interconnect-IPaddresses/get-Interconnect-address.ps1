
Param ( [string]$OVApplianceIP      ="",
[string]$OVlistCSV          = "",
[PScredential]$OVcredential = $Null,
[string]$OVAdminName        ="", 
[string]$OVAdminPassword    ="",
[string]$OVAuthDomain       = "local",

[string]$OneViewModule      = "HPOneView.410",  

[switch]$All,
[dateTime]$Start            = (get-date -day 1) ,
[dateTime]$End              = (get-date) , 
[string]$Severity           = ''                # default will be critical and warning


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

# -----------------------------  Custom data
$Prefix         = "Interconnect-Address"
$worksheetName  = "Interconnect-Address"
$HeaderText     = "applianceConnection|interconnect|ipV4|ipV6"
$columsToAlign  = @()  # caseID, trap
$alignType      = "center"

function Generate-Excel 
{
Param (
[string]$excelFile,
[string]$worksheetName,
[PSCustomObject]$csvObject,
[array]$columnsToAlign,
[string]$alignType      = "left"   
)

if ($csvObject)
{
$xl = $csvObject| Export-Excel -Path $excelFile -KillExcel -WorkSheetname $worksheetname -BoldTopRow -AutoSize -PassThru
$Sheet = $xl.Workbook.Worksheets[$worksheetName]

if ($columnsToAlign)
{ 
    $columnsToAlign | % { Set-ExcelColumn -Worksheetname $worksheetName -ExcelPackage $xl -Column $_ -HorizontalAlignment $alignType}
}
# custom heading
Set-ExcelRow -Worksheet $sheet -Row 1  -FontSize 15 -BorderBottom thick -BorderColor darkblue -fontname Calibri -fontcolor darkblue -HorizontalAlignment center

Close-ExcelPackage $xl 
}
}

Function Prepare-OutFile ([string]$Outfile)
{

$filename   = $outFile.Split($Delimiter)[-1]
$ovObject   = $filename.Split($Dot)[0] 

New-Item $OutFile -ItemType file -Force -ErrorAction Stop | Out-Null

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

$OutFile            = "$Prefix-$timeStamp.CSV"

$startDate          = $start.ToShortDateString()
$endDate            = $end.ToShortDateString()

write-host -ForegroundColor CYAN "##NOTE: Delimiter used in the CSV file is '|' "

$scriptCode         =  New-Object System.Collections.ArrayList

foreach ($connection in $global:connectedSessions) 
{



$ListofLIs      = get-hpovInterconnect -ApplianceConnection $connection  


foreach ($LI in $ListofLIs)
{
$applianceConnection    = $LI.ApplianceConnection
$ipAddressList          = $LI.ipAddressList
$liName                 = $LI.name           
Write-host -ForegroundColor CYAN "`nCollecting ip V4 and V6 addresses of Interconnect  $liName ....`n"
if ($ipAddressList)
{
    # Collect ip information
    $ipV4               = $ipAddressList.ipaddress[0]
    $ipV6               = $ipAddressList.ipaddress[1]

                        # "applianceConnection|interconnectName|ipV4|ipV6"
    $value              = "$applianceConnection|$liName|$ipV4|$ipV6"
    [void]$scriptCode.Add('{0}' -f $value)
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
$csvobject  = import-csv -delimiter '|' $outFile 
generate-Excel -excelFile  $excelFile -WorksheetName $WorksheetName -csvObject $csvobject -columnsToAlign $columsToAlign -alignType $alignType
}
}

write-host -ForegroundColor Cyan "-----------------------------------------------------"
write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
write-host -ForegroundColor Cyan "-----------------------------------------------------"

Disconnect-HPOVMgmt -ApplianceConnection $global:connectedSessions



