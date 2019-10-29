# Overview
Creator-iLO.ps1 is a PowerShell script used to configure iLO settings of servers from OneView.
The script reads definition of attributes from CSV files.
List of iLO settings includes:
* iLO Accounts

The script leverages the OneView REST API to connect to the iLO thru a SSO session. Doing that, you don't need to provide specific credentials for each iLO.
The general flow of each operation is as follow:
* Get the iLO settings from CSV
* Get the server hardware name from the CSV. Note that the name must match names defined in OneView ( Server Hardware tab)
* Query Oneview to collect the server URI resource
* Append the uri with /remoteConsoleURL - Send a HPOV request to this new uri.
* From the ouput of previous call, collect IP address of iLO and session key. 
* Use session key and call appropriate iLO Web Services using HPREST CmdLets library


# Pre-requisites
* OneView appliance 1.2 / 2.0
* OneView PowerShell library v1.20
* Windows PowerShell 3.0
* HPRESTCmdlets
* Microsoft Excel


# Instructions
* Download the Creator-iLO.zip file.
* On your Windows machine, create a folder, for example C:\OneView
* Unzip Creator-iLO.zip in the folder
* Copy the file HPRESTCmdlets.psm1 to C:\Program Files\WindowsPowerShell\Modules\HPRESTCmdlets\1.0.0.3\HPRESTCmdlets.psm1
* Open a PowerShell command window with the Administrator privilege.
* if necessary, run the command : Set-ExecutionPolicy Unrestricted
* Go to the folder C:\OneView\CSV
* Open the Excel file and review the different tabs.The Excel file contains all definitions for various attributes. Each attribute and possible values are contained in tabs in Excel


<img src="https://raw.githubusercontent.com/wiki/HewlettPackard/POSH-HPOneView/Examples/Creator_ILO_files/Excel-Account.PNG" />



* Modify values in each tab to match with your environment
* Save the Excel file.
* Generate corresponding CSV files using the script below: 

          C:\OneView\ExportExceltoCSV.ps1 -ExcelFile C:\OneView\iLOSettings.xlsx 




# Script in Action!

**Note 1:** Replace the default values with values defined in your appliance:
* IP address of the OV appliance
* Username and password of the OV administrator

**Note 2:**
* Each operation can be executed independently. If you don't want to create a given resource, you can simply skip the operation. 

### Create iLO accounts

     C:\OneView\Creator-iLO.ps1 -iLOAccountCSV c:\Oneview\csv\iLOAccount.csv -OVApplianceIP 10.254.1.39 -OVAdminName administrator -OVAdminPassword P@ssword1 -OneViewModule HPOneView.120

<img src="https://raw.githubusercontent.com/wiki/HewlettPackard/POSH-HPOneView/Examples/Creator_ILO_files/Account-1.PNG" />

<img src="https://raw.githubusercontent.com/wiki/HewlettPackard/POSH-HPOneView/Examples/Creator_ILO_files/iLOAccount.PNG" />








<img src="https://raw.githubusercontent.com/wiki/HewlettPackard/POSH-HPOneView/Examples/icon_download.png"/>[Download Script Source] 
(https://github.com/HewlettPackard/POSH-HPOneView/wiki/Examples/Creator_iLO.zip)
