 # -------------------------------------------------------------------------------------------------------------
##
##
##      Description: Creator functions
##
## DISCLAIMER
## The sample scripts are not supported under any HP standard support program or service.
## The sample scripts are provided AS IS without warranty of any kind. 
## HP further disclaims all implied warranties including, without limitation, any implied 
## warranties of merchantability or of fitness for a particular purpose. 
##
##    
## Scenario
##     	Automate setup of objects in OneView
##		
##
## Input parameters:
##         ExcelFile                    = NAme of the Excel file
##
## History: 
##
##        January 2016   : - v1.0 release
##
## Version : 1.0
##
##
## -------------------------------------------------------------------------------------------------------------

 Param ( [string]$excelFile = "c:\oneview\ilosettings.xlsx")

    #
    # Hash table to generate CSV file based on names of each worksheet
    #
    

     $CSVNames = @{
         "EthernetNetworks"         = "1-Ethernetnetworks.csv"

         "SANManager"               = "2a-SANManager.csv"
         "StorageSystem"            = "3a-StorageSystem.csv"
         "FCNetworks"               = "3b-FCNetworks.csv"

         "StorageVolumeTemplate"    = "4a-StorageVolumeTemplate.csv"
         "StorageVolume"            = "4b-StorageVolume.csv"
     
         "LogicalInterConnectGroup" = "5-LogicalInterConnectGroup.csv"
         "UpLinkSet"                = "6-UpLinkSet.csv"

         "EnclosureGroup"           = "7-EnclosureGroup.csv" 
         "Enclosure"                = "8-Enclosure.csv"  
         
          
     
         "Profile"                  = "9a-Profile.csv"
         "ProfileConnection"        = "9b-ProfileConnection.csv"
         "ProfileStorage"           = "9c-ProfileStorage.csv"
         
         "iLOAccount"              = "iLOAccount.csv"  
     }

     if (Test-Path $ExcelFile)
     {
         $DirName = (dir $ExcelFile).DirectoryName
         if ($DirName[-1] -ne "\")
            { $DirName += "\"}


         Add-Type -AssemblyName Microsoft.Office.Interop.Excel
         $xl=New-Object -ComObject Excel.Application
         $xl.Visible = $false
         $xl.DisplayAlerts = $false

         $wb = $xl.Workbooks.Open($excelFile)
         $wslist = $wb.WorkSheets

         foreach ($ws in $wslist)
         {
            $wsname = $ws.Name

            $wsname   = $wsname -replace "OneView",""    # Remove OneView prefix if necessary
            $wsname   = $wsname -replace "\s+",""        # Remove 1 or more spaces
            $wsname   = $wsname.Trim()
            $Filename = $CSVNames.get_Item($wsname)
            if ($Filename)
            {
                $csvFile = $DirName + $Filename
                write-host -foreground Cyan "Generating CSV file --> $CsvFile .... "
                $ws.SaveAs($csvFile,[Microsoft.Office.Interop.Excel.XlFileFormat]::xlCSV)
            }
         }

         $xl.Quit()
     }
     else
     {
        write-host -foreground Yellow "Excel file $ExcelFile does not exist. Please specify one"
     }
