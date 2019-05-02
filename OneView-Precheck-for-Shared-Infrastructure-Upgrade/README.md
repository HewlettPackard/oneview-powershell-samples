# Pre-check for shared infrastructure upgrade

The script runs pre-check operations before upgrading Firmware on Virtual connect
The script queries all logical interconnects and checks status of:
   * uplink ports
   * stacking links
   * LACP neighbors


## Prerequisites
The script requires:
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
   * Optionally, you can install the module ImportExcel from the PowerShell gallery to take advantage of Excel functions 
     ** Use the command Install-module ImportExcel -scope CurrentUser 


## Note
   To get an Excel sheet with color coding for status, importExcel module must be installed


## Syntax

```
   $cred    = get-credential   # Provide credential to connect to OneView
   # Specify OneView host name and Login Domain ( default is "local" )
    .\Pre-Check-SharedInfrastructure.ps1  -hostname  <FQDN-OneView> -credential $cred -AuthLoginDomain <AD-domain> 

```

