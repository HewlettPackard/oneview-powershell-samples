# OneView Convert to PowerShell scripts


## Scenario
Administrators want to 'replicate' an existing Synergy environment managed by an OneView instance to a new OneView instance 


## Prerequisites
The script requires:
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
        to install on a Windows environment:
         - install-module HPOneView.420 
   * IP address and credentials to connect to an existing OneView environment ( called 'master')
   * IP address and credentials to connect to a new OneView environment


## Notes
The sequence used to replicate the environment is as follow:
   * Connect to the master environment
   * Generate scripts for networks / network sets
   * Generate scripts for Logical interconnect groups including uplink sets
   * Generate scripts for enclosure groups
   * Generate scripts for logical enclosures ( to be modified with enclosures in the destination environment)
   * Generate scripts for server profile templates
   * Generate scripts for server profiles

   ** Note: Use the help of ConvertTo-HPOVPOwerShellScript to generate scripts for addtional configurations
    
