# OV Check LLDP settings

The script get-LLDP.ps1 collects LLDP settings on all Logical Interconnects.

## Scenario
In OneView environment, an admin does not see remote connections to external swicthes from Interconnect uplink ports.
He needs to check whether enhanced LLDP tagging is enabled/disabled on the Logical Interconnect

## Prerequisites
The script requires:
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
   * Optionally, you can install the module ImportExcel from the PowerShell gallery to take advantage of Excel functions 
     ** Use the command Install-module ImportExcel -scope CurrentUser 
   * A txt file containing list of OneView appliances name or IP


## Output
The script generates a CSV file containing: LLDP settings, advertisd LLDP ipV4 and ipV6 address of the logical interconnect
The CSV file uses '|' as delimiter so if you want to view it correctly in Excel, you should use custom delimiter
Example
import-CSV -delimiter '|' file.csv | Out-GridView

if the ImportExcel module is installed, the script will generate Excel file.


## Syntax

```
   $cred    = get-credential   # Provide credential to connect to OneView
    .\get-LLDP.ps1  -OVlistCSV  <OVappliances.txt> -OVcredential $cred 

```

    
