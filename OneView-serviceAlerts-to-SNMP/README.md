# OV Service Alerts to SNMP

The script serviceAlerts-to-snmp.ps1 collects service alerts from OneView and displays snmp traps associated with each alert
This is useful in the scenario where administrator wants to find OneView service alerts that generate ticket service to HPE Support ( through IRS) and have SNMP OIID trap attached to it. The output allows admins to correlate service tickets with snmp traps received in their mornitoring environment.

## Prerequisites
The  script requires:
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
   * Optionally, you can install the module ImportExcel from the PowerShell gallery to take advantage of Excel functions 
     ** Use the command: Install-module ImportExcel -scope CurrentUser 
   * A txt file containing list of OneView appliances name or IP


## Output
The script generates a CSV file containing: caseID, description, SNMP OID and suggested corrective action 
The CSV file uses '|' as delimiter so if you want to view it correctly in Excel, you should use custom delimiter
Example
import-CSV -delimiter '|' file.csv | Out-GridView

if the ImportExcel module is installed, the script will generate Excel file.


## Syntax

```
   $cred    = get-credential   # Provide credential to connect to OneView
    .\serviceAlerts-To-snmp.ps1 -OVlistCSV  <OVappliances.txt> -OVcredential $cred -Start <start-day-of-alert-collection> -End <end-day-of-alert-collection> -All:$true

```
Default values are:

   * Start : get-date -day 1   --> Beginning of current month
   * End   : get-date          --> today
   * All   : if the parameter is present, all service tickets (closed or open) are examined. If it's not present, only opened service tickest are collected.

   
    
