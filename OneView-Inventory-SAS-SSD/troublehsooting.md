# Troublehsooting the PowerShell script



## Overview
The Powershell script connects to the iLO of a given server and creates an iLO session to be used by REDFish calls to collect data about the disks
   * if you use the OneView version, it ccreates a SSO session with the ILO
   * if you use the iLO version, it uses credentials provided in the iLO.CSV file to get IP address and credentials  


## Troubleshooting
If the script cannot create an iLO session, it will record its IP address in a log txt file. Here are the steps you can use to troubleshoot access to this iLO
   * Ping the iLO IP address
   * Login to the ILO using https or ssh
   * if you are using OneView, from the GUI, select the server and connect to the iLO console ( This is how the script is doing : it creates a SSO session)
   * In the last resort reset the iLO 

## How to get Support
Simple scripts or tools posted on github are provided AS-IS and support is absed on best effort provided by the author. If you encunter problems with the script, please submit an issue 

