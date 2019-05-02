

Param (
    $credential , 
    $hostname, 
    $AuthLoginDomain = "local", 
    $OneViewModule      = "HPOneView.410"
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
$Prefix         = "LI-Pre-Check"
if ($isImportExcelPresent)
{
    $worksheetName  = "LI-Pre-Check"
    $HeaderText     = "logicalInterconnect|consistentState|stackingHealth|uplinkSet|portName|portStatus|LAGstate|applianceConnection"
    $columsToAlign  = @(2,3,6,7)  # consistentState|stackingHealth|portStatus|LAGstate
    $alignType      = "center"
    $conditions      = @(
        New-ConditionalText unlink red
        New-ConditionalText disabled red
        New-ConditionalText Linked Blue Cyan
        New-ConditionalText CONSISTENT Blue Cyan
        New-ConditionalText redundantBlue Cyan
        )
}

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
        $xl = $csvObject| Export-Excel -Path $excelFile -KillExcel -WorkSheetname $worksheetname -BoldTopRow -AutoSize -PassThru -ConditionalText $conditions
        $Sheet = $xl.Workbook.Worksheets[$worksheetName]
 
        if ($columnsToAlign)
        { 
            $columnsToAlign | % { Set-ExcelColumn -Worksheetname $worksheetName -ExcelPackage $xl -Column $_ -HorizontalAlignment $alignType}
        }
        # custom heading
        Set-ExcelRow -Worksheet $sheet -Row 1  -FontSize 15 -BorderBottom thick -BorderColor darkblue -fontname Calibri -fontcolor darkblue -HorizontalAlignment center
        
        Close-ExcelPackage $xl 

        write-host -ForegroundColor Cyan "Excel file --> $((dir $excelFile).FullName)"
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
#import-module $OneViewModule 

$isImportExcelPresent   = (get-module -name "ImportExcel" -listavailable ) -ne $NULL
if (-not $isImportExcelPresent )
{   write-host -foreground YELLOW "Import Excel module not found. Install the module with the command -->  install-module ImportExcel "}

# ---------------- Connect to OneView appliance
#
$ScriptDir          = Split-Path $script:MyInvocation.MyCommand.Path
# ---------------- Connect to OneView appliance
#

if (-not $credential)
{
    $credential = get-credential -message "Please provide admin credential to log into...."
}


if (-not ($hostname))
{
    $hostname   = read-host "Please provide the FQDN name or IP address of OneView"
}

write-host -foreground CYAN  '#################################################'
write-host -foreground CYAN  "Connecting to OneView ... $hostname"
write-host -foreground CYAN  '##################################################'
Connect-HPOVMgmt -hostname $hostname -Credential $credential  -AuthLoginDomain  $AuthLoginDomain

# ---------------------------
#  Generate Output files

$timeStamp          = [DateTime]::Now.ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ss.ff.fffZzzz').Replace(':','')

$OutFile            = "$Prefix-$timeStamp.CSV"


write-host -ForegroundColor CYAN "##NOTE: Delimiter used in the CSV file is '|' "

$scriptCode         =  New-Object System.Collections.ArrayList

foreach ($connection in $global:connectedSessions) 
{
    $connectionName = $connection.name

    # --------- Get Appliance snmp settings
    $listofLIs         = Get-HPOVLogicalInterconnect -ApplianceConnection $connectionName
    foreach ($LI in $listofLIs)
    {
        $LIname             = $LI.name
        $consistencyStatus  = $LI.consistencyStatus
        $stackingHealth     = if ( $LI.stackingHealth -eq 'biConnected') {'Redundantly connected'} else { $LI.stackingHealth}
        $IClist             = $LI.interconnects | % { send-hpovrequest -uri $_ -hostname $connectionName}  
        foreach ($IC in $IClist)
        {
            
            $portList       = $IC.ports |  where {($_.porttype -eq 'Uplink')  -and (-not ([string]::IsNullorEmpty($_.associatedUplinkSetUri) )) }
            foreach ($port in $portList)
            {
                $portName           = $port.interconnectName + "," + $port.name
                $portStatus         = $port.portStatus + " " + $port.portStatusReason

                $portLAGstate       = ""
                if ($port.neighbor -ne $NULL )
                {
                    $portLAGstate   = "LACP Activity" 
                }

                $uplsetName         = (Send-HPOVRequest -uri $port.associatedUplinkSetUri -hostname $connectionName).name

                          
                # "logicalInterconnect|consistentState|stackingHealth|uplinkSet|portName|portStatus|LAGstate|applianceConnection"
                $value          = "$LIname|$consistencyStatus|$stackingHealth|$uplsetName|$portName|$portStatus|$portLAGstate|$connectionName"
                [void]$scriptCode.Add('{0}' -f $value)
            }
        }  
      
        $value          = "|||||||"
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
        $csvobject  = import-csv -delimiter '|' $outFile 
        generate-Excel -excelFile  $excelFile -WorksheetName $WorksheetName -csvObject $csvobject -columnsToAlign $columsToAlign -alignType $alignType
    }
}

write-host -ForegroundColor Cyan "-----------------------------------------------------"
write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
write-host -ForegroundColor Cyan "-----------------------------------------------------"

Disconnect-HPOVMgmt -ApplianceConnection $global:connectedSessions



