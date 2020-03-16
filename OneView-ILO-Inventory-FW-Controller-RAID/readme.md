# Inventory of FW-Controller and RAID level PowerShell script


## Scenario
Administrators want to get an inventory of Controller FW and RAID in response to the critical advisory for upgrading firmware: https://support.hpe.com/hpesc/public/docDisplay?docId=emr_na-a00097210en_us


## Notes
   * Works for both OneView and non-OneView environment(using iLO)
   * Works for Gen8/Gen9 and Gen10 servers - BL and DL


## New features
   * Mar 2020: 1st release

## How to get Support
Simple scripts or tools posted on github are provided AS-IS and support is absed on best effort provided by the author. If you encunter problems with the script, please submit an issue 

## Prerequisites
The script requires:
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
   * the latest HPERedfishCmdelts on PowerShell gallery
   * IP address and credentials to connect to a OneView environment
   * iLO CSV file ( see notes)
  

## To install OneView PowerShell library and HPERedfishCmdlets

```
    # You will need HPERedfishCmdlets for both OneView and non-OneView environment 
    install-Module  HPERedfishcmdlets  -scope currentuser
    
    # For OneView 4.20
    install-module HPOneView.420  -scope currentuser

    # For OneView 5.0
    install-module HPOneView.500  -scope currentuser

```

## To run in an OneView environment

```
    # Get inventory ONLY on Gen10 servers
    .\OV-Get-Controller-FW-RAID.ps1 -hostname <OV-name> -username <OV-admin> -password <OV-password>

    # Get inventory on ALL servers
    .\OV-Get-Controller-FW-RAID.ps1 -hostname <OV-name> -username <OV-admin> -password <OV-password> -All:$True

```

## To run in a  non-OneView environment using iLO addresses

Create an ILO.csv file ( see sample)
```
iloName,userName,password
10.10.1.3,admin,password
10.10.1.5,admin,password

```

```
    # Get inventory for All disks ( default)
    .\iLO-Get-Controller-FW-RAID.ps1 -CSVfile ilo.csv

        # Get inventory on ALL servers
    .\iLO-Get-Controller-FW-RAID.ps1 -CSVfile ilo.csv -All:$True

```
    
