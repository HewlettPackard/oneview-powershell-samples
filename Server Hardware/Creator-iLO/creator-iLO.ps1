## -------------------------------------------------------------------------------------------------------------
##
##
##      Description: OneView-iLO functions
##
## DISCLAIMER
## The sample scripts are not supported under any HPE standard support program or service.
## The sample scripts are provided AS IS without warranty of any kind. 
## HP further disclaims all implied warranties including, without limitation, any implied 
## warranties of merchantability or of fitness for a particular purpose. 
##
##    
## Scenario
##     	Use SSO to configure iLO from OneView
##		
##
## Input parameters:
##         OVApplianceIP                      = IP address of the OV appliance
##		   OVAdminName                        = Administrator name of the appliance
##         OVAdminPassword                    = Administrator's password
##         iLOUserCSV                         = path to the CSV file containing user accounts definition
##
## History: 
##
##        February-2016   : v1.0
##
## Version : 1.0
##
##
## -------------------------------------------------------------------------------------------------------------

Param ( [string]$OVApplianceIP="10.254.1.21", 
        [string]$OVAdminName="Administrator", 
        [string]$OVAdminPassword="P@ssword1",
        [string]$OneViewModule = "HPOneView.120",  

        [string]$iLOAccountCSV = "c:\oneview\iloAccount.csv"

)



## -------------------------------------------------------------------------------------------------------------
##
##                     Function Create-iLOAccount
##
## -------------------------------------------------------------------------------------------------------------

Function Create-iLOAccount {

<#
  .SYNOPSIS
    Create iLO accounts from OneView
  
  .DESCRIPTION
	Create iLO accounts from OneView
      
  .EXAMPLE
    Create-iLOAccount.ps1  -iLOaccountCSV c:\iLOaccount.CSV 



  .PARAMETER iLOAccountCSV
    Name of the CSV file containing iLO account definition
	

  .Notes
    NAME:  Create-iLOAccount
    LASTEDIT: 02/13/2016
    KEYWORDS: iLO accounts
   
  .Link
     Http://www.hpe.com
 
 #Requires PS -Version 3.0
 #>
Param ([string]$iLOAccountCSV ="")

    if ( -not (Test-path $iLOAccountCSV))
    {
        write-host "No file specified or file $iLOAccountCSV does not exist. Skip creating iLO account"        return    }    # Read the CSV Users file    $tempFile = [IO.Path]::GetTempFileName()    type $iLOAccountCSV | where { ($_ -notlike ",,,,,*") -and ( $_ -notlike "#*") -and ($_ -notlike ",,,#*") } > $tempfile   # Skip blank line    $ListofAccts    = import-csv $tempfile       foreach ($A in $ListofAccts)    {        $userName      = $A.userName        $ServerName    = $A.ServerName        if (($userName -eq "") -or ($ServerName -eq ""))        {            write-host -ForegroundColor Yellow "No username specified or No Server HArdware specified. Skip creating accounts..."                    }        else        {            $Password      = $A.Password            $LoginName     = if ($A.LoginName) { $A.LoginName} else {$userName}            $PrivList      = if ($A.Privileges) { $($A.Privileges).split('|')} else { ""}                    if ($PrivList -eq 'All')             {                $PrivList = @(                    'RemoteConsolePriv',                    'iLOConfigPriv',                    'VirtualMediaPriv',                    'UserConfigPriv',                    'VirtualPowerAndResetPriv')            }            ## ----- Build up data now            $priv = @{}
                foreach ($p in $PrivList)
                {
                    $priv.Add($p,$true)
                }            $hp = @{}
                $hp.Add('LoginName',$LoginName)
                $hp.Add('Privileges',$priv)            $oem = @{}
                $oem.Add('Hp',$hp)
            $Headers = @{}
                $Headers.Add("UserName" , $userName)                            
                $Headers.Add("Password" , $Password)   
                $Headers.Add('Oem',$oem)

            $data  = $Headers |ConvertTo-Json -Depth 10            ## ---- Get Server Hardware            $ThisServer = get-hpovServer -name $ServerName            if ($ThisServer)            {                $ThisRemoteConsole = "$($ThisServer.Uri)/remoteConsoleUrl"                $resp = Send-HPOVRequest $ThisRemoteConsole                $URL,$session          = $resp.remoteConsoleUrl.Split("&")
                $http, $iLOIP          = $URL.split("=")
                $sName,$sessionkey     = $session.split("=")                        $rootURI   = "https://$iLOIP/rest/v1"                $AcctUri   = "/rest/v1/AccountService/Accounts"                $iloSession = new-object PSObject -Property @{"RootUri" = $rootURI ; "X-Auth-Token" = $sessionkey}                                write-host -ForegroundColor Cyan "-----------------------------------------------------"                write-host -ForegroundColor Cyan "Creating account $username on ILO $iLOIP.... "                write-host -ForegroundColor Cyan "-----------------------------------------------------"                Invoke-HPRESTAction -href $AcctUri -data $headers -session $iLOsession            }            else            {                write-host -foreground Yellow "Server Hardware --> $ServerName is not managed by this OneView appliance. Skip creating accounts in iLO"            }                    } #end else username empty                  }

}

## -------------------------------------------------------------------------------------------------------------
##
##                     Main Entry
##
## -------------------------------------------------------------------------------------------------------------

       # -----------------------------------       #    Always reload module          $LoadedModule = get-module -listavailable $OneviewModule       if ($LoadedModule -ne $NULL)       {            $LoadedModule = $LoadedModule.Name.Split('.')[0] + "*"            remove-module $LoadedModule       }       import-module $OneViewModule       # ----------------------------------------       # Import HPREST Cmdlets module       import-module "C:\Program Files\WindowsPowerShell\Modules\HPRESTCmdlets\1.0.0.3\HPRESTCmdlets.psm1"        # ---------------- Connect to OneView appliance        #        write-host -ForegroundColor Cyan "-----------------------------------------------------"        write-host -ForegroundColor Cyan "Connect to the OneView appliance..."        write-host -ForegroundColor Cyan "-----------------------------------------------------"        Connect-HPOVMgmt -appliance $OVApplianceIP -user $OVAdminName -password $OVAdminPassword
        if ( ! [string]::IsNullOrEmpty($iLOAccountCSV) -and (Test-path $iLOAccountCSV) )
        {
            Create-iLOAccount -iLOAccountCSV $iLOAccountCSV         }



        write-host -ForegroundColor Cyan "-----------------------------------------------------"
        write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
        write-host -ForegroundColor Cyan "-----------------------------------------------------"
        
        Disconnect-HPOVMgmt