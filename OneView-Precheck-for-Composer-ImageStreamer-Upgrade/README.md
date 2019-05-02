# Pre-check for upgrade

The script runs pre-check operations before OneView upgrade to 4.20
It can create support dump and backup file during the pre-check operations


## Prerequisites
The script requires:
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases

The script must be run with administrator privilege


## Syntax

```
   $cred    = get-credential   # Provide admin credential to connect to OneView
    .\precheck-upgrade.ps1  -hostname  <FQDN-OneView> -credential $cred 
   
   # To create support dump and backup file during the precheck operations, use the follwoing command:
   # Specify OneView host name and Login Domain ( default is "local" )
   .\precheck-upgrade.ps1  -hostname  <FQDN-OneView> -credential $cred -AuthLoginDomain <AD-domain> -createBackupSupport

```

    
