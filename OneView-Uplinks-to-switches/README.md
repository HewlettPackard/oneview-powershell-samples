# From uplinks to external switches

The script Get-uplinks-to-switch.ps1 collects uplink ports information from interconnect devices and present a view from external switches to Synergy uplink ports and uplinkset.
The ouput in Excel/CSV helps admin and network admins to have a comprehensive view of network connections between Synergy and customer's network switches.


## Prerequisites
The  script requires:
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
   * Optionally, you can install the module ImportExcel from the PowerShell gallery to take advantage of Excel functions 
     ** Use the command: Install-module ImportExcel -scope CurrentUser 
   * A txt file containing list of OneView appliances name or IP


## Output
The script generates a CSV fil 
The CSV file uses '|' as delimiter so if you want to view it correctly in Excel, you should use custom delimiter
Example
import-CSV -delimiter '|' file.csv | Out-GridView

if the ImportExcel module is installed, the script will generate Excel file.


## Syntax

```
   $cred    = get-credential   # Provide credential to connect to OneView
    .\Get-uplinks-to-switch.ps1 -OVlistCSV  <OVappliances.CSV> -OVcredential $cred 

```

   
    
