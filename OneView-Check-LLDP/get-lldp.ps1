
Param ( [string]$OVApplianceIP      ="",
        [string]$OVlistCSV          = "",
        [PScredential]$OVcredential = $Null,
        [string]$OVAdminName        ="", 
        [string]$OVAdminPassword    ="",
        [string]$OVAuthDomain       = "local",

        [string]$OneViewModule      = "HPOneView.410"

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
$Prefix         = "lldp-LI"
$HeaderText     = "OneView|LogicalInterConnect|enableTaggedLldp|lldpIpv4Address|lldpIpv6Address"
$worksheetName  = "lldp on LI"
$columsToAlign  = @(3)  # enableTaggedLldp
$alignType      = "center"
$F8partNumber   = '794502-B23'   # VC F8 40GB

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

$OutFile            = "$prefix-$timeStamp.CSV"

#Write-Host -ForegroundColor Cyan "CSV file -->     $OutFile  "
write-host -ForegroundColor CYAN "##NOTE: Delimiter used in the CSV file is '|' "

$scriptCode         =  New-Object System.Collections.ArrayList

$uplinkSetName      = ""

foreach ($connection in $global:connectedSessions) 
{
    Write-host -ForegroundColor CYAN "`nGetting uplinks on Interconnects of OneView $connection ....`n"

    $connectionName         = $connection.Name
    $ListofLIs              = get-hpovLogicalInterConnect  -ApplianceConnection $connection 


    foreach ($LI in $ListofLIs)
    {
        $LIname             = $LI.Name
        $ethernetSettings   = $LI.ethernetSettings

        $lldpEnable         = $ethernetSettings.enableTaggedLldp
        $lldpIpV4           = $ethernetSettings.lldpIpv4Address
        $lldpIpV6           = $ethernetSettings.lldpIpv6Address   

        # --- Write value
        #                   "OneView|LogicalInterConnect|enableTaggedLldp|lldpIpv4Address|lldpIpv6Address""
        $value              = "$connectionName|$LIname|$lldpEnable|$lldpIpV4|$lldpIpV6"
        [void]$scriptCode.Add('{0}' -f $value)


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
        $csvobject  = import-csv -delimiter '|' $outFile | sort portID 
        generate-Excel -excelFile  $excelFile -WorksheetName $WorksheetName -csvObject $csvobject -columnsToAlign $columsToAlign -alignType $alignType
    
    }
}

write-host -ForegroundColor Cyan "-----------------------------------------------------"
write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
write-host -ForegroundColor Cyan "-----------------------------------------------------"

Disconnect-HPOVMgmt -ApplianceConnection $global:connectedSessions



