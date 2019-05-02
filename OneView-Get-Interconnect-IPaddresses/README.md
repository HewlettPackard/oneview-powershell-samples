# Get Interconnect addresses

The script collects ipV4 and ipV6 addresses of all interconnect modules


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
   # The script will generate an appliance dump 
   $cred    = get-credential   # Provide admin credential to connect to OneView
    .\get-interconnect-address.ps1 -OVcredential $cred -OVListCSV ovlist.txt




```

    
