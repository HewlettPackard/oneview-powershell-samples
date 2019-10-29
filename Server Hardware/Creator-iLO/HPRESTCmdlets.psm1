<# (C) Copyright 2015 Hewlett-Packard Development Company, L.P. All rights reserved. #>

<# NOTE: See typical usage examples in the HPRESTExamples.ps1 file installed with this module. #>

Add-Type @'
public class AsyncPipeline
{
    public System.Management.Automation.PowerShell Pipeline ;
    public System.IAsyncResult AsyncResult ;
}
'@

function Get-Message
{
    Param
    (
        [Parameter(Mandatory=$true)][String]$MsgID
    )
	$LocalizedStrings=@{
	'MSG_PROGRESS_ACTIVITY'='Receiving Results'
	'MSG_PROGRESS_STATUS'='Percent Complete'
	'MSG_SENDING_TO'='Sending to {0}'
	'MSG_FAIL_HOSTNAME'='DNS name translation not available for {0} - Host name left blank.'
	'MSG_FAIL_IPADDRESS'='Invalid Hostname: IP Address translation not available for hostname {0}.'
	'MSG_PARAMETER_INVALID_TYPE'="Error : `"{0}`" is not supported for parameter `"{1}`"."
	'MSG_INVALID_USE'='Error : Invalid use of cmdlet. Please check your input again'
	'MSG_INVALID_RANGE'='Error : The Range value is invalid'
	'MSG_INVALID_PARAMETER'="`"{0}`" is invalid, it will be ignored."
	'MSG_INVALID_TIMEOUT'='Error : The Timeout value is invalid'
	'MSG_FIND_LONGTIME'='It might take a while to search for all the HP Rest sources if the input is a very large range. Use Verbose for more information.'
	'MSG_USING_THREADS_FIND'='Using {0} threads for search.'
	'MSG_PING'='Pinging {0}'
	'MSG_PING_FAIL'='No system responds at {0}'
	'MSG_FIND_NO_SOURCE'='No HP Rest source at {0}'
	'MSG_INVALID_CREDENTIALS'='Invalid credentials'
    'MSG_SCHEMA_NOT_FOUND'='Schema not found for {0}'
	'MSG_INVALID_HREF'='The Href value is invalid'
	'MSG_FORMATDIR_LOCATION'='Location'
	"MSG_PARAMETER_MISSING"="Error : Invalid use of cmdlet. `"{0}`" parameter is missing"
	}
    $Message = ''
    try
    {
        $Message = $RM.GetString($MsgID)
        if($Message -eq $null)
        {
            $Message = $LocalizedStrings[$MsgID]
        }
    }
    catch
    {
        #throw $_
		$Message = $LocalizedStrings[$MsgID]
    }

    if($Message -eq $null)
    {
		#or unknown
        $Message = 'Fail to get the message'
    }
    return $Message
}

function Create-ThreadPool
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$true)][int]$PoolSize,
        [Parameter(Position=1,Mandatory=$False)][Switch]$MTA
    )
    
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $PoolSize)	
    
    If(!$MTA) { $pool.ApartmentState = 'STA' }
    
    $pool.Open()
    
    return $pool
}

function Start-ThreadScriptBlock
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$True)]$ThreadPool,
        [Parameter(Position=1,Mandatory=$True)][ScriptBlock]$ScriptBlock,
        [Parameter(Position=2,Mandatory=$False)][Object[]]$Parameters
    )
    
    $Pipeline = [System.Management.Automation.PowerShell]::Create() 

	$Pipeline.RunspacePool = $ThreadPool
	    
    $Pipeline.AddScript($ScriptBlock) | Out-Null
    
    Foreach($Arg in $Parameters)
    {
        $Pipeline.AddArgument($Arg) | Out-Null
    }
    
	$AsyncResult = $Pipeline.BeginInvoke() 
	
	$Output = New-Object AsyncPipeline 
	
	$Output.Pipeline = $Pipeline
	$Output.AsyncResult = $AsyncResult
	
	$Output
}
function Get-ThreadPipelines
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$True)][AsyncPipeline[]]$Pipelines,
		[Parameter(Position=1,Mandatory=$false)][Switch]$ShowProgress
    )
	
	# incrementing for Write-Progress
    $i = 1 
	
    foreach($Pipeline in $Pipelines)
    {
		
		try
		{
        	$Pipeline.Pipeline.EndInvoke($Pipeline.AsyncResult)
			
			If($Pipeline.Pipeline.Streams.Error)
			{
				Throw $Pipeline.Pipeline.Streams.Error
			}
        } catch {
			$_
		}
        $Pipeline.Pipeline.Dispose()
		
		If($ShowProgress)
		{
            Write-Progress -Activity $(Get-Message('MSG_PROGRESS_ACTIVITY')) -PercentComplete $(($i/$Pipelines.Length) * 100) `
                -Status $(Get-Message('MSG_PROGRESS_STATUS'))
		}
		$i++
    }
}


function Get-IPArrayFromIPSection {
      param (
      [parameter(Mandatory=$true)][String] $stringIPSection,
      [parameter(Mandatory=$false)] [ValidateSet('IPv4','IPv6')] [String]$IPType = 'IPv4'
   )

    $returnarray=@()   
    try
    {
        $errMsg = "Failed to get $IPType array from IP section $stringIPSection"
        $by_commas = $stringIPSection.split(',')

        if($IPType -eq 'IPV4')
        {
        foreach($by_comma in $by_commas)
        {
            $by_comma_dashs = $by_comma.split('-')
            $by_comma_dash_ele=[int]($by_comma_dashs[0])
            $by_comma_dash_ele_end = [int]($by_comma_dashs[$by_comma_dashs.Length-1])
            if($by_comma_dash_ele -gt $by_comma_dash_ele_end)
            {
                $by_comma_dash_ele = $by_comma_dash_ele_end
                $by_comma_dash_ele_end = [int]($by_comma_dashs[0])                   
            }

            for(; $by_comma_dash_ele -le $by_comma_dash_ele_end;$by_comma_dash_ele++)
            {
                $returnarray+=[String]($by_comma_dash_ele)
                
            }
         }
        }

        if($IPType -eq 'IPv6')
        {
        foreach($by_comma in $by_commas)
        {
            $by_comma_dashs = $by_comma.split('-')
            $by_comma_dash_ele=[Convert]::ToInt32($by_comma_dashs[0], 16)
            $by_comma_dash_ele_end = ([Convert]::ToInt32($by_comma_dashs[$by_comma_dashs.Length-1], 16))
            if($by_comma_dash_ele -gt $by_comma_dash_ele_end)
            {
                $by_comma_dash_ele = $by_comma_dash_ele_end
                $by_comma_dash_ele_end = [Convert]::ToInt32($by_comma_dashs[0], 16)                   
            }

            for(; $by_comma_dash_ele -le $by_comma_dash_ele_end;$by_comma_dash_ele++)
            {
                $returnarray+=[Convert]::ToString($by_comma_dash_ele,16);
                
            }
         }
    }
   }
   catch
   {
         Write-Host "Error - $errmsg" -ForegroundColor red
   }
   return ,$returnarray
   }

#A common function for both IPv4/IPv6 , which will firstly make sure all the sections of IPv4/IPv6 is complete before calling this function)   
#input is a IPv4 address(separeated by ".") or IPv6 address(separeated by ":") and in each section, there might be "," and "-", like "1,2,3-4"
#return the array of all the possible IP adreesses parsed from the input string
function Get-IPArrayFromString {
      param (
      [parameter(Mandatory=$true)][String] $stringIP,
      [parameter(Mandatory=$false)] [ValidateSet('IPv4','IPv6')] [String]$IPType = 'IPv4',
      [parameter(Mandatory=$false)] [String]$PreFix = '',
      [parameter(Mandatory=$false)] [String]$PostFix = ''
   )

    #$returnarray=@()
    try
    {
    $errMsg = "Invalid format of IP string $stringIP to get $IPType array"
    $IPSectionArray = New-Object System.Collections.ArrayList
    $returnarray = New-Object 'System.Collections.ObjectModel.Collection`1[System.String]'

    $IPdelimiter='.'
    if($IPType -eq 'IPv6')
    {
        $IPdelimiter=':'
    }
    
    $sections_bycolondot = $stringIP.Split($IPdelimiter)
    for($x=0; ($x -lt $sections_bycolondot.Length -and ($sections_bycolondot[$x] -ne $null -and $sections_bycolondot[$x] -ne '')) ; $x++)
    {
        $section=@()		
        $section= Get-IPArrayFromIPSection -stringIPSection $sections_bycolondot[$x] -IPType $IPType
        $x=$IPSectionArray.Add($section)        
    }
    
    if($IPSectionArray.Count -eq 1)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$PostFix)
        }
    }
    if($IPSectionArray.Count -eq 2)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$PostFix)
            }
        }
    }
    if($IPSectionArray.Count -eq 3)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$PostFix)
                }
            }
        }
    }
    if($IPSectionArray.Count -eq 4)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {  
                        $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$PostFix)
                    }
                }
            }
        }
    }

    if($IPSectionArray.Count -eq 5)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$PostFix)
                        }
                    }
                }
            }
        }
    }

    if($IPSectionArray.Count -eq 6)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$PostFix)
                            }
                        }
                    }
                }
            }
        }
    }
    if($IPSectionArray.Count -eq 7)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                for($d=0; $d -lt $IPSectionArray[6].Count; $c++)
                                {
                                    $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$IPdelimiter+$IPSectionArray[6][$d]+$PostFix)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if($IPSectionArray.Count -eq 8)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                for($d=0; $d -lt $IPSectionArray[6].Count; $d++)
                                {
                                    for($e=0; $e -lt $IPSectionArray[7].Count; $e++)
                                    {
                                        $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$IPdelimiter+$IPSectionArray[6][$d]+$IPdelimiter+$IPSectionArray[7][$e]+$PostFix)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if($IPSectionArray.Count -eq 9)
    {
        for($x=0; $x -lt $IPSectionArray[0].Count; $x++)
        {
            for($y=0; $y -lt $IPSectionArray[1].Count; $y++)
            {
                for($z=0; $z -lt $IPSectionArray[2].Count; $z++)
                {
                    for($a=0; $a -lt $IPSectionArray[3].Count; $a++)
                    {
                        for($b=0; $b -lt $IPSectionArray[4].Count; $b++)
                        {
                            for($c=0; $c -lt $IPSectionArray[5].Count; $c++)
                            {
                                for($d=0; $d -lt $IPSectionArray[6].Count; $c++)
                                {
                                    for($e=0; $e -lt $IPSectionArray[7].Count; $e++)
                                    {
                                        for($f=0; $f -lt $IPSectionArray[8].Count; $f++)
                                        {
                                            $returnarray.Add($PreFix+$IPSectionArray[0][$x]+$IPdelimiter+$IPSectionArray[1][$y]+$IPdelimiter+$IPSectionArray[2][$z]+$IPdelimiter+$IPSectionArray[3][$a]+$IPdelimiter+$IPSectionArray[4][$b]+$IPdelimiter+$IPSectionArray[5][$c]+$IPdelimiter+$IPSectionArray[6][$d]+$IPdelimiter+$IPSectionArray[7][$e]+$IPdelimiter+$IPSectionArray[8][$f]+$PostFix)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }
    catch
    {
         Write-Host "Error - $errmsg" -ForegroundColor red
    }

   return ,$returnarray
   }

#for ipv6 support in cmdlets other than Find-HPRest
function Get-IPv6FromString {
      param (
      [parameter(Mandatory=$true)][String] $stringIP,
	  [parameter(Mandatory=$false)] [switch] $AddSquare
	  
   )
            $percentpart=''
            $ipv4array=@()
            #$ipv6array=@()
            #$returnstring=@()
            $returnstring = New-Object 'System.Collections.ObjectModel.Collection`1[System.String]'
            $ipv6array = New-Object 'System.Collections.ObjectModel.Collection`1[System.String]'
			$preFix=''
			$postFix=''
			if($AddSquare)
			{
				$preFix='['
				$postFix=']'
			}
            try
            {
            $errMsg = "Invalid format of IP string $stringIP to get IPv6 address"
            #it could have ::, :,., % inside it, have % in it            
            if($stringIP.LastIndexOf('%') -ne -1)  
            {
                $sections = $stringIP.Split('%')
                $percentpart='%'+$sections[1]
                $stringIP=$sections[0]                
            }

            #it could have ::, :,.inside it, have ipv4 in it
            if($stringIP.IndexOf('.') -ne -1) 
            {
                [int]$nseperate = $stringIP.LastIndexOf(':')
				#to get the ipv4 part
                $mappedIpv4 = $stringIP.SubString($nseperate + 1) 
				$ipv4array=Get-IPArrayFromString -stringIP $mappedIpv4 -IPType 'IPV4' 

                #to get the first 6 sections, including :: or :
				$stringIP = $stringIP.Substring(0, $nseperate + 1) 
            }

				#it could have ::,: inside it             
                $stringIP = $stringIP -replace '::', '|' 
                $sectionsby_2colon=@()
				#suppose to get a 2 element array
                $sectionsby_2colon = $stringIP.Split('|') 
				#no :: in it
                if($sectionsby_2colon.Length -eq 1) 
                {
                    $ipv6array=Get-IPArrayFromString -stringIP $sectionsby_2colon[0] -IPType 'IPv6' 
                }
                elseif($sectionsby_2colon.Length -gt 1)
                {
					#starting with ::
                    if(($sectionsby_2colon[0] -eq '')) 
                    {
                        if(($sectionsby_2colon[1] -eq ''))
                        {
                            $ipv6array=@('::')
                        }
                        else
                        {
                            $ipv6array=Get-IPArrayFromString -stringIP $sectionsby_2colon[1] -IPType 'IPv6' -PreFix '::'
                        }
                    }
					#not starting with ::, may in the middle or in the ending
                    else 
                    {
                        if(($sectionsby_2colon[1] -eq ''))
                        {
                            $ipv6array=Get-IPArrayFromString -stringIP $sectionsby_2colon[0] -IPType 'IPv6' -PostFix '::'
                        }
                        else
                        {
                            $ipv6array1=Get-IPArrayFromString -stringIP $sectionsby_2colon[0] -IPType 'IPv6'  -PostFix '::'                            
                            $ipv6array2=Get-IPArrayFromString -stringIP $sectionsby_2colon[1] -IPType 'IPv6' 
                            foreach($x1 in $ipv6array1)
                            {
                                foreach($x2 in $ipv6array2)
                                {
                                    $ipv6array.Add($x1 + $x2)
                                }
                            }
                        }                        
                    }
                }        

        foreach($ip1 in $ipv6array)
        {
            if($ipv4array.Count -ge 1)
            {
                foreach($ip2 in $ipv4array)
                {
                    if($ip1.SubString($ip1.Length-1) -eq ':')
                    {
                        $returnstring.Add($preFix+$ip1+$ip2+$percentpart+$postFix)
                    }
                    else
                    {
                        $returnstring.Add($preFix+$ip1+':'+$ip2+$percentpart+$postFix)
                    }
                }
            }
            else
            {
                $returnstring.Add($preFix+$ip1+$percentpart+$postFix)
            }            
        }
        }
        catch
        {
            Write-Host "Error - $errmsg" -ForegroundColor red
        }
    return $returnstring    
}

#called from Find-HPRest, complete all the sections for one IPv4 address, 
#$arrayforip returns an array with 4 items, which map to the 4 sections of IPv4 address. 
#for example, if input $strIP="x", the $arrayforip will be @("x","0-255","0-255","0-255")
function Complete-IPv4{
    param (
        [parameter(Mandatory=$true)] [String] $strIP
        #[parameter(Mandatory=$true)] [ref] $arrayforip
    )
    $arrayfor = @()
    $arrayfor += '0-255'
    $arrayfor += '0-255'
    $arrayfor += '0-255'
    $arrayfor += '0-255'

             #with the new format, 1..., or .1, at most 5 items in $sections, but might have empty values  
             $sections = $strIP.Split('.')
			 
			 #no "." in it
             if($sections.length -eq 1)
             {              
                $arrayfor[0]=$sections[0]					
			 }
			#might have empty item when input is "x." or ".x"
			elseif($sections.length -eq 2)
			{
                if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
                    if($sections[1] -ne '')
                    {
                        $arrayfor[1]=$sections[1]   
                    }
                }
                else
                {
                    if($sections[1] -ne '')
                    {
                        $arrayfor[3]=$sections[1]
                    }
                }				
			}
            elseif($sections.length -eq 3) 
			{
				#"1..", "1.1.","1.1.1" "1..1"
                if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
                    if($sections[1] -ne '')
                    {
                        $arrayfor[1]=$sections[1]
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]
                        }
                    }
                    else
                    {
                        if($sections[2] -ne '')
                        {
                            $arrayfor[3]=$sections[2]
                        }
                    }

                }                                
                else
                { 
					#.1.1
                    if($sections[2] -ne '') 
                    {
                        $arrayfor[3]=$sections[2]
                        if($sections[1] -ne '')
                        {
                            $arrayfor[2]=$sections[1]
                        }                                      
                    }
                    else
                    {
						#the 1 and 3 items are empty ".1."
                        if($sections[1] -ne '')
                        {
                            $arrayfor[1]=$sections[1]
                        }
                    }
                }							
			}
			#1.1.1., 1..., ...1, 1...1, .x.x.x, x..x.x, x.x..x,..x. 
            elseif($sections.length -eq 4)
			{
				#1st is not empty
                if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
					#2nd is not empty
                    if($sections[1] -ne '')
                    {
                        $arrayfor[1]=$sections[1]
						#3rd is not empty
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]
							#4th is not empty
                            if($sections[3] -ne '')
                            {
                                $arrayfor[3]=$sections[3]
                            }
                        }
						#3rd is empty 1.1..1
                        else 
                        {
							#4th is not empty
                            if($sections[3] -ne '')
                            {
                                $arrayfor[3]=$sections[3]
                            }                            
                        }

                    }
					#2nd is empty, 1..1., 1...
                    else 
                    {
						#4th is not empty
                        if($sections[3] -ne '')
                        {
                            $arrayfor[3]=$sections[3]
							#3rd is not empty
                            if($sections[2] -ne '')
                            {
                                $arrayfor[2]=$sections[2]
                            }  
                        }  
						#4th is empty
                        else 
                        {
							#3rd is not empty
                            if($sections[2] -ne '')
                            {
                                $arrayfor[2]=$sections[2]
                            } 
                        }                        
                    }
                }
				#1st is empty
                else 
                {
					#4th is not empty
                    if($sections[3] -ne '')
                    {
                        $arrayfor[3]=$sections[3]
						#3rd is not empty
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]
							#2rd is not empty
                            if($sections[1] -ne '')
                            {
                                $arrayfor[1]=$sections[1]
                            }                            
                        }
                        else
                        {
							#2rd is not empty
                            if($sections[1] -ne '')
                            {
                                $arrayfor[1]=$sections[1]
                            }  
                        }
                    }
					#4th is empty .1.1., ..1., .1..
                    else 
                    {
						#3rd is not empty
                        if($sections[2] -ne '')
                        {
                            $arrayfor[2]=$sections[2]                                                      
                        }
						
						#2nd is not empty
                        if($sections[1] -ne '')
                        {
                            $arrayfor[1]=$sections[1]                                                      
                        }
                    }                    
                }			
			}
			#x.x.x.., ..x.x.x, x.x.x.x
            elseif($sections.length -eq 5) 
			{
				#1st is not empty
				if($sections[0] -ne '')
                {
                    $arrayfor[0]=$sections[0]
                    if($sections[1] -ne '') 
                    {
                        $arrayfor[1]=$sections[1]
                    }
                    if($sections[2] -ne '') 
                    {
                        $arrayfor[2]=$sections[2]
                    }
                    if($sections[3] -ne '') 
                    {
                        $arrayfor[3]=$sections[3]
                    }
                                                    
                }
				#1st is empty
                else 
                {                    
                    if($sections[4] -ne '')
                    {
                        $arrayfor[3]=$sections[4]
                    }
                    if($sections[3] -ne '') 
                    {
                        $arrayfor[2]=$sections[3]
                    }
                    if($sections[2] -ne'')
                    {
                        $arrayfor[1]=$sections[2]
                    }
                    if($sections[1] -ne '') 
                    {
                        $arrayfor[0]=$sections[1]
                    }
                }		
			}

            #$arrayforip.Value = $arrayfor;
            return $arrayfor[0]+'.'+$arrayfor[1]+'.'+$arrayfor[2]+'.'+$arrayfor[3]
}

#called from Find-HPRest, a helper function to check whether input IPv4 is valid or not
#returns the total number of "." in an IPv4 address
#for example: if input $strIP is "1...1", the return value is 3
function Get-IPv4-Dot-Num{
    param (
        [parameter(Mandatory=$true)] [String] $strIP
    )
    [int]$dotnum = 0
    for($i=0;$i -lt $strIP.Length; $i++)
    {
        if($strIP[$i] -eq '.')
        {
            $dotnum++
        }
    }
    
    return $dotnum
}

#called from Find-HPRest, complete the all sections for one IPv6 address
#$arrayforip returns an array with 8 or more items, which map to the sections of IPv6 address. 
#for example, if input $strIP="x:x:x", the $arrayforip will be @("x","x","x","0-FFFF","0-FFFF","0-FFFF","0-FFFF","0-FFFF")
function Complete-IPv6{
    param (
        [parameter(Mandatory=$true)] [String] $strIP,
        #[parameter(Mandatory=$true)] [ref] $arrayforip,
        [parameter(Mandatory=$false)] [Int] $MaxSecNum=8
    )
            $arrayfor = @()
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
            $arrayfor+=@('0-FFFF')
			
			#used for ipv4-mapped,also used for ipv6 if not in ipv4 mapped format
            $arrayfor+=@('0-FFFF') 
			
			#used for ipv4-mapped,also used for ipv6 if not in ipv4 mapped format
            $arrayfor+=@('0-FFFF') 
			
			#used for ipv4-mapped
            $arrayfor+=@('') 
			
			#used for ipv4-mapped
            $arrayfor+=@('')  
			
			#used for %
            $arrayfor+=@('') 
			
            #$strIP = $strIP -replace "::", "|" 
            $returnstring=''
			
			#have % in it 
            if($strIP.LastIndexOf('%') -ne -1)  
            {
                $sections = $strIP.Split('%')
                $arrayfor[10]='%'+$sections[1]
                $strIP=$sections[0]                
            }
            #it could have ::, :, %, . inside it, have ipv4 in it
            if($strIP.IndexOf('.') -ne -1) 
            {
            
                [int]$nseperate = $strIP.LastIndexOf(':')	
				#to get the ipv4 part				
                $mappedIpv4 = $strIP.SubString($nseperate + 1) 
				$secarray=@()
                $ipv4part = Complete-IPv4 -strIP $mappedIpv4                				
				
				#to get the first 6 sections
                $strIP = $strIP.Substring(0, $nseperate + 1)  
                $ipv6part = Complete-IPv6 -strIP $strIP -MaxSecNum 6 
                $returnstring += $ipv6part+':'+$ipv4part
            }
			#no ipv4 part in it, to get the 8 sections
            else 
            {
                $strIP = $strIP -replace '::', '|' 
                $parsedipv6sections=@()
				#suppose to get a 2 element array
                $bigsections = $strIP.Split('|') 
				#no :: in it
                if($bigsections.Length -eq 1) 
                {
                    $parsedipv6sections = $bigsections[0].Split(':')
                    for($x=0; ($x -lt $parsedipv6sections.Length) -and ($x -lt $MaxSecNum); $x++)
                    {
                        $arrayfor[$x] = $parsedipv6sections[$x]
                    }
                }
                elseif($bigsections.Length -gt 1)
                {
					#starting with ::
                    if(($bigsections[0] -eq '')) 
                    {
                        $parsedipv6sections = $bigsections[1].Split(':')
                        $Y=$MaxSecNum-1
                        for($x=$parsedipv6sections.Length; ($parsedipv6sections[$x-1] -ne '') -and ($x -gt 0) -and ($y -gt -1); $x--, $y--)
                        {
                            $arrayfor[$y] = $parsedipv6sections[$x-1]
                        }
                        for(; $y -gt -1; $y--)
                        {
                            $arrayfor[$y]='0'
                        }
                        
                    }
					#not starting with ::, may in the middle or in the ending
                    else 
                    {
                        $parsedipv6sections = $bigsections[0].Split(':')
                        $x=0
                        for(; ($x -lt $parsedipv6sections.Length) -and ($x -lt $MaxSecNum); $x++)
                        {
                            $arrayfor[$x] = $parsedipv6sections[$x]
                        }
                        
                        $y=$MaxSecNum-1
                        if($bigsections[1] -ne '')
                        {
                            $parsedipv6sections2 = $bigsections[1].Split(':')                            
                            for($z=$parsedipv6sections2.Length;  ($parsedipv6sections2[$z-1] -ne '')-and ($z -gt 0) -and ($y -gt ($x-1)); $y--,$z--)
                            {
                                $arrayfor[$y] = $parsedipv6sections2[$z-1]
                            }
                        }
                        for(;$x -lt ($y+1); $x++)
                        {
                              $arrayfor[$x]='0' 
                        }
                    }
                }
            if($MaxSecNum -eq 6)
            {
                $returnstring = $returnstring = $arrayfor[0]+':'+$arrayfor[1]+':'+$arrayfor[2]+':'+$arrayfor[3]+':'+$arrayfor[4]+':'+$arrayfor[5]
            }
            if($MaxSecNum -eq 8)
            {
                $appendingstring=''
                if($arrayfor[8] -ne '')
                {
                    $appendingstring=':'+$arrayfor[8]
                }
                if($arrayfor[9] -ne '')
                {
                    if($appendingstring -ne '')
                    {
                        $appendingstring = $appendingstring + ':'+$arrayfor[9]
                    }
                    else
                    {
                        $appendingstring=':'+$arrayfor[9]
                    }
                }
                if($arrayfor[10] -ne '')
                {
                    if($appendingstring -ne '')
                    {
                        $appendingstring = $appendingstring + $arrayfor[10]
                    }
                    else
                    {
                        $appendingstring=$arrayfor[10]
                    }
                }
                
                $returnstring = $arrayfor[0]+':'+$arrayfor[1]+':'+$arrayfor[2]+':'+$arrayfor[3]+':'+$arrayfor[4]+':'+$arrayfor[5]+':'+$arrayfor[6]+':'+$arrayfor[7]+$appendingstring
            }
            }
    #$arrayforip.Value= $arrayfor
    return $returnstring
}

function New-TrustAllWebClient {
     <#
       Source for New-TrustAllWebClient is found at http://poshcode.org/624
       Use is governed by the Creative Commons "No Rights Reserved" license 
       and is considered public domain see http://creativecommons.org/publicdomain/zero/1.0/legalcode 
       published by Stephen Campbell of Marchview Consultants Ltd. 
     #>

     <# Create a compilation environment #>    
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add('System.DLL') > $null
    $TASource=@'
namespace Local.ToolkitExtensions.Net.CertificatePolicy {
    public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
            System.Security.Cryptography.X509Certificates.X509Certificate cert, 
            System.Net.WebRequest req, int problem) {
            return true;
        }
    }
}
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    <# We now create an instance of the TrustAll and attach it to the ServicePointManager #>
    $TrustAll=$TAAssembly.CreateInstance('Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll')
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

    <# The ESX Upload requires the Preauthenticate value to be true which is not the default
       for the System.Net.WebClient class which has very simple-to-use downloadFile and uploadfile
       methods.  We create an override class which simply sets that Preauthenticate value.
       After creating an instance of the Local.ToolkitExtensions.Net.WebClient class, we use it just
       like the standard WebClient class.
    #>
    $WCSource=@'
namespace Local.ToolkitExtensions.Net { 
        class WebClient : System.Net.WebClient {
        protected override System.Net.WebRequest GetWebRequest(System.Uri uri) {
            System.Net.WebRequest webRequest = base.GetWebRequest(uri);
            webRequest.PreAuthenticate = true;
            webRequest.Timeout = 10000;
            return webRequest;
        }
    }
}
'@
    $WCResults=$Provider.CompileAssemblyFromSource($Params,$WCSource)
    $WCAssembly=$WCResults.CompiledAssembly

    <# Now return the custom WebClient. It behaves almost like a normal WebClient. #>
    $WebClient=$WCAssembly.CreateInstance('Local.ToolkitExtensions.Net.WebClient')
    return $WebClient
}

function Get-HPRESTDataProp2
{
    param
    (
        [PSObject]
        $Data,

        [PSObject]
        $Schema,

        [PSObject]
        $Session,

        [System.Collections.Hashtable]
        $DictionaryOfSchemas
    )
    $DataProperties = New-Object PSObject

    $PROP = 'Value'
    $PROP1 = 'Schema_Description'
    $SCHEMAPROP1 = 'Description'  #'description' prop name in schema
    $PROP2 = 'Schema_AllowedValue'
    $SCHEMAPROP2 = 'enum'         #'enum' prop name in schema
    $PROP3 = 'Schema_Type'
    $SCHEMAPROP3 = 'type'         #'type' prop name in schema
    $PROP4 = 'Schema_ReadOnly'
    $SCHEMAPROP4 = 'readonly'     #'readonly' prop name in schema
    $dataInSchema = $false

    foreach($dataProp in $data.PSObject.Properties)
    {
        foreach($schProp in $Schema.Properties.PSObject.Properties)
        {
            if($schProp.Name -eq $dataProp.Name)
            {
                $dataInSchema = $true
                if($dataProp.TypeNameOfValue -eq 'System.String' -or $dataProp.TypeNameOfValue -eq 'System.Int32')
                {
                    
                    $outputObj = New-Object PSObject
                    $schToUse = $null
                    if($schProp.value.PSObject.properties.Name.Contains("`$ref"))
                    {
                        $subpath = ''
                        if($schProp.value.'$ref'.contains('.json#/'))
                        {
                            $startInd = $schProp.value.'$ref'.IndexOf('.json#/')
                            $subpath = $schProp.value.'$ref'.Substring(0,$startInd+6)
                            $subpath = $subpath.replace('#','')
                        }
                        else
                        {
                            $subpath = $schProp.value.'$ref'.replace('#','')
                        }
                        
                        $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session
                        $index = $schemaJSONLink.LastIndexOf('/')
                        $prefix = $schemaJSONLink.SubString(0,$index+1)
                        $newLink = $prefix + $subpath

                        $schToUse = Get-HPRESTDataRaw -Href $newLink -Session $session
                    }
                    else
                    {
                        $schToUse = $schProp.Value
                    }

                    if(-not($schToUse.$SCHEMAPROP1 -eq '' -or $schToUse.$SCHEMAPROP1 -eq $null))
                    {
                        $outputObj | Add-Member NoteProperty $PROP1 $schToUse.$SCHEMAPROP1
                    }
                    if($schToUse.PSObject.Properties.Name.Contains('enum') -eq $true)
                    {
                        $outputObj | Add-Member NoteProperty $PROP2 $schToUse.enum
                    }
                    if($schToUse.PSObject.Properties.Name.Contains('enumDescriptions') -eq $true)
                    {    
                        $outputObj | Add-Member NoteProperty 'schema_enumDescriptions' $schToUse.enumDescriptions
                    }
                    <#if($schToUse.PSObject.Properties.Name.Contains('enum') -eq $true)
                    {
                        $outputObj | Add-Member NoteProperty 'schema_valueType' $schToUse.type
                    }#>
                    if(-not($schToUse.$SCHEMAPROP3 -eq '' -or $schToUse.$SCHEMAPROP3 -eq $null))
                    {
                        $outputObj | Add-Member NoteProperty $PROP3 $schToUse.$SCHEMAPROP3
                    }
                    if($schToUse.$SCHEMAPROP4 -eq $true -or $schToUse.$SCHEMAPROP4 -eq $false) # readonly is true or false 
                    {
                        $outputObj | Add-Member NoteProperty $PROP4 $schToUse.$SCHEMAPROP4
                    }
                    if(-not ($DictionaryOfSchemas.ContainsKey($dataProp.Name)))
                    {
                        $DictionaryOfSchemas.Add($dataProp.Name, $outputObj)
                    }
                    $DataProperties | Add-Member NoteProperty $dataProp.Name $dataProp.value
                }
                elseif($dataProp.TypeNameOfValue -eq 'System.Object[]')
                {
                    $dataList = @()
                    for($i=0;$i-lt$dataProp.value.Length;$i++)
                    {
                        $dataPropElement = ($dataProp.Value)[$i]
                        if($dataPropElement.GetType().ToString() -eq 'System.String' -or $dataPropElement.GetType().ToString() -eq 'System.Int32')
                        {
                            $dataList += $dataPropElement                            if(-not ($DictionaryOfSchemas.ContainsKey($dataProp.Name)))
                            {

                                if($schprop.value.items.PSObject.Properties.name.Contains('anyOf'))
                                {
                                    $x = $schProp.Value.items.anyOf
                                }
                                else
                                {
                                    $x = $schProp.Value.items
                                }
                                $outputObj = New-Object PSObject
                                if(-not($schema.Properties.($schprop.Name).$SCHEMAPROP1 -eq '' -or $schema.Properties.($schprop.Name).$SCHEMAPROP1 -eq $null))
                                {
                                    $outputObj | Add-Member NoteProperty $PROP1 $schema.Properties.($schprop.Name).$SCHEMAPROP1
                                }
                                if($x.PSObject.Properties.Name.Contains('enum') -eq $true)
                                {
                                    $outputObj | Add-Member NoteProperty $PROP2 $x.enum
                                }
                                if($x.PSObject.Properties.Name.Contains('enumDescriptions') -eq $true)
                                {    
                                    $outputObj | Add-Member NoteProperty 'schema_enumDescriptions' $x.enumDescriptions
                                }
                                <#if($schToUse.PSObject.Properties.Name.Contains('enum') -eq $true)
                                {
                                    $outputObj | Add-Member NoteProperty 'schema_valueType' $schToUse.type
                                }#>
                                if(-not($x.$SCHEMAPROP3 -eq '' -or $x.$SCHEMAPROP3 -eq $null))
                                {
                                    $outputObj | Add-Member NoteProperty $PROP3 $x.$SCHEMAPROP3
                                }
                                if($x.$SCHEMAPROP4 -eq $true -or $x.$SCHEMAPROP4 -eq $false) # readonly is true or false 
                                {
                                    $outputObj | Add-Member NoteProperty $PROP4 $x.$SCHEMAPROP4
                                }                            
                                $DictionaryOfSchemas.Add($dataProp.Name, $outputObj)
                            }
                        }
                        elseif($dataPropElement.GetType().ToString() -eq 'System.Management.Automation.PSCustomObject')
                        {
                            $psObj = New-Object PSObject
                            if($schprop.Value.PSObject.Properties.name.Contains("items"))
                            {
                                if($schprop.value.items.PSObject.Properties.name.Contains('anyOf'))
                                {
                                    $x = $schProp.Value.items.anyOf
                                }
                                else
                                {
                                    $x = $schProp.Value.items
                                }
                            }
                            else
                            {
                                $x = $schProp.value
                            }
                            if($x.PSObject.properties.Name.Contains("`$ref"))
                            {
                                $subpath = ''
                                if($x.'$ref'.contains('.json#/'))
                                {
                                    $startInd = $x.'$ref'.IndexOf('.json#/')
                                    $subpath = $x.'$ref'.Substring(0,$startInd+6)
                                    $subpath = $subpath.replace('#','')
                                }
                                else
                                {
                                    $subpath = $x.'$ref'.replace('#','')
                                }
                        
                                $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session
                                $index = $schemaJSONLink.LastIndexOf('/')
                                $prefix = $schemaJSONLink.SubString(0,$index+1)
                                $newLink = $prefix + $subpath

                                $schToUse = Get-HPRESTDataRaw -Href $newLink -Session $session
                            }
                            else
                            {
                                $schToUse = $x
                            }
                            $opObj, $DictionaryOfSchemas = Get-HPRESTDataProp2 -Data $dataPropElement -Schema $schToUse -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas
                            $dataList += $opObj
                        }
                    }
                    $DataProperties | Add-Member NoteProperty $dataProp.Name $dataList #$outputObj
                }
                elseif($dataProp.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject')
                {
                    $psObj = New-Object PSObject
                    if($schProp.value.PSObject.properties.Name.Contains("`$ref"))
                    {
                        
                        $laterPath = ''
                        $subpath = ''
                        if($schProp.value.'$ref'.contains('.json#/'))
                        {
                            $startInd = $schProp.value.'$ref'.IndexOf('.json#/')
                            $laterPath = $schProp.value.'$ref'.Substring($startInd+7)
                            $subpath = $schProp.value.'$ref'.Substring(0,$startInd+6)
                            $subpath = $subpath.replace('#','')
                        }
                        else
                        {
                            $subpath = $schProp.value.'$ref'.replace('#','')
                        }
                        
                        $schemaJSONLink = Get-HPRESTSchemaExtref -Type $subpath.replace('.json','') -Session $Session
                        $index = $schemaJSONLink.LastIndexOf('/')
                        $prefix = $schemaJSONLink.SubString(0,$index+1)
                        $newLink = $prefix + $subpath

                        $refSchema = Get-HPRESTDataRaw -Href $newLink -Session $session

                        if($laterPath -eq '')
                        {
                            $sch = $refSchema
                        }
                        else
                        {
                            $tmp = $laterPath.Replace('/','.')
                            $sch = $refSchema
                            foreach($x in $tmp.split('.'))
                            {
                                $sch = $sch.$x
                            }
                        }
                        $opObj, $DictionaryOfSchemas = Get-HPRESTDataProp2 -Data $dataProp.Value -Schema $sch -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas
                        $DataProperties | Add-Member NoteProperty $dataProp.Name $opObj
                        
                    }
                    else
                    {
                        $opObj, $DictionaryOfSchemas  = Get-HPRESTDataProp2 -Data $dataProp.Value -Schema $schProp.Value -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas
                        $DataProperties | Add-Member NoteProperty $dataProp.Name $opObj #$psObj
                    }
                }
                break;
            }
        }
        
        if($dataInSchema -eq $false)
        {
            $DataProperties | Add-Member NoteProperty $dataProp.Name $dataProp.Value
        }
    }
    #Write-Host $DataProperties
    return $DataProperties, $DictionaryOfSchemas
}

function Get-HPRESTTypePrefix
{
    param
    (
        [System.String]
        $Type
    )

    if($Type.IndexOf('.') -eq -1)
    {
        return $Type
    }
    else
    {
        return ($Type.Split('.'))[0]
    }
}

function Compare-HPRESTSchemaVersion
{
<#
.SYNOPSIS
Compares Type fields of data and schema.

.DESCRIPTION
Compares Type field of data and schema and returns True if the schema and data have same major version and False if not. Type includes a name as well as version information. Version information is major.minor.errata (for example, SystemRoot.0.9.5). Anything but a major version is backward compatible, so a new property added to an object might result in minor Type increments (for example, Chassis.1.0.0 becomes Chassis.1.1.0). Moving to a major version change (for example, Chassis.2.0.0) is a breaking change without backward compatibility, and the HP iLO development team will be careful before making a big break like this. 

.PARAMETER DataType
Type field retrieved from the Data.

.PARAMETER SchemaType
Type field retrieved from Schema.

.EXAMPLE
PS C:\> Compare-HPRESTSchemaVersion -DataType ComputerSystem.0.9.5 -SchemaType ComputerSystem.0.9.5
True

The major version values are 0 for both data and schema. This example shows that when same major version values of the data and schema are same, the cmdlet returns true.

.EXAMPLE
PS c:\> Compare-HPRESTSchemaVersion -DataType ComputerSystem.0.9.5 -SchemaType ComputerSystem.1.0.0
False

The major version values are 0 and 1 for both data and schema respectively. This example shows that when same major version values of the data and schema are different, the cmdlet returns false.
#>
    param
    (

        [System.String]
        $DataType,

        [System.String]
        $SchemaType
    )

    $schMaxVer = $SchemaType.split('.')
    $datMaxVer = $DataType.Split('.')

    if($DataType.IndexOf($SchemaType) -gt -1 -or $SchemaType.IndexOf($DataType) -gt -1)
    {
        return $true
    }

    if([int]$schMaxVer[1] -ne [int]$datMaxVer[1])
    {
        return $false
    }
    else
    {
        <#
        if([int]$schMaxVer[2] -lt [int]$datMaxVer[2])
        {
            return $false
        }
        if(([int]$schMaxVer[2] -eq [int]$datMaxVer[2]) -and ([int]$schMaxVer[3] -lt [int]$datMaxVer[3]))
        {
            return $false
        }
        #>
        return $true
    }
}

function Merge-HPRESTPage
{
    param
    (
        [PSObject]
        $FinalObj,
	
        [PSObject]
        $ThisPage,

        [PSObject]
        $Session
    )

    if($ThisPage.links.PSObject.Properties.Name -contains 'NextPage')
    {
        $self = $ThisPage.links.self.href
        $uri = $self.Substring(0,$self.length-1)
        $page = [int]$self.Substring($self.length-1)
        $nextPageURI = $uri+($page+1)

        # get http data and convert to PSObject from JSON string
        try
        {
            $resp = Get-HPRESTHttpData -Href $nextPageURI -Session $Session
            $rs = $resp.GetResponseStream();
            [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
            $results = ''
            [string]$results = $sr.ReadToEnd();
            $nextPageData = $results|Convert-JsonToPSObject
            $resp.Close()
            $rs.Close()
            $sr.Close()

            # concatenate data into the final object
            foreach($i in $nextPageData.Items)
            {
                $FinalObj.Items += $i
            }
            foreach($m in $nextPageData.links.member)
            {
                $FinalObj.links.member += $m
            }
        }
        finally
        {
            if ($resp -ne $null -and $resp -is [System.IDisposable]){$resp.Close()}
            if ($rs -ne $null -and $rs -is [System.IDisposable]){$rs.Close()}
            if ($sr -ne $null -and $sr -is [System.IDisposable]){$sr.Close()}
        }

        if($nextPageData.links.PSObject.Properties.Name -contains ('NextPage'))
        {
            Merge-HPRESTPage -FinalObj $FinalObj -ThisPage $nextPageData -Session $Session
        }

        $newLinks = New-Object PSObject
        foreach($mem in $FinalObj.links.PSObject.Properties)
        {
            if($mem.Name -ne 'NextPage')
            {
                $newLinks|Add-Member $mem.Name $mem.Value
            }
        }
        $FinalObj.links = $newLinks
        $FinalObj.links.self.href = $self.Substring(0,$self.IndexOf('?'))
    }
}

function Set-Message
{
    param
    (
        [System.String]
        $Message,
	
        [System.Object]
        $MessageArg
    )

    $m = $Message
    for($i = 0; $i -lt $MessageArg.count; $i++)
    {
        $placeHolder = "%"+($i+1)
        $value = $MessageArg[$i]
        $m =  $m -replace $placeHolder, $value
    }
    return $m
}

function Get-ErrorRecord
{
    param
    (
        [System.Net.HttpWebResponse]
        $WebResponse,
	
        [System.String]
        $CmdletName
    )

    $webStream = $webResponse.GetResponseStream()
    $respReader = New-Object System.IO.StreamReader($webStream)
    $respJSON = $respReader.ReadToEnd()
    $webResponse.close()
    $webStream.close()
    $respReader.Close()
    $resp = $respJSON|Convert-JsonToPSObject
    $webResponse.Close()
            
    $noValidSession = $false
    $msg = ""
    if($resp.Messages.Count -gt 0)
    {
        foreach($msgID in $resp.Messages)
        {
            if($msgID.MessageId -match 'NoValidSession')
            {
                $noValidSession = $true
                $msg = $msg + $msgID.messageID + "`n"
                break
            }
        }
        if($noValidSession -eq $false)
        {
            foreach($msgID in $resp.Messages)
            {
                $msg = $msg + "`n" + $msgID.messageID
                $status = Get-HPRESTError -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $session
                foreach($mem in $status.PSObject.Properties)
                {
                    $msg = $msg + $mem.Name + ': ' + $mem.value + "`n"
                }
            }
        }
    }

    $message = $msg + ($_| Format-Table | Out-String)
    $targetObject = $CmdletName
    try{
        $exception = New-Object $_.Exception $message
        $errorID = $_.FullyQualifiedErrorId
        $errorCategory = $_.CategoryInfo.Category
    }
    catch
    {
        $exception = New-Object System.InvalidOperationException $message
        $errorID = 'InvocationException'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
    }
        

    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
}

function Find-PropertyEndIndex
{
    param
    (
        [System.String]
        $InputString,

        [System.String]
        $Property
    )

    $valueStartIndex = 0
    $valueStartFlag = $false
    $propIndex = $InputString.IndexOf('"'+$Property+'"')
    for($i=$propIndex; $i-lt $InputString.Length; $i++)
    {
        # mark start of value of property
        if($InputString[$i] -eq ":")
        {
            $valueStartFlag = $true
        }
        # set start index if { or [ are found
        elseif($InputString[$i] -eq "{" -or $InputString[$i] -eq "[")
        {
            $valueStartIndex = $i
            break
        }
        # if prop is simple e.g. -  prop1 : val1,
        elseif($InputString[$i] -eq "," -and $valueStartFlag -eq $true)
        {
            return $i
        }
        # if last property in the collection or object 
        # eg. if we search for prop2 in the array -> [{prop1: val1,prop2:val2}]
        elseif(($InputString[$i] -eq "]" -or $InputString[$i] -eq "}") -and $valueStartFlag -eq $true)
        {
            return $i-1
        }
    }


    $valueStartChar = $InputString[$valueStartIndex]
    
    $valueEndChar = ""
    if($valueStartChar -eq "{"){$valueEndChar = "}"}
    if($valueStartChar -eq "["){$valueEndChar = "]"}

    for($i=$valueStartIndex; $i-lt$InputString.Length; $i++)
    {
        if($InputString[$i] -eq $valueStartChar )
        {
            $stack.Push($valueStartChar)
        }
        elseif($InputString[$i] -eq $valueEndChar)
        {
            $x = $stack.Pop()
            if($stack.Count -eq 0)
            {
                #$str = $InputString.Substring($StartIndex, $i-$StartIndex+1)
                #Write-Host $str
                #break
                return $i
            }
        }
    }
}

function Remove-PropertyDuplicate
{
    param
    (
        [System.String]
        $InputJSONString,

        [System.String]
        $Property
    )

    
    $stack = New-Object System.Collections.Stack
    #$Property = "PrefixLength" #"Items"
    $propStartIndex = $InputJSONString.IndexOf('"'+$Property+'"')
    #$si = Find-ValueStartIndex -InputString $a -Property $prop
    #$ei = Find-ValueEndIndex -InputString $a -StartIndex $si
    $ei = Find-PropertyEndIndex -InputString $InputJSONString -Property $Property
    $prop = $InputJSONString.Substring($propStartIndex,$ei-$propStartIndex+1)
    #$prop

    $addtoprop = ""
    $propIndex = $InputJSONString.IndexOf($prop) + $prop.Length
    $commaFound = $false
    for($i=$propIndex+1; $i-lt $InputJSONString.Length; $i++)
    {
        # if the prop is last in the object or array - this is found if the next non-space char is closing bracket
        if($InputJSONString[$i] -eq "}" -or $InputJSONString[$i] -eq "]" )
        {
            # attach each char till previous comma
            for($j=$InputJSONString.IndexOf($prop)-1; $j-gt0; $j--)
            {
                $addtoprop = $InputJSONString[$j]+$addtoprop
                if($InputJSONString[$j] -eq ',')
                {
                    $commaFound = $true
                    break
                }
            }
            if($commaFound -eq $true)
            { 
                break
            }
        }
    }
    if($commaFound -eq $true -and $prop.LastIndexOf(",") -ne $prop.Length-1)
    {
        $prop = $addtoprop + $prop
    }
    return $InputJSONString.Replace($prop,"")

}

# use this method instead of ConvertFrom-Json to remove duplicates
function Convert-JsonToPSObject
{
    param
    (
        [System.String]
        [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $JsonString
    )

    try
    {
        $convertedPsobject = ConvertFrom-Json -InputObject $JsonString

    }
    catch [System.InvalidOperationException]
    {
        if($_.FullyQualifiedErrorId -eq "DuplicateKeysInJsonString,Microsoft.PowerShell.Commands.ConvertFromJsonCommand")
        {
            $spl = $_.Exception.Message.Split("'")
            $propToRemove = $spl[1]
            $jsonStringRemProp = Remove-PropertyDuplicate -InputJSONString $JsonString -Property $propToRemove
            $convertedPsobject = Convert-JsonToPSObject -JsonString $jsonStringRemProp
        }
        else
        {
            throw $_
        }
    }
    return $convertedPsobject
    
}


#-------------------------------------------------------------------------------------------------#
#-----------------------------------------HP REST Cmdlets-----------------------------------------#
#-------------------------------------------------------------------------------------------------#

function Connect-HPREST
{
<#
.SYNOPSIS
Creates a session between PowerShell client and the REST source.

.DESCRIPTION
Creates a session between the PowerShell client and the REST source using HTTP POST method and returns a session object. The session object has the following members:
1. 'X-Auth-Token' to identify the session
2. 'RootURI' of the REST source
3. 'Location' which is used for logging out of the session.
4. 'RootData' includes data from 'rest/v1'. It includes the rest details and the links to components like systems, chassis, etc.

.PARAMETER Address
IP address or Hostname of the target HP REST source.

.PARAMETER Username
Username of iLO account to access the HP REST source.

.PARAMETER Password
Password of iLO account to access the iLO.

.PARAMETER Cred
PowerShell PSCredential object having username and passwword of iLO account to access the iLO.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Address i.e. the hostname or IP address to Connect-HPREST.

.OUTPUTS
System.Management.Automation.PSCustomObject
Connect-HPREST returns a PSObject that has session details - X-Auth-Token, RootURI, Location and RootData.

.EXAMPLE
PS C:\> $s = Connect-HPREST -Address 192.184.217.212 -Username admin -Password admin123


PS C:\> $s|fl


RootUri      : https://192.184.217.212/rest/v1
X-Auth-Token : e02ce457b3fa4ad10f9ebc64d33c1445
Location     : https://192.184.217.212/rest/v1/Sessions/admin556733a2020c49bb
RootData     : @{Name=HP RESTful Root Service; Oem=; ServiceVersion=0.9.5; Time=2015-05-28T15:26:26Z; Type=ServiceRoot.0.10.1; UUID=8dea7372-23f9-565f-9396-2cd07febbe29; links=}


.EXAMPLE
PS C:\> $cred = Get-Credential
PS C:\> $s = Connect-HPREST -Address 192.184.217.212 -Cred $cred
PS C:\> $s|fl


RootUri      : https://192.184.217.212/rest/v1
X-Auth-Token : a5657bdsgfsdg3650f9ebc64d33c3262
Location     : https://192.184.217.212/rest/v1/Sessions/admin75675856ad6g25fg6
RootData     : @{Name=HP RESTful Root Service; Oem=; ServiceVersion=0.9.5; Time=2015-06-28T5:24:22Z; Type=ServiceRoot.0.10.1; UUID=8dea7372-23f9-565f-9396-2cd07f564629; links=}

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Address,

        [System.String]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Username,
        
        [System.String]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Password,

        [alias("Cred")] 
        [System.Management.Automation.PSCredential]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Credential
    )

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $session = $null
    $wr = $null
    $httpWebRequest = $null


    if($Credential -ne $null)
    {
        $un = $Credential.UserName
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
        $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    elseif($username -ne '' -and $password -ne '')
    {
        $un = $username
        $pw = $password
    }
    else
    {
        throw $(Get-Message('MSG_INVALID_CREDENTIALS'))
        #Write-Error 'Credentials not provided!'
        #return $null
    }
    
    $unpw = @{'UserName'=$un; 'Password'=$pw}
    $data = $unpw|ConvertTo-Json
    $session = $null

    try
    {
        $uri = "https://$Address/rest/v1/sessions"
        $wr = [System.Net.WebRequest]::Create($uri)
        $httpWebRequest = [System.Net.HttpWebRequest]$wr
        $httpWebRequest.Method = 'POST'
        $httpWebRequest.ContentType = 'application/json'
        $httpWebRequest.ContentLength = $data.length
        $reqWriter = New-Object System.IO.StreamWriter($httpWebRequest.GetRequestStream(), [System.Text.Encoding]::ASCII)
        $reqWriter.Write($data)
        $reqWriter.Close()
        
        try
        {
            $webResponse = $httpWebRequest.GetResponse()
            
            $rootUri = $webResponse.ResponseUri.ToString().Substring(0,$webResponse.ResponseUri.ToString().LastIndexOf("`/"))
            $session = New-Object PSObject   
            $session|Add-Member -MemberType NoteProperty 'RootUri' $rootUri
            $session|Add-Member -MemberType NoteProperty 'X-Auth-Token' $webResponse.Headers['X-Auth-Token']
            $session|Add-Member -MemberType NoteProperty 'Location' $webResponse.Headers['Location']

            $rootData = Get-HPRESTDataRaw -Href 'rest/v1' -Session $session
            $session|Add-Member -MemberType NoteProperty 'RootData' $rootData
            $webResponse.Close()
        }
        catch
        {
            $webResponse = $_.Exception.InnerException.Response
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $respJSON = $respReader.ReadToEnd()
            $resp = $respJSON|Convert-JsonToPSObject
            $webResponse.close()
            $webStream.Close()
            $respReader.Close()
            $msg = $_.Exception.Message
            if($resp.Messages.Count -gt 0)
            {
                foreach($msgID in $resp.Messages)
                {
                    $msg = $msg + "`n" + $msgID.messageID
                }
            }
            #$Global:Error.RemoveAt($Global:Error.Count-2)
            $Global:Error.RemoveAt(0)
            throw $msg
            #Write-Error -Message $msg -Category $_.CategoryInfo.Category -CategoryReason $_.CategoryInfo.CategoryReason

            
        }
      }
      finally
      {
          if ($null -ne $reqWriter -and $reqWriter -is [System.IDisposable]){$reqWriter.Dispose()}
          if ($null -ne $webResponse -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
          if ($null -ne $webStream -and $webStream -is [System.IDisposable]){$webStream.Dispose()}
          if ($null -ne $respReader -and $respReader -is [System.IDisposable]){$respReader.Dispose()}
      }

      return $Session
}

function Disconnect-HPREST
{
<#
.SYNOPSIS
Disconnects specified session between PowerShell client and REST source.

.DESCRIPTION
Disconnects the session between the PowerShell client and REST source by deleting the session information from location pointed to by Location field in Session object passed as parameter. Uses HTTP DELETE method for removing session information from location.

.PARAMETER Session
Session object that has Location information obtained by executing Connect-HPREST cmdlet.

.NOTES
The variable storing the session object will not become null/blank but cmdlets cannot not be executed using the session object.

.INPUTS
System.String
You can pipe the session object to Disconnect-HPREST. The session object is obtained from executing Connect-HPREST.

.OUTPUTS
This cmdlet does not generate any output.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> Disconnect-HPREST -Session $s
PS C:\> 

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Session
    )
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $wr = $null
    $httpWebRequest = $null
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    try
    {
        $wr = [System.Net.WebRequest]::Create($Session.Location)
        $httpWebRequest = [System.Net.HttpWebRequest]$wr
        $httpWebRequest.Method = 'DELETE'
        $httpWebRequest.ContentType = 'application/json'
        $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
        $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
        try
        {
            $webResponse = $httpWebRequest.GetResponse();
            $webResponse.Close()
            
        }
        catch
        {
            $webResponse = $_.Exception.InnerException.Response
            $webStream = $webResponse.GetResponseStream();
            [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $webStream;
            $resultJSON = $sr.ReadToEnd();
            $result = $resultJSON|Convert-JsonToPSObject
            $webResponse.close()
            $webStream.close()
            $sr.Close()
            $msg = $_.Exception.Message
            if($result.Messages.Count -gt 0)
            {
                foreach($msgID in $result.Messages)
                {
                    $msg = $msg + "`n" + $msgID.messageID
                }
            }
            $Global:Error.RemoveAt(0)
            throw $msg
            #Write-Error -Message $msg -Category $_.CategoryInfo.Category -CategoryReason $_.CategoryInfo.CategoryReason
        }

    }
    finally
    {
        if ($null -ne $webResponse -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
    }
}

function Edit-HPRESTData
{
<#
.SYNOPSIS
Executes HTTP PUT method on the destination server.

.DESCRIPTION
Executes HTTP PUT method on the desitination server with the data from InputObject parameter. Used for setting BIOS default settings.

.PARAMETER Href
Href where the setting is to be sent using HTTP PUT method.

.PARAMETER Setting
Data to be 'PUT' in name-value pair format. The parameter can be a hashtable with multiple name-value pairs.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.NOTES
- Edit-HPRESTData is for HTTP PUT method.
- Invoke-HPRESTAction is for HTTP POST method.
- Remove-HPRESTData is for HTTP DELETE method.
- Set-HPRESTData is for HTTP PATCH method.

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.


.INPUTS
System.String
You can pipe the Href to Edit-HPRESTData. Href points to the location where the PUT method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Edit-HPRESTData returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
PS C:\> $newBiosSetting=@{'BaseConfig'='Default'}
PS C:\> $ret = Edit-HPRESTData -Href rest/v1/systems/1/bios/Settings -Setting $newBiosSetting -Session $session
PS C:\> $ret

Messages                    Name                        Type                       
--------                    ----                        ----                       
{@{MessageID=iLO.0.10.Sy... Extended Error Information  ExtendedError.0.9.6        


PS C:\> $ret.Messages

MessageID                                                                          
---------                                                                          
iLO.0.10.SystemResetRequired                                                       


This example shows updating BIOS config to factory defaults.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.Object]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Setting,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )
  
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    if($Setting -eq $null -or $Setting -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Setting"))
    }
    if($Setting.GetType().ToString() -ne "System.Collections.Hashtable")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Setting.GetType().ToString() ,"Setting"))
    }
    
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $wr = $null
    $httpWebRequest = $null
    try
    {
        $data = $setting | ConvertTo-Json -Depth 10

        $uri = Get-HPRESTUriFromHref -Href $href -Session $Session
        
        if($uri.substring($uri.length -1) -eq "/")
        {
            $uri = $uri.substring(0,$uri.length-2)
        }
        $wr = [System.Net.WebRequest]::Create($uri)
        $httpWebRequest = [System.Net.HttpWebRequest]$wr
        $httpWebRequest.Method = 'PUT'
        $httpWebRequest.ContentType = 'application/json'
        $httpWebRequest.ContentLength = $data.length
        $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]'GZip'
        $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
        $reqWriter = New-Object System.IO.StreamWriter($httpWebRequest.GetRequestStream(), [System.Text.Encoding]::ASCII)
        $reqWriter.Write($data)
        $reqWriter.Close()
        
        try
        {
            $webResponse = $httpWebRequest.GetResponse()
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $resp = $respReader.ReadToEnd()

            $webResponse.Close()
            $webStream.Close()
            $respReader.Close()
        }
        catch
        {
            $webResponse = $_.Exception.InnerException.Response
            $errorRecord = Get-ErrorRecord -WebResponse $webResponse -CmdletName 'Edit-HPRESTData'
            $Global:Error.RemoveAt(0)
            throw $errorRecord
            #Write-Error -Message $msg -Category $_.CategoryInfo.Category -CategoryReason $_.CategoryInfo.CategoryReason
        }
    }
    finally
    {
        if ($null -ne $reqWriter -and $reqWriter -is [System.IDisposable]){$reqWriter.Dispose()}
        if ($null -ne $webResponse -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
        if ($null -ne $webStream -and $webStream -is [System.IDisposable]){$webStream.Dispose()}
        if ($null -ne $respReader -and $respReader -is [System.IDisposable]){$respReader.Dispose()}
    }

    return $resp|Convert-JsonToPSObject
}

function Find-HPREST 
{
<#
.SYNOPSIS
Find list of HP REST sources in a specified subnet.

.DESCRIPTION
Lists HP REST sources in the subnet provided. You must provide the subnet in which the REST sources have to be searched.

.PARAMETER Range
Specifies the lower parts of the IP addresses which is the subnet in which the REST sources are being searched. For IP address format 'a.b.c.d', where a, b, c, d represent an integer from 0 to 255, the Range parameter can have values such  as: 
a - eg: 10 - for all IP addresses in 10.0.0.0 to 10.255.255.255
a.b - eg: 10.44 - for all IP addresses in 10.44.0.0 to 10.44.255.255
a.b.c - eg: 10.44.111 - for all IP addresses in 10.44.111.0 to 10.44.111.255
a.b.c.d - eg: 10.44.111.222 - for IP address 10.44.111.222
Each division of the IP address, can specify a range using a hyphen. eg: 
"10.44.111.10-12" returns IP addresses 10.44.111.10, 10.44.111.11, 10.44.111.12
Each division of the IP address, can specify a set using a comma. eg: 
"10.44.111.10,12" returns IP addresses 10.44.111.10, 10.44.111.12

.PARAMETER Timeout
Timeout period for ping request. Timeout period can be specified by the user where there can be a possible lag due to geographical distance between client and server. Default value is 300 which is 300 milliseconds. If the default timeout is not long enough, no REST sources will be found and no errors 
will be displayed.

.INPUTS
String or a list of String specifying the lower parts of the IP addresses which is the subnet in which the REST sources are being searched. For IP address format 'a.b.c.d', where a, b, c, d represent an integer from 0 to 255, the Range parameter can have values such as: 
    a - eg: 10 - for all IP addresses in 10.0.0.0 to 10.255.255.255
    a.b - eg: 10.44 - for all IP addresses in 10.44.0.0 to 10.44.255.255
    a.b.c - eg: 10.44.111 - for all IP addresses in 10.44.111.0 to 10.44.111.255
    a.b.c.d - eg: 10.44.111.222 - for IP address 10.44.111.222
Each division of the IP address, can specify a range using a hyphen. eg: "10.44.111.10-12" returns IP addresses 10.44.111.10, 10.44.111.11, 10.44.111.12.
Each division of the IP address, can specify a set using a comma. eg: "10.44.111.10,12" returns IP addresses 10.44.111.10, 10.44.111.12
Note: Both IPv4 and IPv6 ranges are supported.
Note: Port number is optional. With port number 8888 the input are 10:8888, 10.44:8888, 10.44.111:8888, 10.44.111.222:8888; Without port number, default port in iLO is used.

.OUTPUTS
 System.Management.Automation.PSObject[]
List of service Name, Oem details, Service Version, Links, IP, and hostname for valid REST sources in the subnet.
Use Get-Member to get details of fields in returned objects.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> Find-HPREST -Range 192.184.217.210-215
WARNING: It might take a while to search for all the HP Rest sources if the input is
 a very large range. Use Verbose for more information.


Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 2015-05-28T03:48:12Z
Type           : ServiceRoot.0.10.1
UUID           : 174f7247-ccd3-5b3f-9c15-fe4ae0bcfe14
links          : @{AccountService=; Chassis=; EventService=; Managers=; 
                 Registries=; Schemas=; Sessions=; Systems=; self=}
IP             : 192.184.217.211
HOSTNAME       : ilo-xl23.americas.net

Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 2015-05-28T15:50:41Z
Type           : ServiceRoot.0.10.1
UUID           : 8dea7372-23f9-565f-9396-2cd07febbe29
links          : @{AccountService=; Chassis=; EventService=; Managers=; 
                 Registries=; Schemas=; Sessions=; Systems=; self=}
IP             : 192.184.217.212
HOSTNAME       : ilogen9.americas.net

Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 1970-01-02T11:44:18Z
Type           : ServiceRoot.0.10.0
links          : @{AccountService=; Chassis=; Managers=; Registries=; Schemas=; 
                 Sessions=; Systems=; self=}
IP             : 192.184.217.213
HOSTNAME       : ilom7.americas.net

Name           : HP RESTful Root Service
Oem            : @{Hp=}
ServiceVersion : 0.9.5
Time           : 2015-05-27T09:40:19Z
Type           : ServiceRoot.0.10.0
links          : @{AccountService=; Chassis=; Managers=; Registries=; Schemas=; 
                 Sessions=; Systems=; self=}
IP             : 192.184.217.215
HOSTNAME       : ilom4.americas.net

.LINK
http://www.hp.com/go/powershell

#>
    param (
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)] [alias('IP')] $Range,
        [parameter(Mandatory=$false)] $Timeout = 300
    )
    Add-Type -AssemblyName System.Core

    $ping    = New-Object System.Net.NetworkInformation.Ping
    $options = New-Object System.Net.NetworkInformation.PingOptions(20, $false)
    $bytes   =  0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb
    $iptoping = New-Object System.Collections.Generic.HashSet[String]
    $pingedRSTs = @()
    $validformat = $false

    #put all the input range in to array (one for IPv4, the other for IPv6)
    $InputIPv4Array = @()
    $InputIPv6Array = @() 

    # size of $IPv4Array will be the same as size of $InputIPv4Array, the same case to IPv6
    $IPv4Array = @()
    $IPv6Array = @()
	
    $ipv6_one_section='[0-9A-Fa-f]{1,4}'
    $ipv6_one_section_phen="$ipv6_one_section(-$ipv6_one_section)?"
	$ipv6_one_section_phen_comma="$ipv6_one_section_phen(,$ipv6_one_section_phen)*"

    $ipv4_one_section='(2[0-4]\d|25[0-5]|[01]?\d\d?)'
	$ipv4_one_section_phen="$ipv4_one_section(-$ipv4_one_section)?"
	$ipv4_one_section_phen_comma="$ipv4_one_section_phen(,$ipv4_one_section_phen)*"

    $ipv4_regex_inipv6="${ipv4_one_section_phen_comma}(\.${ipv4_one_section_phen_comma}){3}"  
    $ipv4_one_section_phen_comma_dot_findhpilo="(\.\.|\.|${ipv4_one_section_phen_comma}|\.${ipv4_one_section_phen_comma}|${ipv4_one_section_phen_comma}\.)"

    $port_regex = ':([1-9]|[1-9]\d|[1-9]\d{2}|[1-9]\d{3}|[1-5]\d{4}|6[0-4]\d{3}|65[0-4]\d{2}|655[0-2]\d|6553[0-5])'
	$ipv6_regex_findhpilo="^\s*(${ipv4_regex_inipv6}|${ipv6_one_section_phen_comma}|((${ipv6_one_section_phen_comma}:){1,7}(${ipv6_one_section_phen_comma}|:))|((${ipv6_one_section_phen_comma}:){1,6}(:${ipv6_one_section_phen_comma}|${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,5}(((:${ipv6_one_section_phen_comma}){1,2})|:${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,4}(((:${ipv6_one_section_phen_comma}){1,3})|((:${ipv6_one_section_phen_comma})?:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,3}(((:${ipv6_one_section_phen_comma}){1,4})|((:${ipv6_one_section_phen_comma}){0,2}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,2}(((:${ipv6_one_section_phen_comma}){1,5})|((:${ipv6_one_section_phen_comma}){0,3}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1}(((:${ipv6_one_section_phen_comma}){1,6})|((:${ipv6_one_section_phen_comma}){0,4}:${ipv4_regex_inipv6})|:))|(:(((:${ipv6_one_section_phen_comma}){1,7})|((:${ipv6_one_section_phen_comma}){0,5}:${ipv4_regex_inipv6})|:)))(%.+)?\s*$" 
	$ipv6_regex_findhpilo_with_bra ="^\s*\[(${ipv4_regex_inipv6}|${ipv6_one_section_phen_comma}|((${ipv6_one_section_phen_comma}:){1,7}(${ipv6_one_section_phen_comma}|:))|((${ipv6_one_section_phen_comma}:){1,6}(:${ipv6_one_section_phen_comma}|${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,5}(((:${ipv6_one_section_phen_comma}){1,2})|:${ipv4_regex_inipv6}|:))|((${ipv6_one_section_phen_comma}:){1,4}(((:${ipv6_one_section_phen_comma}){1,3})|((:${ipv6_one_section_phen_comma})?:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,3}(((:${ipv6_one_section_phen_comma}){1,4})|((:${ipv6_one_section_phen_comma}){0,2}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1,2}(((:${ipv6_one_section_phen_comma}){1,5})|((:${ipv6_one_section_phen_comma}){0,3}:${ipv4_regex_inipv6})|:))|((${ipv6_one_section_phen_comma}:){1}(((:${ipv6_one_section_phen_comma}){1,6})|((:${ipv6_one_section_phen_comma}){0,4}:${ipv4_regex_inipv6})|:))|(:(((:${ipv6_one_section_phen_comma}){1,7})|((:${ipv6_one_section_phen_comma}){0,5}:${ipv4_regex_inipv6})|:)))(%.+)?\]($port_regex)?\s*$" 	
    $ipv4_regex_findhpilo="^\s*${ipv4_one_section_phen_comma_dot_findhpilo}(\.${ipv4_one_section_phen_comma_dot_findhpilo}){0,3}($port_regex)?\s*$"
  		
    if ($Range.GetType().Name -eq 'String')
    {
        if(($range -match $ipv4_regex_findhpilo) -and (4 -ge (Get-IPv4-Dot-Num -strIP  $range)))
        {
            $InputIPv4Array += $Range            
            $validformat = $true
        }
        elseif($range -match $ipv6_regex_findhpilo -or $range -match $ipv6_regex_findhpilo_with_bra)
        {
            if($range.contains(']') -and $range.Split(']')[0].Replace('[','').Trim() -match $ipv4_regex_findhpilo)  #exclude [ipv4] and [ipv4]:port
            {
			   $validformat = $false
               throw $(Get-Message('MSG_INVALID_RANGE'))
            }
            else
            {
               $InputIPv6Array += $Range            
               $validformat = $true
            }
        }
        else
        {
			#Write-Error $(Get-Message('MSG_INVALID_RANGE'))
            $validformat = $false
            throw $(Get-Message('MSG_INVALID_RANGE'))
        }	
        
    }
	elseif($Range.GetType().Name -eq 'Object[]')
    {
        $hasvalidinput=$false
        foreach($r in $Range)
        {            
            if(($r -match $ipv4_regex_findhpilo)  -and (4 -ge (Get-IPv4-Dot-Num -strIP  $r)) )
            {
                $InputIPv4Array += $r                
                $hasvalidinput=$true
            }
            elseif($r -match $ipv6_regex_findhpilo -or $r -match $ipv6_regex_findhpilo_with_bra)
            {
                if($r.contains(']') -and $r.Split(']')[0].Replace('[','').Trim() -match $ipv4_regex_findhpilo) #exclude [ipv4] and [ipv4]:port
                {
                   Write-Warning $([string]::Format($(Get-Message('MSG_INVALID_PARAMETER')) ,$r))           
                }
                else
                {
                   $InputIPv6Array += $r
                   $hasvalidinput=$true
                }
            }
            else
            {
                Write-Warning $([string]::Format($(Get-Message('MSG_INVALID_PARAMETER')) ,$r))           
            }                    
        }
        $validformat = $hasvalidinput        
    }
    else
    {
           $validformat = $false
           throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Range.GetType().Name, 'Range'))
    }
    
    if($Timeout -ne $null){
        if(($Timeout -match "^\s*[1-9][0-9]*\s*$") -ne $true){ 		
            $validformat = $false
            throw $(Get-Message('MSG_INVALID_TIMEOUT'))
        }
    }
	
    if($InputIPv4Array.Length -gt 0)
    {
        #$IPv4Array = New-Object 'object[,]' $InputIPv4Array.Length,4
        $IPv4Array = New-Object System.Collections.ArrayList              
        foreach($inputIP in $InputIPv4Array)
        {
           if($inputIP.contains(':'))
           {
              $returnip = Complete-IPv4 -strIP $inputIP.Split(':')[0].Trim()
              $returnip = $returnip + ':' + $inputIP.Split(':')[1].Trim()      
           }
           else
           {
              $returnip = Complete-IPv4 -strIP $inputIP
           }
           $x = $IPv4Array.Add($returnip)
        }
    }

    if($InputIPv6Array.Length -gt 0)
    {
        #$IPv6Array = New-Object'object[,]' $InputIPv6Array.Length,11
        $IPv6Array = New-Object System.Collections.ArrayList        
        foreach($inputIP in $InputIPv6Array)
        { 
            if($inputIP.contains(']')) #[ipv6] and [ipv6]:port
            {
               $returnip = Complete-IPv6 -strIP $inputIP.Split(']')[0].Replace('[','').Trim()
               $returnip = '[' + $returnip + ']' + $inputIP.Split(']')[1].Trim()
            }
            else #ipv6 without [] nor port
            {
               $returnip = Complete-IPv6 -strIP $inputIP 
               $returnip = '[' + $returnip + ']'
            }
            $x = $IPv6Array.Add($returnip)
        }
    }   

	
	if($validformat)
	{	
		Write-Warning $(Get-Message('MSG_FIND_LONGTIME'))
        foreach($ipv4 in $IPv4Array)
        { 
            if($ipv4.contains(':')) #contains port
            {
               $retarray = Get-IPArrayFromString -stringIP $ipv4.Split(':')[0].Trim() -IPType 'IPv4'
               foreach($oneip in $retarray)
               {
                  $x = $ipToPing.Add($oneip + ':' + $ipv4.Split(':')[1].Trim())
               }                 
            }
            else
            {
               $retarray = Get-IPArrayFromString -stringIP $ipv4 -IPType 'IPv4'
               foreach($oneip in $retarray)
               {
                  $x = $ipToPing.Add($oneip)
               }  
            }                  
        }
				
        foreach($ipv6 in $IPv6Array) #all ipv6 has been changed to [ipv6] or [ipv6]:port
        { 
           $retarray = Get-IPv6FromString -stringIP $ipv6.Split(']')[0].Replace('[','').Trim() 
           foreach($oneip in $retarray)
           {
              $x = $ipToPing.Add('[' + $oneip + ']' + $ipv6.Split(']')[1].Trim())
           }                           
        }		
		  
        $rstList = @()
		$ThreadPipes = @()
		$poolsize = (@($ipToPing.Count, 256) | Measure-Object -Minimum).Minimum
		if($poolsize -eq 0)
		{
			$poolsize = 1
		}
		Write-Verbose -Message $([string]::Format($(Get-Message('MSG_USING_THREADS_FIND')) ,$poolsize))
		$thispool = Create-ThreadPool $poolsize
		$t = {
			    Param($aComp, $aComp2, $timeout,$RM)

                Function Get-Message
                {
                    Param
                    (
                        [Parameter(Mandatory=$true)][String]$MsgID
                    )
                     #only these strings are used in the two script blocks
                    $LocalizedStrings=@{
	                    'MSG_SENDING_TO'='Sending to {0}'
	                    'MSG_FAIL_HOSTNAME'='DNS name translation not available for {0} - Host name left blank.'
	                    'MSG_FAIL_IPADDRESS'='Invalid Hostname: IP Address translation not available for hostname {0}.'
	                    'MSG_PING'='Pinging {0}'
	                    'MSG_PING_FAIL'='No system responds at {0}'
	                    'MSG_FIND_NO_SOURCE'='No HP Rest source at {0}'
	                    }
                    $Message = ''
                    try
                    {
                        $Message = $RM.GetString($MsgID)
                        if($Message -eq $null)
                        {
                            $Message = $LocalizedStrings[$MsgID]
                        }
                    }
                    catch
                    {
                        #throw $_
		                $Message = $LocalizedStrings[$MsgID]
                    }

                    if($Message -eq $null)
                    {
		                #or unknown
                        $Message = 'Fail to get the message'
                    }
                    return $Message
                }

                Function New-TrustAllWebClient 
                {
                    <# 
                      Source for New-TrustAllWebClient is found at http://poshcode.org/624
                      Use is governed by the Creative Commons "No Rights Reserved" license
                      and is considered public domain see http://creativecommons.org/publicdomain/zero/1.0/legalcode 
                      published by Stephen Campbell of Marchview Consultants Ltd. 
                    #>

                    <# Create a compilation environment #>
                    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
                    $Compiler=$Provider.CreateCompiler()
                    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
                    $Params.GenerateExecutable=$False
                    $Params.GenerateInMemory=$True
                    $Params.IncludeDebugInformation=$False
                    $Params.ReferencedAssemblies.Add('System.DLL') > $null
                    $TASource=@'
                        namespace Local.ToolkitExtensions.Net.CertificatePolicy {
                            public class TrustAll : System.Net.ICertificatePolicy {
                                public TrustAll() { 
                                }
                                public bool CheckValidationResult(System.Net.ServicePoint sp,
                                    System.Security.Cryptography.X509Certificates.X509Certificate cert, 
                                    System.Net.WebRequest req, int problem) {
                                    return true;
                                }
                            }
                        }
'@ 
                    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
                    $TAAssembly=$TAResults.CompiledAssembly

                    <# We now create an instance of the TrustAll and attach it to the ServicePointManager #>
                    $TrustAll=$TAAssembly.CreateInstance('Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll')
                    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

                    <#
                     The ESX Upload requires the Preauthenticate value to be true which is not the default
                     for the System.Net.WebClient class which has very simple-to-use downloadFile and uploadfile
                     methods.  We create an override class which simply sets that Preauthenticate value.
                     After creating an instance of the Local.ToolkitExtensions.Net.WebClient class, we use it just
                     like the standard WebClient class.
                    #>
                    $Params1=New-Object System.CodeDom.Compiler.CompilerParameters
                    $Params1.GenerateExecutable=$False
                    $Params1.GenerateInMemory=$True
                    $Params1.IncludeDebugInformation=$False
                    $Params1.ReferencedAssemblies.Add('System.DLL') > $null
                    $WCSource=@'
                        namespace Local.ToolkitExtensions.Net { 
                                class WebClient : System.Net.WebClient {
                                protected override System.Net.WebRequest GetWebRequest(System.Uri uri) {
                                    System.Net.WebRequest webRequest = base.GetWebRequest(uri);
                                    webRequest.PreAuthenticate = true;
                                    webRequest.Timeout = 60000;
                                    return webRequest;
                                }
                            }
                        }
'@
                    $WCResults=$Provider.CompileAssemblyFromSource($Params1,$WCSource)
                    $WCAssembly=$WCResults.CompiledAssembly

                    <# Now return the custom WebClient. It behaves almost like a normal WebClient. #>
                    $WebClient=$WCAssembly.CreateInstance('Local.ToolkitExtensions.Net.WebClient')
                    return $WebClient
                }

			    $ping    = New-Object -TypeName System.Net.NetworkInformation.Ping
			    $options = New-Object -TypeName System.Net.NetworkInformation.PingOptions -ArgumentList (20, $false)
			    $bytes   =  0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb, 0xdb
			    $retobj = New-Object -TypeName PSObject   
			    try
			    {			
				    $pingres = $ping.Send($aComp2, $timeout, [Byte[]]$bytes, $options )
				    if ($pingres.Status -eq 'Success') 
                    {
					    $rstAddr = $pingres.Address.IPAddressToString
					    $client = New-Object -TypeName System.Net.WebClient
								  
					    try 
					    {   
                            try
                            {
                              $data = $client.DownloadData("http://$aComp/rest/v1")                   
                            }
                            catch
                            {
                              $client = New-TrustAllWebClient
                              $data = $client.DownloadData("https://$aComp/rest/v1")                   
                            }                 
						
						    $str = ''
						    $data | % {$str += [char]$_}
						    $rstobj = ConvertFrom-Json $str 
						    $rstobj |   Add-Member NoteProperty IP  $rstAddr 
						    $rstobj |   Add-Member NoteProperty HOSTNAME $null
						    try
						    {
							    $dns = [System.Net.Dns]::GetHostEntry($rstAddr)
							    $rstobj.Hostname = $dns.Hostname
						    }
						    catch
						    {
							    $retobj | Add-Member NoteProperty errormsg $([string]::Format($(Get-Message('MSG_FAIL_HOSTNAME')), $rstAddr))
						    }
						    if(($rstobj.Type).indexOf('ServiceRoot.') -ne -1) 
                            {
							    $retobj | Add-Member NoteProperty data $rstobj
						    }
					    }
					    catch 
					    {
						    $retobj | Add-Member NoteProperty errormsg $([string]::Format($(Get-Message('MSG_FIND_NO_SOURCE')), $rstAddr))
					    }
				    }
				    else
				    {
					    $retobj | Add-Member NoteProperty errormsg  $([string]::Format($(Get-Message('MSG_PING_FAIL')), $aComp2))
				    }
			    }
			    catch
			    {
				    $retobj | Add-Member NoteProperty errormsg  $([string]::Format($(Get-Message('MSG_PING_FAIL')), $aComp2))
			    }
			    return $retobj
        } 
		#end of $t scriptblock
            
		foreach ($comp in $ipToPing) {
			Write-Verbose -Message $([string]::Format($(Get-Message('MSG_PING')) ,$comp))
            $comp2=$comp
            if($comp -match $ipv4_regex_findhpilo -and $comp.contains(':')) #ipv4:port
            {
               $comp2 = $comp.Split(':')[0].Trim()
            }
            elseif($comp -match $ipv6_regex_findhpilo_with_bra) #all ipv6 have been added [] after completing address
            {
               if($comp.contains(']:')) #[ipv6]:port
               {
                 $comp2 = $comp.Split(']')[0].Replace('[','').Trim()
               }
               else #[ipv6]
               {
                 $comp2 = $comp.Replace('[','').Replace(']','').Trim()
               }
            }
            
			$ThreadPipes += Start-ThreadScriptBlock -ThreadPool $thispool -ScriptBlock $t -Parameters $comp,$comp2, $Timeout, $RM
		}

		#this waits for and collects the output of all of the scriptblock pipelines - using showprogress for verbose
		if ($VerbosePreference -eq 'Continue') {
			$rstList = Get-ThreadPipelines -Pipelines $ThreadPipes -ShowProgress
		}
		else {
			$rstList = Get-ThreadPipelines -Pipelines $ThreadPipes
		}
		$thispool.Close()
		$thispool.Dispose()
        foreach($ilo in $rstList)
        {
			if($ilo.errormsg -ne $null)
            {
                Write-Verbose $ilo.errormsg
            }
            
            if($ilo.data -ne $null)
            {
                $ilo.data
            }
        }  
        
    }    
    else{
        #Write-Error $(Get-Message('MSG_INVALID_USE'))
        throw $(Get-Message('MSG_INVALID_USE'))
    }
}
#end of Find-HPRest

function Format-HPRESTDir
{
<#
.SYNOPSIS
Displays HP REST data in directory format.

.DESCRIPTION
Takes the node array returned by Get-HPRESTDir and displays each node as a directory.

.PARAMETER NodeArray
The array created by Get-HPRESTDir, containing a collection of REST API nodes in an array.

.PARAMETER Session
Session PSObject returned by executing -HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER AutoSize
Switch parameter that turns the autosize feature on when true.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the NodeArray obtained from Get-HPRESTDir to Format-HPRESTDir.

.OUTPUTS
System.Management.Automation.PSCustomObject or System.Object[]
Format-HPRESTDir returns a PSCustomObject or an array of PSCustomObject if Recurse parameter is set to true.

.EXAMPLE
PS C:\> $href = 'rest/v1/sessions'

PS C:\> $nodeArray = Get-HPRESTDir -Session $s -Href $href -Recurse

PS C:\> Format-HPRESTDir -NodeArray $NodeArray

Location: https://192.184.217.212/rest/v1
Link: /rest/v1/Sessions

Type           Name                Value                                                            
----           ----                -----                                                            
String         @odata.context      /redfish/v1/$metadata#Sessions                                   
String         @odata.id           /redfish/v1/Sessions/                                            
String         @odata.type         #SessionCollection.SessionCollection                             
String         Description         Manager User Sessions                                            
Object[]       Items               {@{@odata.context=/redfish/v1/$metadata#SessionService/Session...
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
PSCustomObject links               @{Member=System.Object[]; self=}                                 
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
               href                /rest/v1/Sessions                                                
Object[]       Members             {@{@odata.id=/redfish/v1/SessionService/Sessions/admin55dd017b...
Int32          Members@odata.count 1                                                                
String         MemberType          Session.1                                                        
String         Name                Sessions                                                         
PSCustomObject Oem                 @{Hp=}                                                           
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
Int32          Total               1                                                                
String         Type                Collection.1.0.0                                                 


Link: /rest/v1/SessionService/Sessions/admin55dd017b39999998

Type           Name           Value                                                        
----           ----           -----                                                        
String         @odata.context /redfish/v1/$metadata#SessionService/Sessions/Members/$entity
String         @odata.id      /redfish/v1/SessionService/Sessions/admin55dd017b39999998/   
String         @odata.type    #Session.1.0.0.Session                                       
String         Description    Manager User Session                                         
String         Id             admin55dd017b39999998                                        
PSCustomObject links          @{self=}                                                     
               href           /rest/v1/SessionService/Sessions/admin55dd017b39999998       
String         Name           User Session                                                 
PSCustomObject Oem            @{Hp=}                                                       
String         Type           Session.1.0.0                                                
String         UserName       admin                                                        


Link: /rest/v1/Sessions

Type           Name                Value                                                            
----           ----                -----                                                            
String         @odata.context      /redfish/v1/$metadata#Sessions                                   
String         @odata.id           /redfish/v1/Sessions/                                            
String         @odata.type         #SessionCollection.SessionCollection                             
String         Description         Manager User Sessions                                            
Object[]       Items               {@{@odata.context=/redfish/v1/$metadata#SessionService/Session...
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
PSCustomObject links               @{Member=System.Object[]; self=}                                 
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
               href                /rest/v1/Sessions                                                
Object[]       Members             {@{@odata.id=/redfish/v1/SessionService/Sessions/admin55dd017b...
Int32          Members@odata.count 1                                                                
String         MemberType          Session.1                                                        
String         Name                Sessions                                                         
PSCustomObject Oem                 @{Hp=}                                                           
               href                /rest/v1/SessionService/Sessions/admin55dd017b39999998           
Int32          Total               1                                                                
String         Type                Collection.1.0.0                                                 



This example shows the formatted node array obtained from href for sessions.The list of Href links in a property are listed below the property name and value

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        #($NodeArray, $Session, $AutoSize)
        [System.Object[]]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $NodeArray,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [switch]
        [parameter(Mandatory=$false)]
        $AutoSize
    )
    BEGIN 
    {
        function Find-Hrefs($nodeForFindHref)
        {
            $nodeForFindHref | Get-Member -type NoteProperty | foreach {
                $name = $_.Name ;
                $value = $nodeForFindHref."$($_.Name)"
                if($name -eq "href")
                {
                    foreach($v in $value)
                    { 
                        $NodeProperties = New-Object System.Object
                        $NodeProperties | Add-Member -type NoteProperty -name Type -value $null
                        $NodeProperties | Add-Member -type NoteProperty -name Name -value $name
                        $NodeProperties | Add-Member -type NoteProperty -name Value -value $v
                        $Global:DirValues += $NodeProperties
                    }
                }

                elseif($value -ne $null -and ($value |gm).MemberType -contains "NoteProperty")
                {
                    Find-Hrefs -nodeForFindHref $value
                }
            }
        }

        Function Format-Node($nodeForFormat, $href)
        {
            "Link: $href"
            $Global:DirValues = @()
            $nodeForFormat | get-member -type NoteProperty | foreach-object {
                $name = $_.Name ; 
                $value = $nodeForFormat."$($_.Name)"
                if($value -ne $null)
                {
                    $NodeProperties = New-Object System.Object
                    $NodeProperties | Add-Member -type NoteProperty -name Type -value $value.GetType().name
                    $NodeProperties | Add-Member -type NoteProperty -name Name -value $name
                    $NodeProperties | Add-Member -type NoteProperty -name Value -value $value
                    $Global:DirValues += $NodeProperties
                }
                else
                {
                    $NodeProperties = New-Object System.Object
                    $NodeProperties | Add-Member -type NoteProperty -name Type -value "Null"
                    $NodeProperties | Add-Member -type NoteProperty -name Name -value $name
                    $NodeProperties | Add-Member -type NoteProperty -name Value -value $value
                    $Global:DirValues += $NodeProperties
                }
                if($value -ne $null -and ($value |gm).MemberType -contains "NoteProperty")
                {
                    Find-Hrefs -nodeForFindHref $value
                }
            }
            if($AutoSize -eq $true)
            {
                $Global:DirValues | FT -AutoSize
            }
            else
            {
                $Global:DirValues | FT
            }
        }
        if(!($session.Location -eq $null -or $session.Location -eq ""))
        {
            "$(Get-Message('MSG_FORMATDIR_LOCATION')): $($Session.RootUri)"
        }
    }
    PROCESS
    {
        if($NodeArray.GetType().ToString() -match 'PScustomobject')
        {
            $href1 = $NodeArray.links.self.href
            Format-Node -nodeForFormat $NodeArray -href $href1
        }
        elseif($NodeArray.GetType().ToString() -eq 'System.Object[]')
        {
            foreach($node1 in $NodeArray)
            {
                if($node1.GetType().ToString() -match 'PSCustomObject')
                {
                    $href1 = $node1.links.self.href
                    Format-Node -nodeForFormat $node1 -href $href1
                }
                else
                {
                    throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $node1.GetType().Name, 'NodeArray'))
                }
            }
        }
    }
    END
    {

    }
}

function Get-HPRESTData
{
<#
.SYNOPSIS
Retrieves Data and Properties of data for provided Href.

.DESCRIPTION
Retrieves Data and Properties for data specified by given Href. This cmdlet returns two sets of values - Data and properties. The properties include if the data item is readonly, possible values in enum, enum values' descriptions and datatypes of allowed value.

.PARAMETER Href
Href of the data for which data and properties are to be retrieved.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.INPUTS
System.String
You can pipe the Href to Get-HPRESTData.

.OUTPUTS
Two objects of type System.Management.Automation.PSCustomObject or one object of System.Object[]
Get-HPRESTData returns two object of type PSObject - first has the retrieved data and the second has properties in the form of System.Collections.Hashtable. If you use one variable for returned object, then the variable will be an array with first term as the data PSObject and second element as the property list in System.Collections.Hashtable

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.


.EXAMPLE
PS C:\> $data,$prop = Get-HPRESTData -Href rest/v1/systems/1 -Session $s

PS C:\> $data


AssetTag         : 
AvailableActions : {@{Action=Reset; Capabilities=System.Object[]}}
Bios             : @{Current=}
Boot             : @{BootSourceOverrideEnabled=Disabled; BootSourceOverrideSupported=System.Object[]; 
                   BootSourceOverrideTarget=None; UefiTargetBootSourceOverride=None; 
                   UefiTargetBootSourceOverrideSupported=System.Object[]}
Description      : Computer System View
HostCorrelation  : @{HostMACAddress=System.Object[]; HostName=; IPAddress=System.Object[]}
IndicatorLED     : Off
Manufacturer     : HP
Memory           : @{Status=; TotalSystemMemoryGB=8}
Model            : ProLiant DL380 Gen9
Name             : Computer System
Oem              : @{Hp=}
Power            : On
Processors       : @{Count=2; ProcessorFamily=Intel(R) Xeon(R) CPU E5-2683 v3 @ 2.00GHz; Status=}
SKU              : 501101-001
SerialNumber     : LCHAS01RJ5Y00Z
Status           : @{Health=Warning; State=Enabled}
SystemType       : Physical
Type             : ComputerSystem.0.9.7
UUID             : 31313035-3130-434C-4841-533031524A35
links            : @{Chassis=System.Object[]; Logs=; ManagedBy=System.Object[]; self=}




PS C:\> $prop

Name                           Value                                                                                    
----                           -----                                                                                    
BootSourceOverrideSupported    @{Schema_AllowedValue=System.Object[]; schema_enumDescriptions=; Schema_Type=System.Ob...
UUID                           @{Schema_Description=The universal unique identifier for this system.; Schema_Type=Sys...
Status                         @{Schema_Description=This property indicates the TPM or TM status.; Schema_AllowedValu...
Description                    @{Schema_Description=This object represents the Description property.; Schema_Type=str...
PowerOnDelay                   @{Schema_Description=The PowerAutoOn policy delay that can also be found in the HpBios...
BootSourceOverrideTarget       @{Schema_Description=The current boot source to be used at next boot instead of the no...
Model                          @{Schema_Description=The model information that the manufacturer uses to refer to this...
Name                           @{Schema_Description=The name of the resource or array element.; Schema_Type=string; S...
Date                           @{Schema_Description=The build date of the firmware.; Schema_Type=string; Schema_ReadO...
  .
  .
  .
IntelligentProvisioningVersion @{Schema_Description= Intelligent Provisioning Version.; Schema_Type=string; Schema_Re...
IntelligentProvisioningIndex   @{Schema_Description= Index in the Firmware Version Table for Intelligent Provisioning...
AssetTag                       @{Schema_Description=A user-definable tag that is used to track this system for invent...
AllowableValues                @{Schema_Description=The supported values for this property on this resource.; Schema_...
BootSourceOverrideEnabled      @{Schema_Description=BootSourceOverrideTarget must be specified before BootSourceOverr...
IndicatorLED                   @{Schema_Description=The state of the indicator LED.; Schema_AllowedValue=System.Objec...
href                           @{Schema_Description=The URI of an internal resource; Schema_Type=string; Schema_ReadO...
VersionString                  @{Schema_Description=This string represents the version of the firmware image.; Schema...



PS C:\> $prop.IndicatorLED


Schema_Description      : The state of the indicator LED.
Schema_AllowedValue     : {Unknown, Lit, Blinking, Off}
schema_enumDescriptions : @{Unknown=The state of the Indicator LED cannot be determined.; Lit=The Indicator LED is 
                          lit.; Blinking=The Indicator LED is blinking.; Off=The Indicator LED is off.}
Schema_Type             : {string, null}
Schema_ReadOnly         : False

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    $data = Get-HPRESTDataRaw -Href $href -Session $Session
    $schema = Get-HPRESTSchema -Type $data.Type -Session $Session
    $DictionaryOfSchemas = [System.Collections.Hashtable]@{}

    $data, $props = Get-HPRESTDataProp2 -Data $data -Schema $schema -Session $Session -DictionaryOfSchemas $DictionaryOfSchemas
    return $data, $props
}

function Get-HPRESTDataRaw
{
<#
.SYNOPSIS
Retrieves data for provided Href.

.DESCRIPTION
Retrieves the HP REST data returned from the source pointed to by the Href in PSObject format.
This cmdlet uses the session information to connect to the REST data source and retrieves the data to the user in PSObject format. Session object with ‘RootUri’, ‘X-Auth-Token’ and ‘Location’ information of the session must be provided for using sessions to retrieve data.

.PARAMETER Href
Specifies the value of href of REST source to be retrieved. This is concatenated with the root URI (obtained from session parameter) to get the URI to send the WebRequest to.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.NOTES
Paging in the REST data is automatically handled by this cmdlet. You will not be able to retrieve individual pages when using this cmdlet.

.INPUTS
System.String
You can pipe the Href parameter to Get-HPRESTDataRaw.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTDataRaw returns a PSCustomObject that has the retrieved data.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $sys = Get-HPRESTDataRaw -Href rest/v1/systems/1 -Session $s

PS C:\> $sys


AssetTag         : 
AvailableActions : {@{Action=Reset; Capabilities=System.Object[]}}
Bios             : @{Current=}
Boot             : @{BootSourceOverrideEnabled=Disabled; BootSourceOverrideSupported=System.Object[]; BootSourceOverrideTarget=None; UefiTargetBootSourceOverride=None; UefiTargetBootSourceOverrideSupported=System.Object[]}
Description      : Computer System View
HostCorrelation  : @{HostMACAddress=System.Object[]; HostName=; IPAddress=System.Object[]}
IndicatorLED     : Off
Manufacturer     : HP
Memory           : @{Status=; TotalSystemMemoryGB=8}
Model            : ProLiant DL380 Gen9
Name             : Computer System
Oem              : @{Hp=}
Power            : On
Processors       : @{Count=2; ProcessorFamily=Intel(R) Xeon(R) CPU E5-2683 v3 @ 2.00GHz; Status=}
SKU              : 501101-001
SerialNumber     : LCHAS01RJ5Y00Z
Status           : @{Health=Warning; State=Enabled}
SystemType       : Physical
Type             : ComputerSystem.0.9.7
UUID             : 31313035-3130-434C-4841-533031524A35
links            : @{Chassis=System.Object[]; Logs=; ManagedBy=System.Object[]; self=}

This example retrieves system data.

.EXAMPLE

PS C:\> $sessions = Get-HPRESTDataRaw -Href 'rest/v1/Sessions' -Session $session
        foreach($ses in $sessions.Items)
        {
            if($ses.Oem.Hp.MySession -eq $true)
            {
                $ses
                $ses.oem.hp
            }
        }



Description : Manager User Session
Name        : User Session
Oem         : @{Hp=}
Type        : Session.0.9.5
UserName    : admin
links       : @{self=}

AccessTime            : 2014-10-30T18:56:31Z
LoginTime             : 2014-10-30T18:56:30Z
MySession             : True
Privileges            : @{LoginPriv=True; RemoteConsolePriv=True; 
                        UserConfigPriv=True; VirtualMediaPriv=True; 
                        VirtualPowerAndResetPriv=True; iLOConfigPriv=True}
Type                  : HpiLOSession.0.9.5
UserAccount           : admin
UserDistinguishedName : 
UserExpires           : 2014-10-30T19:01:31Z
UserIP                : 
UserTag               : Web UI
UserType              : Local

This example shows the process to retrieve current user session.


.EXAMPLE
PS C:\> $biosData = Get-HPRESTDataRaw -Href 'rest/v1/registries' -Session $session
        foreach($reg in $registries.items)
        {
            if($reg.Schema -eq $biosAttReg)
            {
                $attRegLoc = $reg.Location|Where-Object{$_.Language -eq 'en'}|%{$_.uri.extref}
                break
            }
        }
        $attReg = Get-HPRESTDataRaw -Href $attRegLoc -Session $session
        $attReg.RegistryEntries.Dependencies


The example shows retrieval of Dependencies of BIOS settings. The BIOS attribute registry value is present in $biosAttReg. The English version of the registry is retrieved.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )
    # $resp is http web response object with headers
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    try
    {
        $resp = Get-HPRESTHttpData -Href $Href -Session $Session
        $rs = $resp.GetResponseStream();
        [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
        $results = ''
        [string]$results = $sr.ReadToEnd();
        $resp.Close()
        $rs.Close()
        $sr.Close()
        $finalResult = Convert-JsonToPSObject -JsonString $results 
        Merge-HPRESTPage -FinalObj $finalResult -ThisPage $finalResult -Session $Session
    }
    finally
    {
        if ($resp -ne $null -and $resp -is [System.IDisposable]){$resp.Dispose()}
        if ($rs -ne $null -and $rs -is [System.IDisposable]){$rs.Dispose()}
        if ($sr -ne $null -and $sr -is [System.IDisposable]){$sr.Dispose()}
    }

   return $finalResult
}

function Get-HPRESTDir
{
<#
.SYNOPSIS
Gets HP REST data and stores into a node array.

.DESCRIPTION
Get-HPRESTDir cmdlet gets the data at location specified by the href parameter and stores it in a node array. If Recurse parameter is set, the cmdlet will iterate to every href stored within the first node and every node there after storing each node into a node array.

.PARAMETER Href
Specifies the value of href of REST source to be retrieved. This is concatenated with the root URI (obtained from session parameter) to get the URI to retrieve the REST data.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER Recurse
Switch parameter that turns recursion on if true.

.INPUTS
System.String
You can pipe the Href to Get-HPRESTDir.

.OUTPUTS
System.Object[]
Get-HPRESTDir returns an array of PSObject objects that contains the data at the location specified by the Href parameter and by hrefs in that data if Recurse parameter is set to true.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.Example
PS C:\windows\system32> $NodeArray = Get-HPRESTDir -Session $s -Href $href 

PS C:\windows\system32> $NodeArray 


Description : Manager User Sessions
Items       : {@{Description=Manager User Session; Name=User Session; Oem=; Type=Session.0.9.5; UserName=admin; links=}, @{Description=Manager User Session; Name=User Session; Oem=; 
              Type=Session.0.9.5; UserName=admin; links=}}
MemberType  : Session.0
Name        : Sessions
Oem         : @{Hp=}
Total       : 2
Type        : Collection.0.9.5
links       : @{Member=System.Object[]; self=}

This example shows the basic execution where there is no recursion. Only the data at the specified Href is returned.

.Example
PS C:\windows\system32> $NodeArray = Get-HPRESTDir -Session $s -Href $href -Recurse

PS C:\windows\system32> $NodeArray


Description : Manager User Sessions
Items       : {@{Description=Manager User Session; Name=User Session; Oem=; Type=Session.0.9.5; UserName=admin; links=}, @{Description=Manager User Session; Name=User Session; Oem=; 
              Type=Session.0.9.5; UserName=admin; links=}}
MemberType  : Session.0
Name        : Sessions
Oem         : @{Hp=}
Total       : 2
Type        : Collection.0.9.5
links       : @{Member=System.Object[]; self=}

Description : Manager User Session
Name        : User Session
Oem         : @{Hp=}
Type        : Session.0.9.5
UserName    : admin
links       : @{self=}

Description : Manager User Session
Name        : User Session
Oem         : @{Hp=}
Type        : Session.0.9.5
UserName    : admin
links       : @{self=}


This example shows a recursive execution of the cmdlet with the specified Recurse parameter. The second and the third PSObjects shown above are retrieved recursively using the Href from the 'links' property in each object under the 'Items' property in the first object.


.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [Switch]
        [parameter(Mandatory=$false)]
        $Recurse
    )
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    
    $global:SeenHrefs = [System.Collections.ArrayList]@() #The hrefs of the already visited nodes.
    $global:NodeArr = @() #The Array of nodes to be returned.
    function Find-Hrefs($node) #This function finds all the hrefs in a node recursively and adds them to the $SeenHrefs cmdlet, 
    {                          #adds the new node to the node array, and uses the new node to call the function again.
    
        $node | Get-Member -type NoteProperty | foreach {
            $name = $_.Name ;
            $value = $node."$($_.Name)"
            if($name -eq "href")
            {
                foreach($v in $value)
                {
                    if($Global:SeenHrefs -notcontains $v -and $v -ne $null)
                    {
                        try
                        {   
                            $newnode = Get-HPRESTDataRaw -Href $v -Session $Session
                        }
                        catch
                        {
                            Write-Error "$v`n$_"
                        }
                        $global:SeenHrefs += $v 
                        $global:NodeArr += $newnode
                        if($recurse -eq $true)
                        {
                            Find-Hrefs $newnode
                        
                        }
                    }
                }

            }

            elseif($value -ne $null -and ($value |gm).MemberType -contains "NoteProperty")
            {
                Find-Hrefs -node $value
            }
        }
    }


    if($recurse -ne $true)
    {
        try
        {
            $newnode = Get-HPRESTDataRaw -Href $href -Session $Session
        }
        catch
        {
            Write-Error "$href`n$_"
        }
        $global:NodeArr+=$newnode
    }
    else
    {

        try
        {
            $newnode = Get-HPRESTDataRaw -Href $href -Session $Session
        }
        catch
        {
            Write-Error "$href`n$_"
        }
        $global:SeenHrefs += $href 
        $global:NodeArr += $newnode
        Find-Hrefs $newnode
    }
    $ret = $global:NodeArr
    return $ret
}

function Get-HPRESTError
{
<#
.SYNOPSIS
Retrieves error message details.

.DESCRIPTION
This cmdlet retrieves error details of the API response messages specified by the MessageID parameter. This error message may be informational or warning message and not necessarily an error. The possible error messages are specified in the Data Model Reference document. These messages are obtained as returned objects by executing cmdlets like Set-HPRESTData, Edit-HPRESTData etc.

.PARAMETER MessageID
API response message object returned by executing cmdlets like Set-HPRESTData and Edit-HPRESTData.

.PARAMETER MessageArg
API response message arguments returned in the message from cmdlets like Set-HPRESTData, Edit-HPRESTData, etc. The MessageArg parameter has an array of arguments that provides parameter names and/or values relevant to the error/messages returned from cmdlet execution.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.INPUTS
System.String
You can pipe the MessageID parameter to Get-HPRESTError.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTError returns a PSCustomObject that has the error details with Description, Mesage, Severity, Number of arguments to the message, parameter types and the resolution.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $setting = @{'AdminName' = 'TestAdmin'}
PS C:\> $ret = Set-HPRESTData -Href rest/v1/systems/1/bios/settings -Setting $setting -Session $s
PS C:\> $ret

Messages                    Name                        Type                       
--------                    ----                        ----                       
{@{MessageID=iLO.0.10.Sy... Extended Error Information  ExtendedError.0.9.6        



PS C:\> $ret.Messages

MessageID                                                                          
---------                                                                          
iLO.0.10.SystemResetRequired                                                       



PS C:\> $status = Get-HPRESTError -MessageID $ret.Messages[0].MessageID -Session $s
PS C:\> $status


Description  : The system properties were correctly changed, but will not take effect until the system is reset.
Message      : One or more properties were changed and will not take effect until system is reset.
Severity     : Warning
NumberOfArgs : 0
ParamTypes   : {}
Resolution   : Reset system for the settings to take effect.


In this example, when a BIOS setting(AdminName) is updated, an object is returned with messageID  iLO.0.10.SystemResetRequired. When this message ID is passed to Get-HPRESTError, details of this message/error are returned.


.EXAMPLE
PS C:\> $tempBoot = @{'BootSourceOverrideTarget'='test'}
    $OneTimeBoot = @{'Boot'=$tempBoot}
PS C:\> $ret = Set-HPRESTData -Href rest/v1/systems/1 -Setting $OneTimeBoot -Session $s
PS C:\> $ret|fl


Messages : {@{MessageArgs=System.Object[]; MessageID=Base.0.0.PropertyValueNotInList}}
Name     : Extended Error Information
Type     : ExtendedError.0.9.5


PS C:\> $ret.Messages

MessageArgs                                     MessageID                                     
-----------                                     ---------                                     
{test, BootSourceOverrideTarget}                Base.0.0.PropertyValueNotInList  


PS C:\> $status = Get-HPRESTError -MessageArgs $ret.Messages[0].MessageArgs -MessageID $ret.Messages[0].MessageID -Session $s
PS C:\> $status


Description  : The value type is correct, but the value is not supported.
Message      : The value test for the property BootSourceOverrideTarget is not valid.
Severity     : Warning
NumberOfArgs : 2
ParamTypes   : {String, String}
Resolution   : If the operation did not complete, choose a value from the enumeration list and 
               resubmit your request.


In this example, when an invalid value is set as temporary boot device, an object is returned with messageID  Base.0.0.PropertyValueNotInList. When this message ID is passed to Get-HPRESTError along with the message arguments, details of this message/error are returned.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $MessageID,

        [System.Object]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $MessageArg,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )

    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    
    $regs = Get-HPRESTDataRaw -Href 'rest/v1/registries' -Session $session
    $location = ''
    $errorname = ''
    foreach($item in $regs.Items)
    {
        if(($MessageID.Split('.'))[0] -eq $item.Schema.Split('.')[0] )
        {
            $location = ($item.Location | Where-Object{$_.Language -eq 'en'}).uri.extref
            $split = $MessageID.Split('.')
            $errorname = $split[$split.Length-1]
            break
        }
    }
    $registry = Get-HPRESTDataRaw -Href $location -Session $session
    if(-not($registry.Messages.$errorname -eq '' -or $registry.Messages.$errorname -eq $null))
    {
        $errDetail = $registry.Messages.$errorname
        $msg = $errDetail.Message
        $newMsg = Set-Message -Message $msg -MessageArg $MessageArg
        $errDetail.Message = $newMsg
        return $errDetail
    }
    return $null
}

function Get-HPRESTHttpData
{
<#
.SYNOPSIS
Retrieves HTTP data for provided Href.

.DESCRIPTION
Retrieves the HTTP web response with the REST data returned from the source pointed to by the Href in PSObject format.
This cmdlet uses the session information to connect to the REST data source and retrieves the webresponse which has the headers from which 'Allow' methods can be found. These can be GET, POST, PATCH, PUT, DELETE. Session object with ‘RootUri’, ‘X-Auth-Token’ and ‘Location’ information of the session must be provided for using sessions to retrieve data.


.PARAMETER Href
Specifies the value of href of REST source to be retrieved. This is concatenated with the root URI (obtained from session parameter) to get the URI to send the WebRequest to.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.INPUTS
System.String
You can pipe the Href parameter to Get-HPRESTHttpData.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTHttpData returns a PSCustomObject that has the retrieved HTTP data.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $httpSys = Get-HPRESTHttpData -Href rest/v1/systems/1 -Session $s

PS C:\> $httpSys


IsMutuallyAuthenticated : False
Cookies                 : {}
Headers                 : {Allow, Connection, X_HP-CHRP-Service-Version, Content-Length...}
SupportsHeaders         : True
ContentLength           : 2920
ContentEncoding         : 
ContentType             : application/json
CharacterSet            : 
Server                  : HP-iLO-Server/1.30
LastModified            : 5/27/2015 11:04:47 AM
StatusCode              : OK
StatusDescription       : OK
ProtocolVersion         : 1.1
ResponseUri             : https://192.184.217.212/rest/v1/systems/1
Method                  : GET
IsFromCache             : False



PS C:\> $httpSys.Headers['Allow']
GET, HEAD, POST, PATCH

PS C:\> $httpSys.Headers['Connection']
keep-alive

The example shows HTTP details returned and the 'Allow' and 'Connection' header values

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )

    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $wr = $null
    $httpWebRequest = $null

    $uri = Get-HPRESTUriFromHref -Session $Session -Href $href
    $split = $uri.Split('//')
    $sessHost = $split[2]
    $Method = 'GET'
    
    if($uri.substring($uri.length -1) -eq "/")
    {
        $uri = $uri.substring(0,$uri.length-2)
    }
    $wr = [System.Net.WebRequest]::Create($uri)
    $httpWebRequest = [System.Net.HttpWebRequest]$wr
    $httpWebRequest.Method = $Method
    $httpWebRequest.ContentType = 'application/json'
    $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]'GZip'
    $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
    $resp = $null
    try
    {
        [System.Net.WebResponse] $resp = $httpWebRequest.GetResponse()
        return $resp
    }
    catch
    {
        $webResponse = $_.Exception.InnerException.Response
        $errorRecord = Get-ErrorRecord -WebResponse $webResponse -CmdletName 'Get-HPRESTHttpData'
        $Global:Error.RemoveAt(0)
        throw $errorRecord
        #Write-Error -Message $msg -Category $_.CategoryInfo.Category -CategoryReason $_.CategoryInfo.CategoryReason
    }
}

function Get-HPRESTIndex
{ 
<#
.SYNOPSIS
Gets an index of HP REST API data.

.DESCRIPTION
Using a passed in REST API session, the cmdlet recursively traverses the REST API tree and indexes everything that is found. Using the switch parameters, the user can customize what gets indexed. The returned index is a set of key-value pairs where the keys are the terms in the HP REST data source and the values are list of occurances of the term and details of the term like Property name or value where the term is found, the hrefs to access the data item and its schema, etc.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.PARAMETER DateAndTime
Switch value that causes the iLO Data and Time node to be indexed when true.

.PARAMETER ExtRef
Switch value that causes external refrences to be indexed when true.

.PARAMETER Schema
Switch value that causes Schemas to be in indexed when  true.

.PARAMETER Log
Switch value that causes IML and IEL logs to be indexed when true.

.INPUTS
System.Management.Automation.PSCustomObject
You can pipe Session object obtained by executing Connect-HPREST cmdlet to Get-HPRESTIndex

.OUTPUTS
System.Collections.SortedList
Get-HPRESTIndex returns a sorted list of key-value pairs which is the index. The keys are terms in the HP REST source and values are details of keys like Porperty name and value where the key is found, href to access the key and the schema href for the property.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $index = Get-HPRESTIndex -Session $s

PS C:\> $index.Keys -match "power"
AllocatedPowerWatts
AutoPowerOn
AveragePowerOutputWatts
BalancedPowerPerf
CollabPowerControl
DynamicPowerResponse
DynamicPowerSavings
FastPowerMeter
HpPowerMeter
HpPowerMetricsExt
HpServerPowerSupply
LastPowerOutputWatts
MaxPowerOutputWatts
MinProcIdlePower
MixedPowerSupplyReporting
OldPowerOnPassword
Power
PowerAllocationLimit
PowerandResetPriv
PowerAutoOn
PowerButton
PowerCapacityWatts
PowerConsumedWatts
PowerMeter
PowerMetrics
PowerOnDelay
PowerOnLogo
PowerOnPassword
PowerProfile
PowerRegulator
PowerRegulatorMode
PowerRegulatorModesSupported
PowerSupplies
PowerSupplyStatus
PowerSupplyType
PushPowerButton
VirtualPowerAndResetPriv

PS C:\> $index.PowerMeter


PropertyName : PowerMeter
Value        : @{href=/rest/v1/Chassis/1/PowerMetrics/PowerMeter}
DataHref     : /rest/v1/Chassis/1/PowerMetrics
SchemaHref   : /rest/v1/SchemaStore/en/HpPowerMetricsExt.json
Tag          : PropertyName

PropertyName : href
Value        : /rest/v1/Chassis/1/PowerMetrics/PowerMeter
DataHref     : /rest/v1/Chassis/1/PowerMetrics
SchemaHref   : /rest/v1/SchemaStore/en/HpPowerMetricsExt.json
Tag          : Value

PropertyName : href
Value        : /rest/v1/Chassis/1/PowerMetrics/PowerMeter
DataHref     : /rest/v1/ResourceDirectory
SchemaHref   : /rest/v1/SchemaStore/en/HpiLODateTime.json
Tag          : Value

This example shows how to create and use the index on an HP REST data source. First, the index is created using Get-HPRESTIndex cmdlets and store the created index. The index stores key-value pairs for the entire data source. The term "power" is searched in the keys of the index and it returns all the keys which has "power" as substring. When a specific key "PowerMeter" is seleted, the list of values is displayed where PowerMeter was encountered in the HP REST data.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [Switch]
        [parameter(Mandatory=$false)]
        $DateAndTime,

        [Switch]
        [parameter(Mandatory=$false)]
        $ExtRef,

        [Switch]
        [parameter(Mandatory=$false)]
        $Schema,

        [Switch]
        [parameter(Mandatory=$false)]
        $Log
    )
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    
    $Global:SeenHrefs = [System.Collections.ArrayList]@() #The hrefs of the already visited nodes.

    $Global:SeenSchemaTypes = [System.Collections.ArrayList]@() #The hrefs of the already visited nodes.

    $KeyValueIndex= New-Object System.Collections.SortedList
    
    $SchemaIgnoreList = @("object", "string", "BaseNetworkAdapter.0.9.5", "Type.json#", "array", "integer", "null", "number", "boolean", "map")

    $Seperator = @(" ", "!", "`"", "#", "$", "%", "&", "``", "(", ")", "*", "'","+", "-", ".", "/", ":", ";", "<", "=", ">", "?", "@", "[", "\", "]", "^", "_", "~", "{", "|", "}")

    $IgnoreList = @("a", "A", "and", "any", "are", "as", "at", "be", "been", "for", "from", "has", "have", "if", "in", "is", "or", "the", "The", "this", "This", "to", "was", "when", "which", "will")

    $PropertyNameIgnoreList = @("Created", "Type", "action", "UUID", "Updated", "updated")

    $hrefIgnoreList = @()

    $TraverseRefs = @("href")

    if($DateAndTime -ne $true)
    {
        $hrefIgnoreList += "/rest/v1/Managers/1/DateTime"
    }

    if($ExtRefToggle -eq $true)
    {
        $TraverseRefs += "extref"
    }

    if($LogToggle -ne $true)
    {
        $hrefIgnoreList += "/rest/v1/Managers/1/Logs/IEL/Entries"
        $hrefIgnoreList += "/rest/v1/Systems/1/Logs/IML/Entries"
    }

    

    

    function Step-ThroughNoteProperties($node, $Dhref, $SchemaHref, $s, $SchemaNode)
    {
        if($node.Type -ne $null)
        {
            $NodeType = $node.type
            foreach($SchemaType in $NodeType)
            {
                if($SchemaType.'$ref' -ne $null)
                {
                    $SchemaType = $SchemaType.'$ref'
                } 
                if($SchemaType -ne $null -and $SchemaIgnoreList -notcontains $SchemaType -and $Global:SeenSchemaTypes -notcontains $SchemaType)
                {
                    $Global:SeenSchemaTypes += $SchemaType
                    try
                    {
                        $SchemaHref = Get-HPRESTSchemaExtref -Type $SchemaType -Session $s
                    }
                    catch
                    {
                        write-error "No Schema for: $SchemaType"
                    }
                    
                    if($SchemaToggle -and $Global:SeenHrefs -notcontains $SchemaHref)
                    {
                        $Global:SeenHrefs+= $SchemaHref
                        try
                        {
                            $SchemaNode = Get-HPRESTDataRaw -Href $SchemaHref -Session $s
                        }
                        catch
                        {
                            Write-Error "No HP REST API data at $SchemaHref"
                        }
                        Step-ThroughNoteProperties -node $SchemaNode -Dhref $SchemaHref -s $s
                    }
                }
            }
        }
        $node | get-member -type NoteProperty | foreach-object { #Displays all the note properties within the node.
            if($true)#$PropertyNameIgnoreList -notcontains $_.Name)
            {
                $name=$_.Name ;
                $temp = $node.$name
            
                $Information = New-Object PSObject
                    $Information | Add-Member -type NoteProperty -Name PropertyName -Value $name
                    $Information | Add-Member -type NoteProperty -Name Value -Value $temp
                    $Information | Add-Member -type NoteProperty -Name DataHref -Value $DHref
                    $Information | Add-Member -type NoteProperty -Name SchemaHref -Value $SchemaHref
                    $Information | Add-Member -type NoteProperty -Name Tag -Value "PropertyName"
                    Limit-Entries -Name $name -Information $information
            
                if($temp -ne $null -and $temp -ne "" -and $PropertyNameIgnoreList -notcontains $name)
                {
                    if(($temp | gm).MemberType -contains "NoteProperty") 
                    {
                        Step-ThroughNoteProperties -node $temp -Dhref $Dhref -SchemaHref $SchemaHref -s $s -SchemaNode $SchemaNode
                
                    }
                    elseif(($temp.Count) -gt 1)
                    {
                        foreach($t in $temp)
                        {
                            if($t -ne $null -and ($t | gm).MemberType -contains "NoteProperty") 
                            {
                                Step-ThroughNoteProperties -node $t -Dhref $Dhref -SchemaHref $SchemaHref -s $s -SchemaNode $SchemaNode
            
                            }
                            else
                            {
                                Split-Value -DHref $Dhref -SchemaHref $SchemaHref -node $node -Value $t -name $name
                            }
                    }
                    }
                    else
                    {
                        Split-Value -DHref $Dhref -SchemaHref $SchemaHref -node $node -Value $temp -name $name
                    }
            
                    if($TraverseRefs -contains $name)
                    {
                        
                
                        foreach($t in $temp)
                        {
                            if($Global:SeenHrefs -notcontains $t -and $hrefIgnoreList -notcontains $t -and (Confirm-Href $t))
                            {
                                $Global:SeenHrefs += $t
                                $NewNode = Get-HPRESTDataRaw -Href $t -Session $s
                                if($NewNode -ne $null)
                                {
                                    Step-ThroughNoteProperties -node $NewNode -Dhref $t -SchemaHref $SchemaHref -s $s -SchemaNode $SchemaNode
                                }
                            }        
                        }
                       

                    
                    }
                }
            }
        }
    }

    function Confirm-Href($value)
    {
        if($value -match "/rest/v1")
        {
            return $true
        }
        else
        {
            return $false
        }
    }

    function Confirm-isNumeric ($value) 
    {
        $x = 0
        $isNum = [System.Int32]::TryParse($value, [ref]$x)
        return $isNum
    }

    function Limit-Entries($Name, $Information)
    {
        $PassedRules = $true

        if(Confirm-isNumeric $name)
        {
            $PassedRules = $false
        }
        elseif($name -eq "" -or $Information -eq $null)
        {
            $PassedRules = $false
        }
        elseif($IgnoreList -ccontains $name)
        {
            $PassedRules = $false
        }
        if($PassedRules)
        {
            Add-KeyValueIndex $Name $Information
        }
    }

    function Add-KeyValueIndex($Name, $Information)
    {
        if($KeyValueIndex.Contains($Name))
        {
            $KeyValueIndex.$Name += $Information
        }
        else
        {
            $ray = @()
            $KeyValueIndex.Add($Name, $ray)
            $KeyValueIndex.$Name += $Information
        }
    }

    function Split-Value($DHref, $SchemaHref, $node, $Value, $name)
    {
        $Information = New-Object PSObject
        $Information | Add-Member -type NoteProperty -Name PropertyName -Value $name
        $Information | Add-Member -type NoteProperty -Name Value -Value $value
        $Information | Add-Member -type NoteProperty -Name DataHref -Value $DHref
        $Information | Add-Member -type NoteProperty -Name SchemaHref -Value $SchemaHref
        $Information | Add-Member -type NoteProperty -Name Tag -Value "Value"

        $value = $value -replace '[ -/]+', " "
        $value = $value -replace '[:-@]+', " "
        $value = $value -replace '[[-``]+', " "
        $value = $value -replace '[{-~]+', " "

        if($value -ne $null -and $value -ne "")
        {
            $StringValue = $Value.toString
            $SplitValue = $Value.Split(" ")
            foreach($word in $SplitValue)
            {
                if($IgnoreList -notcontains $word)
                {
                    
                    Limit-Entries -Name $word -Information $information
                }
            }
        }
    }

    $links = $Session.RootData.links
    
    
        $links | get-member -type NoteProperty | foreach-object {
            $name=$_.Name ; 
            $href=$links."$($_.Name)"
            $href = $href.href
            if($Global:SeenHrefs -notcontains $href)
            {
                $Global:SeenHrefs += $href
                if($name -ne "Self" -or $true)
                {
                    try
                    {
                        $node = Get-HPRESTDataRaw -Href $href -Session $Session
                    }
                    catch
                    {
                        write-error "No HP REST API data at: $href"
                    }

                    Step-ThroughNoteProperties -node $node -Dhref $href -s $Session
                }
            }
        }

    return $KeyValueIndex
}

function Get-HPRESTModuleVersion{
<#
.SYNOPSIS
Gets the module details for the HPRESTCmdlets module.

.DESCRIPTION
The Get-HPRESTModuleVersion cmdlet gets the module details for the HPRESTCmdlets module. The details include name of file, path, description, GUID, version, and supported UICultures with respective version.
    
.INPUTS

.OUTPUTS
System.Management.Automation.PSCustomObject
    
    Get-HPRESTmoduleVersion retuns a System.Management.Automation.PSCustomObject object.

.EXAMPLE
Get-HPRESTModuleVersion 

Name                    : HPRESTCmdlets
Path                    : C:\Poseidon_SVN\HPREST\HPRESTCmdlets\HPRESTCmdlets.psm1
Description             : HP REST PowerShell cmdlets create an interface to HP REST devices such as iLO and 
                          Moonshot iLO CM. 
                          These cmdlets can be used to get and set HP REST data and to invoke actions on 
                          these devices and the systems they manage
                          There are also advanced functions that can create an index or directory of HP REST 
                          data sources. A file with examples called HPRESTExamples.ps1 is included in this 
                          release. 
GUID                    : 2f9b1ca0-2031-45c0-9d82-a432014abfdf
Version                 : 1.0.0.2
CurrentUICultureName    : en-US
CurrentUICultureVersion : 1.0.0.2
AvailableUICulture      : @{UICultureName=en-US; UICultureVersion=1.0.0.2}


This example shows the cmdlets module details.

.LINK
http://www.hp.com/go/powershell

#>
    [CmdletBinding(PositionalBinding=$false)]
    param() # no parameters
    $mod = Get-Module | ? {$_.Name -eq "HPRESTCmdlets"}
    $cul = Get-UICulture
    $versionObject = New-Object PSObject
    $versionObject | Add-member "Name" $mod.Name
    $versionObject | Add-member "Path" $mod.Path
    $versionObject | Add-member "Description" $mod.Description
    $versionObject | Add-member "GUID" $mod.GUID
    $versionObject | Add-member "Version" $mod.Version
    $versionObject | Add-member "CurrentUICultureName" $cul.Name
    $versionObject | Add-member "CurrentUICultureVersion" $mod.Version
    
    $UICulture = New-Object PSObject
    $UICulture | Add-Member 'UICultureName' 'en-US'
    $UICulture | Add-Member 'UICultureVersion' $mod.Version
    $AvailableUICulture += $UICulture
          
    $versionObject | Add-Member "AvailableUICulture" $AvailableUICulture

    return $versionObject
}

function Get-HPRESTSchema
{
<#
.SYNOPSIS
Retrieve schema for the specified Type.

.DESCRIPTION
Retrieves the schema for the specified Type of REST data. The cmdlet first gets the JSON link of the schema and then gets the data from the schema store that has the schema.

.PARAMETER Type
Value of the Type field obtained from the data for which schema is to be found.

.PARAMETER Language
The language code of the schema to be retrieved. The default value is 'en'. The allowed values depend on the languages available on the system.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.INPUTS
System.String
You can pipe the Type parameter to Get-HPRESTSchema.

.OUTPUTS
System.Management.Automation.PSCustomObject
Get-HPRESTSchema returns a PSCustomObject that has the retrieved schema of the specified type.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $sch = Get-HPRESTSchema -Type ComputerSystem.0.9.7 -Session $s

PS C:\> $sch


$schema              : http://json-schema.org/draft-04/schema#
title                : ComputerSystem.0.9.7
type                 : object
readonly             : False
additionalProperties : False
description          : The schema definition of a computer system and its properties. A computer system represents a physical or virtual machine and the local resources, such as memory, CPU, and other devices that can be accessed from that machine.
properties           : @{Oem=; Name=; Modified=; Type=; SystemType=; links=; AssetTag=; Manufacturer=; Model=; SKU=; SerialNumber=; Version=; PartNumber=; Description=; VirtualSerialNumber=; UUID=; HostCorrelation=; Status=; BIOSPOSTCode=; IndicatorLED=; Power=; Boot=; Bios=; Processors=; Memory=; AvailableActions=}
required             : {Name, Type}
actions              : @{description=The POST custom actions defined for this type (the implemented actions might be a subset of these).; actions=}


PS C:\> $sch.properties


Oem                 : @{type=object; readonly=False; additionalProperties=True; properties=}
Name                : @{$ref=Name.json#}
Modified            : @{$ref=Modified.json#}
Type                : @{$ref=Type.json#}
SystemType          : @{type=string; description=The type of computer system that this resource represents.; enum=System.Object[]; enumDescriptions=; readonly=True; etag=True}
links               : @{type=object; additionalProperties=True; properties=; readonly=True; description=The links array contains the related resource URIs.}
    .
    .
    .
AssetTag            : @{type=System.Object[]; description=A user-definable tag that is used to track this system for inventory or other client purposes.; readonly=False; etag=True}
IndicatorLED        : @{type=System.Object[]; description=The state of the indicator LED.; enum=System.Object[]; enumDescriptions=; readonly=False; etag=True}
AvailableActions    : @{type=array; readonly=True; additionalItems=False; uniqueItems=True; items=}


PS C:\> $sch.properties.IndicatorLED


type             : {string, null}
description      : The state of the indicator LED.
enum             : {Unknown, Lit, Blinking, Off}
enumDescriptions : @{Unknown=The state of the Indicator LED cannot be determined.; Lit=The Indicator LED is lit.; Blinking=The Indicator LED is blinking.; Off=The Indicator LED is off.}
readonly         : False
etag             : True

This example shows schema of type ComputerSystem.0.9.7

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Type,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Language = 'en'

    )
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }

    $schemaJSONhref = Get-HPRESTSchemaExtref -type $Type -Session $Session -Language $Language
    if($schemaJSONhref -ne $null)
    {
        $schema = Get-HPRESTDataRaw -Href $schemaJSONhref -Session $Session
    }
    
    return $schema
}

function Get-HPRESTSchemaExtref
{
<#
.SYNOPSIS
Retrieves the uri of the JSON file that contains the schema for the specified type.

.DESCRIPTION
Schema JSON file is pointed to by a uri. This link is retrieved from the external reference (extref) in Location field of the Type in rest/v1/schemas. This is uri of the JSON file that contains the schema for the specified type. This cmdlet retrieves this URI that points to the JSON schema file.

.PARAMETER Type
Type value of the data for which schema JSON file link has to be retrieved. The Type value is present in the REST data.

.PARAMETER Language
The language code of the schema for which the JSON URI is to be retrieved. The default value is 'en'. The allowed values depend on the languages available on the system.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI and X-Auth-Token for executing this cmdlet.

.INPUTS
System.String
You can pipe the Type parameter to Get-HPRESTSchemaExtref.

.OUTPUTS
System.String
Get-HPRESTSchemaExtref returns a String that has the Extref of the schema specified by the Type parameter.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> $schemaJSONhref = Get-HPRESTSchemaExtref -type ComputerSystem.0.9.7 -Session $s
    

PS C:\> $schemaJSONhref
/rest/v1/SchemaStore/en/ComputerSystem.json


This example shows that the schema for ComputerSystem.0.9.7 is stored at the external reference /rest/v1/SchemaStore/en/ComputerSystem.json. The schema is retrieved using this as value of 'Href' parameter for Get-HPRESTData or Get-HPRESTDataRaw and navigate to the 'Properties' field.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Type,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session,

        [System.String]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Language = 'en'
    )

    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    
    if(-not($Type -eq $null -or $Type -eq ''))
    {
        $rootURI = $Session.RootUri
        $schemaURIList = 'rest/v1/schemas'
        $data = $null
        $data = Get-HPRESTDataRaw -Session $Session -Href $schemaURIList
        $hreflist = $data.links.member.href

        $neededHref = ''
        $foundFlag = $false
        $schemaHref = ''
        $prefix = $Type
        $schemaJSONLink = ''

<#
    ##code in this comment block is rendered unnecessary due to page handling functionality added in Get-HPRESTDataRaw

   #$return = $false
   if($data.links.PSObject.Properties.Name.Contains('NextPage'))
    {
        if($data.links.NextPage.PSObject.Properties.Name.Contains('page'))
        {
            while($true)
            {
                if($data.links.PSObject.Properties.Name.Contains('NextPage'))
                {
                    if($data.links.NextPage.PSObject.Properties.Name.Contains('page'))
                    {
                          $newPage = $data.links.NextPage.page
                          $link = $data.links.self.href -replace 'page=(\d)*',"page=$newPage"
                          $data = Get-HPRESTDataRaw -Href $link -Session $Session
                          foreach($sch in $data.links.member.href)
                          {
                              $hreflist += $sch
                          }
                    }
                    else
                    {
                        break
                    }
                }
                else
                {
                    break
                }
            }#end while
        }
    }
    #>

        foreach($href in $hreflist)
        {
            $typeFromHref = $href.SubString($href.LastIndexOf('/')+1)
            if($typeFromHref -eq $Type)
                            {
            $schemaHref = $href
            $foundFlag = $true
            break
        }
        }

        if($foundFlag -eq $false)
        {
            $prefix = Get-HPRESTTypePrefix -type $Type
            Write-Verbose "Using prefix - $prefix"
            foreach($href in $hreflist)
            {
                $x = $href.Split('/')
                if($x[$x.length-1] -eq $prefix)
                {
                    $schemaHref = $href
                    $foundFlag = $true
                    break
                }
            }
        }
        if($foundFlag -eq $true)
        {
            $schemaLinkObj = $null
            $schemaLinkObj = Get-HPRESTDataRaw -Href $schemaHref -Session $session
            $x = Compare-HPRESTSchemaVersion -DataType $Type -SchemaType $schemaLinkObj.schema
            if($x -eq $true)
            {
                $schemaJSONHref = ($schemaLinkObj.Location|Where-Object {$_.language -eq $Language} | % {$_.Uri}).extref
            }
            return $schemaJSONHref
        }
        else
        {
            #Write-Error "Schema not found for $type"
            throw $([string]::Format($(Get-Message('MSG_SCHEMA_NOT_FOUND')), $type))
        }
    }
}

function Get-HPRESTUriFromHref
{
<#
.SYNOPSIS
Gets entire URI path from provided Href and root URI in Session variable.

.DESCRIPTION
Gets entire URI path from provided Href and root URI in Session variable.

.PARAMETER Href
Href of data of which completer URI is to be obtained.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter.

.INPUTS
System.String
You can pipe the Href parameter to Get-HPRESTUriFromHref.

.OUTPUTS
System.String
Get-HPRESTUriFromHref returns a string that has the complete URI derived from the Href and the RootUri from the session object.

.NOTES
See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.EXAMPLE
PS C:\> Get-HPRESTUriFromHref -Href rest/v1/systems/1 -Session $s
https://192.184.217.212/rest/v1/systems/1

This example shows the resultant REST URI obtained from the Href provided and the RootURI from the session object.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )

    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    
    $rootURI = $Session.RootUri
    $matchLen = 0
    try
    {
        $split = $Href.Split('/')
        if($split[1] -ieq 'redfish')
        {
            $split[1] = 'rest'
            $Href = ''
            foreach($part in $split)
            {
                $Href = $Href + $part + '/'
            }
            $href = $Href.Substring(0,$href.Length-1)
            #$rootURI = $rootURI -replace 'rest/v1','redfish/v1'
        }
        do {
            $matchLen++
            $a = $rootURI.Substring(($rootURI.Length - $matchLen), $matchLen)
            $b = $Href.Substring(0,$matchLen)
        } while ($a -ne $b)
        $c = $Href.Substring($matchLen)
        return $rootURI + $c
    }
    catch
    {
        throw $(Get-Message('MSG_INVALID_HREF'))
        #throw 'Invalid href'
    }
}

function Invoke-HPRESTAction
{
<#
.SYNOPSIS
Executes HTTP POST method on the destination server.

.DESCRIPTION
Executes HTTP POST method on the desitination server with the data from Data parameter. Used for invoking an action like resetting the server.

.PARAMETER Href
Href where you have to POST the data.

.PARAMETER Data
Data passed in name-value hashtable format that you have to POST.

.Parameter Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter.

.NOTES
- Edit-HPRESTData is for HTTP PUT method
- Invoke-HPRESTAction is for HTTP POST method
- Remove-HPRESTData is for HTTP DELETE method
- Set-HPRESTData is for HTTP PATCH method

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Href to Invoke-HPRESTAction. Href points to the location where the POST method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Invoke-HPRESTAction returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
PS C:\> $dataToPost = @{'Action'='Reset';'ResetType'='ForceRestart'}
PS C:\> Invoke-HPRESTAction -Href $sys -Data $dataToPost -Session $s

Messages                        Name                        Type                       
--------                        ----                        ----                       
{@{MessageID=Base.0.10.Success  Extended Error Information  ExtendedError.0.9.6        

This example shows Invoke-HPRESTData used to invoke a rest on the server. The 'ResetType' property is set to 'ForcedReset' and the output shows that reset was invoked successfully. The details of actions that can be performed at a particular Href are mentioned in the value for 'AvailableActions' field.

.EXAMPLE
$PS C:\> $accData = Get-HPRESTDataRaw -Href 'rest/v1/AccountService' -Session $session
    $accountHref = $accData.links.Accounts.href
    
$PS C:\> $priv = @{}
    $priv.Add('RemoteConsolePriv',$true)
    $priv.Add('iLOConfigPriv',$true)
    $priv.Add('VirtualMediaPriv',$false)
    $priv.Add('UserConfigPriv',$false)
    $priv.Add('VirtualPowerAndResetPriv',$true)

$PS C:\> $hp = @{}
    $hp.Add('LoginName',$newiLOLoginName)
    $hp.Add('Privileges',$priv)
    
$PS C:\> $oem = @{}
    $oem.Add('Hp',$hp)

$PS C:\> $user = @{}
    $user.Add('UserName',$newiLOUserName)
    $user.Add('Password',$newiLOPassword)
    $user.Add('Oem',$oem)

$PS C:\> $ret = Invoke-HPRESTAction -Href $accountHref -Data $user -Session $session

This example creates a user object and adds it to the Account href in AccountService.

.EXAMPLE
PS C:\> $settingToPost = @{}
PS C:\> $settingToPost.Add('Action','Reset')
PS C:\> Invoke-HPRESTAction -Href 'rest/v1/managers/1' -Data $settingToPost -Session $s

Messages                                Name                          Type
--------                                ----                          ----
{@{MessageID=iLO.0.10.ResetInProgress   Extended Error Information    ExtendedError.0.9.6

This example invokes a reset on the iLO for the server.

.EXAMPLE
PS C:\> $action = @{'Action'='ClearLog'}
PS C:\> Invoke-HPRESTAction -Href '/rest/v1/Systems/1/Logs/IML' -Data $action -Session $session

{"Messages":[{"MessageID":"iLO.0.10.EventLogCleared"}],"Name":"Extended Error Information","Type":"ExtendedError.0.9.6"}


This example clears the IML logs by creating a JSON object with action to clear the Integraged Management Logs.

.EXAMPLE
PS C:\> $action = @{'Action'='ClearLog'}
PS C:\> Invoke-HPRESTAction -Href '/rest/v1/Managers/1/Logs/IEL' -Data $action -Session $session

{"Messages":[{"MessageID":"iLO.0.10.EventLogCleared"}],"Name":"Extended Error Information","Type":"ExtendedError.0.9.6"}


This example clears the IML logs by creating a JSON object with action to clear the iLO Event Logs.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.Object]
        [parameter(Mandatory=$false)]
        $Data, #one of the AllowedValue in capabilities

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
  
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    if($Data -eq $null -or $Data -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Data"))
    }
    if($Data.GetType().ToString() -ne "System.Collections.Hashtable")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Data.GetType().ToString() ,"Data"))
    }

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $wr = $null
    $httpWebRequest = $null

    $data = $data|ConvertTo-Json -Depth 10
    $returnObjectFromJSON = New-Object PSObject
    try
    {
        $uri = Get-HPRESTUriFromHref -Href $href -Session $Session
        if($uri.substring($uri.length -1) -eq "/")
        {
            $uri = $uri.substring(0,$uri.length-2)
        }
        $wr = [System.Net.WebRequest]::Create($uri)
        $httpWebRequest = [System.Net.HttpWebRequest]$wr
        $httpWebRequest.Method = 'POST'
        $httpWebRequest.ContentType = 'application/json'
        $httpWebRequest.ContentLength = $data.length
        $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]'GZip'
        $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
        $reqWriter = New-Object System.IO.StreamWriter($httpWebRequest.GetRequestStream(), [System.Text.Encoding]::ASCII)
        $reqWriter.Write($data)
        $reqWriter.Close()

        try
        {
            $webResponse = $httpWebRequest.GetResponse()
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $resp = $respReader.ReadToEnd()
            $returnObjectFromJSON = $resp|Convert-JsonToPSObject

            $webResponse.Close()
            $webStream.Close()
            $respReader.Close()
    
            return $returnObjectFromJSON

        }
        catch
        {
            $webResponse = $_.Exception.InnerException.Response
            $errorRecord = Get-ErrorRecord -WebResponse $webResponse -CmdletName 'Invoke-HPRESTAction'
            $Global:Error.RemoveAt(0)
            throw $errorRecord
            #Write-Error -Message $msg -Category $_.CategoryInfo.Category -CategoryReason $_.CategoryInfo.CategoryReason
        }
    }
    finally
    {
        if ($reqWriter -ne $null -and $reqWriter -is [System.IDisposable]){$reqWriter.Dispose()}
        if ($webResponse -ne $null -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
        if ($webStream -ne $null -and $webStream -is [System.IDisposable]){$webStream.Dispose()}
        if ($respReader -ne $null -and $respReader -is [System.IDisposable]){$respReader.Dispose()}

    }
}

function Remove-HPRESTData
{
<#
.SYNOPSIS
Executes HTTP DELETE method on destination server.

.DESCRIPTION
Executes HTTP DELETE method on the desitination server at the location pointed to by Href parameter. Example of usage of this cmdlet is removing an iLO user account.

.PARAMETER Href
Href of the data which is to be deleted.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter. The root URI of the REST source and the X-Auth-Token session identifier required for executing this cmdlet is obtained from Session parameter.

.NOTES
- Edit-HPRESTData is for HTTP PUT method
- Invoke-HPRESTAction is for HTTP POST method
- Remove-HPRESTData is for HTTP DELETE method
- Set-HPRESTData is for HTTP PATCH method

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Href to Remove-HPRESTData. Href points to the location where the DELETE method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Remove-HPRESTData returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
$users = Get-HPRESTDataRaw -Href rest/v1/accountService/accounts -Session $s
foreach($u in $users.Items)
{
    if($u.Username -eq 'user1')
    {
        Remove-HPRESTData -Href $u.links.self.href -Session $s
        break
    }
}


In this example, first, all accounts are retrieved in $users variable. This list is parsed one by one and when the 'user1' username is found, it is removed from the list of users.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $wr = $null
    $httpWebRequest = $null
    $returnObjectFromJSON = New-Object PSObject

    try
    {
        $uri = Get-HPRESTUriFromHref -Href $href -Session $Session
        if($uri.substring($uri.length -1) -eq "/")
        {
            $uri = $uri.substring(0,$uri.length-2)
        }
        $wr = [System.Net.WebRequest]::Create($uri)
        $httpWebRequest = [System.Net.HttpWebRequest]$wr
        $httpWebRequest.Method = 'DELETE'
        $httpWebRequest.ContentType = 'application/json'
        $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
        $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')
        
        try
        {
            $webResponse = $httpWebRequest.GetResponse();
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $resp = $respReader.ReadToEnd()
            $returnObjectFromJSON = $resp|Convert-JsonToPSObject

            $webResponse.Close()
            $webStream.Close()
            $respReader.Close()
            return $returnObjectFromJSON
        }
        catch
        {
            $webResponse = $_.Exception.InnerException.Response
            $errorRecord = Get-ErrorRecord -WebResponse $webResponse -CmdletName 'Remove-HPRESTData'
            $Global:Error.RemoveAt(0)
            throw $errorRecord
            #Write-Error -Message $msg -Category $_.CategoryInfo.Category -CategoryReason $_.CategoryInfo.CategoryReason
        }
    
    }
    finally
    {
        if ($webResponse -ne $null -and $webResponse -is [System.IDisposable]){$webResponse.Dispose()}
        if ($webStream -ne $null -and $webStream -is [System.IDisposable]){$webStream.Dispose()}
        if ($respReader -ne $null -and $respReader -is [System.IDisposable]){$respReader.Dispose()}
    }
    

}

function Set-HPRESTData
{
<#
.SYNOPSIS
Executes HTTP PATCH method on destination server.

.DESCRIPTION
Executes HTTP PATCH method at the specified Href. This cmdlet is used to update the value of an editable property in the REST source. A property name and the new value must be provided to modify a value. If the Property name is left blank or not specified, then the PATCH is done using the Value parameter on the Href. 

.PARAMETER Href
Href where the property is to be modified.

.PARAMETER Setting
Specifies a hashtable using @{} which has the name of the setting to be modified and the corresponding value. Multiple properties can be modified using the same request by stating multiple name-value pairs in the same hashtable structure.
Example 1: $setting = @{'property1'= 'value1'}
Example 2: $setting = @{'property1'= 'value1'; 'property2'='value2'}
This can also be a complex(nested) hashtable. 
Example: $priv = @{}
          $priv.Add('RemoteConsolePriv',$true)
          $priv.Add('iLOConfigPriv',$true)
          $priv.Add('VirtualMediaPriv',$true)
          $priv.Add('UserConfigPriv',$true)
          $priv.Add('VirtualPowerAndResetPriv',$true)

          $hp = @{}
          $hp.Add('LoginName','user1')
          $hp.Add('Privileges',$priv)
    
          $oem = @{}
          $oem.Add('Hp',$hp)

          $user = @{}
          $user.Add('UserName','adminUser')
          $user.Add('Password','password123')
          $user.Add('Oem',$oem)

This example shows a complex $user object that is used as 'Setting' parameter value to update properties/privileges of a user. This is passed to the Href of the user whose details are to be updated.

.PARAMETER Session
Session PSObject returned by executing Connect-HPREST cmdlet. It must have RootURI to create the complete URI along with the Href parameter. The root URI of the REST source and the X-Auth-Token session identifier required for executing this cmdlet is obtained from Session parameter.

.NOTES
- Edit-HPRESTData is for HTTP PUT method
- Invoke-HPRESTAction is for HTTP POST method
- Remove-HPRESTData is for HTTP DELETE method
- Set-HPRESTData is for HTTP PATCH method

If user tries to PATCH data to an Href that does not allow PATCH operation, then the code automatically searches for 'Settings' href in the 'links' field and performs a PATCH operation on the 'Settings' href. If 'Settings' href is not found in 'links' field of the data and PATCH is not allowed on the provided href, it results in an error.

See typical usage examples in the HPRESTExamples.ps1 file installed with this module.

.INPUTS
System.String
You can pipe the Href to Set-HPRESTData. Href points to the location where the PATCH method is to be executed.

.OUTPUTS
System.Management.Automation.PSCustomObject
Set-HPRESTData returns a PSObject that has message from the HTTP response. The response may be informational or may have a message requiring an action like server reset.

.EXAMPLE
PS C:\> $setting = @{'AdminName' = 'TestAdmin'}
PS C:\> $ret = Set-HPRESTData -Href rest/v1/systems/1/bios/settings -Setting $setting -Session $s
PS C:\> $ret

Messages                                   Name                        Type                       
--------                                   ----                        ----                       
{@{MessageID=iLO.0.10.SystemResetRequired  Extended Error Information  ExtendedError.0.9.6        

This example shows updating the 'AdminName' field in bios setting to set the value to 'TestAdmin'


.EXAMPLE
PS C:\> $LoginNameToModify = 'TimHorton'
PS C:\> $accounts = Get-HPRESTDataRaw -href 'rest/v1/AccountService/Accounts' -Session $s
PS C:\> $reqAccount = $accounts.Items | ?{$_.Username -eq $LoginNameToModify}
PS C:\> $priv = @{}
    $priv.Add('VirtualMediaPriv',$false)
    $priv.Add('UserConfigPriv',$false)
            
    $hp = @{}
    $hp.Add('Privileges',$priv)
    
    $oem = @{}
    $oem.Add('Hp',$hp)

    $user = @{}
    $user.Add('Oem',$oem)

PS C:\> $ret = Set-HPRESTData -Href $reqAccount.links.self.href -Settnig $user -Session $s
PS C:\> $ret

Messages                                  Name                        Type                       
--------                                  ----                        ----                       
{@{MessageID=Base.0.10.AccountModified}}  Extended Error Information  ExtendedError.0.9.6

This example shows modification of user privilege for a user. First the href of the user 'TimHorton' is seacrched from Accounts href. Then user object is created with the required privilege change. This object is then used as the setting parameter value for Set-HPRESTData cmdlet.

.LINK
http://www.hp.com/go/powershell

#>
    param
    (
        [System.String]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $Href,

        [System.Object]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Setting,

        [PSObject]
        [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        $Session
    )
<#
    Edit-HPRESTData is for HTTP PUT method
    Invoke-HPRESTAction is for HTTP POST method
    Remove-HPRESTData is for HTTP DELETE method
    Set-HPRESTData is for HTTP PATCH method
#>
  
    if($session -eq $null -or $session -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Session"))
    }
    if($Setting -eq $null -or $Setting -eq "")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_MISSING')) ,"Setting"))
    }
    if($Setting.GetType().ToString() -ne "System.Collections.Hashtable")
    {
        throw $([string]::Format($(Get-Message('MSG_PARAMETER_INVALID_TYPE')), $Setting.GetType().ToString() ,"Setting"))
    }
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $wr = $null
    $httpWebRequest = $null
    $data = ''
    $returnObjectFromJSON = New-Object PSObject
       
    try
    {
        $resp = Get-HPRESTHttpData -Href $Href -Session $Session
        # if the web response headder 'Allow' field does not have PATCH, then search for Settings href in links field of the data. If the settings field is present, then 
        if(($resp.Headers['Allow'] -split ',').Trim() -notcontains 'PATCH')
        {
            $rs = $resp.GetResponseStream();
            [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
            $results = ''
            [string]$jsonResults = $sr.ReadToEnd();
        
            $results = $jsonResults|Convert-JsonToPSObject
            if($results.links.PSObject.Properties.Name -contains 'Settings')
            {
                $Href = $results.links.Settings.href
            }
            $rs.Close()
            $sr.Close()
        }
        $resp.Close()
    }
    finally
    {
        if ($resp -ne $null -and $resp -is [System.IDisposable]){$resp.Dispose()}
        if ($rs -ne $null -and $rs -is [System.IDisposable]){$rs.Dispose()}
        if ($sr -ne $null -and $sr -is [System.IDisposable]){$sr.Dispose()}
    }
    $data = $Setting | ConvertTo-Json -Depth 10
    try
    {
        $uri = Get-HPRESTUriFromHref -Href $href -Session $Session
        if($uri.substring($uri.length -1) -eq "/")
        {
            $uri = $uri.substring(0,$uri.length-2)
        }
        $wr = [System.Net.WebRequest]::Create($uri)
        $httpWebRequest = [System.Net.HttpWebRequest]$wr
        $httpWebRequest.Method = 'PATCH'
        $httpWebRequest.ContentType = 'application/json'
        $httpWebRequest.ContentLength = $data.length
        $httpWebRequest.AutomaticDecompression = [System.Net.DecompressionMethods]'GZip'
        $httpWebRequest.Headers.Add('X-Auth-Token',$Session.'X-Auth-Token')

        $reqWriter = New-Object System.IO.StreamWriter($httpWebRequest.GetRequestStream(), [System.Text.Encoding]::ASCII)
        $reqWriter.Write($data)
        $reqWriter.Close()

        try
        {
            $webResponse = $httpWebRequest.GetResponse()
            $webStream = $webResponse.GetResponseStream()
            $respReader = New-Object System.IO.StreamReader($webStream)
            $response = $respReader.ReadToEnd()
            $returnObjectFromJSON = $response|Convert-JsonToPSObject

            $webResponse.Close()
            $webStream.Close()
            $respReader.Close()  
            return $returnObjectFromJSON
        } 
        catch
        {
            $webResponse = $_.Exception.InnerException.Response
            $errorRecord = Get-ErrorRecord -WebResponse $webResponse -CmdletName 'Set-HPRESTData'
            $Global:Error.RemoveAt(0)
            throw $errorRecord
            #Write-Error -Message $msg -Category $_.CategoryInfo.Category -CategoryReason $_.CategoryInfo.CategoryReason
        }
          
    }
    finally
    {
        if (($null -ne $reqWriter) -and ($reqWriter -is [System.IDisposable])){$reqWriter.Dispose()}
        if (($null -ne $webResponse) -and ($webResponse -is [System.IDisposable])){$webResponse.Dispose()}
        if (($null -ne $webStream) -and ($webStream -is [System.IDisposable])){$webStream.Dispose()}
        if (($null -ne $respReader) -and ($respReader -is [System.IDisposable])){$respReader.Dispose()}
    }
}


Export-ModuleMember -Function Connect-HPREST, Disconnect-HPREST, Edit-HPRESTData, Find-HPREST, Get-HPRESTData, Get-HPRESTDataRaw, Get-HPRESTDir, Format-HPRESTDir, Get-HPRESTIndex, Get-HPRESTModuleVersion, Get-HPRESTError, Get-HPRESTHttpData, Get-HPRESTSchema, Get-HPRESTSchemaExtref, Get-HPRESTUriFromHref, Invoke-HPRESTAction, Remove-HPRESTData, Set-HPRESTData
# SIG # Begin signature block
# MIIY+wYJKoZIhvcNAQcCoIIY7DCCGOgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUq261zrhnOZMpK1uyxKeRDwtp
# JSWgghPzMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggVIMIIEMKADAgECAhBqJba6oqOIHrqYnJL4yw+NMA0GCSqGSIb3DQEBBQUAMIG0
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBh
# dCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVW
# ZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTE0MDYyNTAw
# MDAwMFoXDTE2MDcyNDIzNTk1OVowejELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNh
# bGlmb3JuaWExEjAQBgNVBAcTCVBhbG8gQWx0bzEgMB4GA1UEChQXSGV3bGV0dC1Q
# YWNrYXJkIENvbXBhbnkxIDAeBgNVBAMUF0hld2xldHQtUGFja2FyZCBDb21wYW55
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvZW91eEe8mEoae5frPX+
# WBFsHw7bkrECc3UANelrP89ZRW64IjR2S/dCUnIpqbMfDXSohVNy/9j8E+Ga8n1M
# wC/IMKigMGRk0AdqjkTML6YhGv5lUFP/c8YOiyEGhx+N/0joXFo8YeN+9xGE82UR
# MGhWJAZjDls+I7VQcCs7UpBuV0egu0tOzufDIgqvWUyTqWAu+lAHsmdS90P+vi82
# Jfv5rEYS6Y1ca2CPMJm7HniDl54QK1By2JEAb5m97VNqyuYKC69D+xDW1GIdGPfr
# v3Ko7NAE5yWg8W8bfIxC5dS+GNh/0alWz1Ke23Uu6Mah+fgO62wxzSd8r1g2VBnw
# NQIDAQABo4IBjTCCAYkwCQYDVR0TBAIwADAOBgNVHQ8BAf8EBAMCB4AwKwYDVR0f
# BCQwIjAgoB6gHIYaaHR0cDovL3NmLnN5bWNiLmNvbS9zZi5jcmwwZgYDVR0gBF8w
# XTBbBgtghkgBhvhFAQcXAzBMMCMGCCsGAQUFBwIBFhdodHRwczovL2Quc3ltY2Iu
# Y29tL2NwczAlBggrBgEFBQcCAjAZFhdodHRwczovL2Quc3ltY2IuY29tL3JwYTAT
# BgNVHSUEDDAKBggrBgEFBQcDAzBXBggrBgEFBQcBAQRLMEkwHwYIKwYBBQUHMAGG
# E2h0dHA6Ly9zZi5zeW1jZC5jb20wJgYIKwYBBQUHMAKGGmh0dHA6Ly9zZi5zeW1j
# Yi5jb20vc2YuY3J0MB8GA1UdIwQYMBaAFM+Zqep7JvRLyY6P1/AFJu/j0qedMB0G
# A1UdDgQWBBSxY0RmDskHVeL3426xzdgBWbGuFDARBglghkgBhvhCAQEEBAMCBBAw
# FgYKKwYBBAGCNwIBGwQIMAYBAQABAf8wDQYJKoZIhvcNAQEFBQADggEBAKoA6naf
# BZ3b4qJVW21/IRNtWounIheL5YD5B5aYaQcPZ3I44gwz5jH90C8DTAvsjUn+NWpO
# gLQ53XcskrY8VSUD8eXfK7M8wTmkTuKZBCaX1l/ejt6nnNfzrGHlGwTa2la98Y6d
# IaMwV6+Hv36gQq/Dh6IdjsjNgFExPOc34AsP/yMK89s3PlHphVEXu7C4/CqPzq1n
# 9l/j/2IOJLoKVDeGjvcuD9rtAoeqowChPmKWjdHmjXNd/PKFdlo085yMWZLuZWHj
# KGgddvWJqnRNCti1WrztJUPS4kGTvsuu0sK9eXOK+VKE+uHxIc6bIyZJAJxS3uPw
# jmnBQuPnl1RDZHwwggYKMIIE8qADAgECAhBSAOWqJVb8GobtlsnUSzPHMA0GCSqG
# SIb3DQEBBQUAMIHKMQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIElu
# Yy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOjA4BgNVBAsTMShj
# KSAyMDA2IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkx
# RTBDBgNVBAMTPFZlcmlTaWduIENsYXNzIDMgUHVibGljIFByaW1hcnkgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkgLSBHNTAeFw0xMDAyMDgwMDAwMDBaFw0yMDAyMDcy
# MzU5NTlaMIG0MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4x
# HzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1z
# IG9mIHVzZSBhdCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4w
# LAYDVQQDEyVWZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMIIB
# IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA9SNLXqXXirsy6dRX9+/kxyZ+
# rRmY/qidfZT2NmsQ13WBMH8EaH/LK3UezR0IjN9plKc3o5x7gOCZ4e43TV/OOxTu
# htTQ9Sc1vCULOKeMY50Xowilq7D7zWpigkzVIdob2fHjhDuKKk+FW5ABT8mndhB/
# JwN8vq5+fcHd+QW8G0icaefApDw8QQA+35blxeSUcdZVAccAJkpAPLWhJqkMp22A
# jpAle8+/PxzrL5b65Yd3xrVWsno7VDBTG99iNP8e0fRakyiF5UwXTn5b/aSTmX/f
# ze+kde/vFfZH5/gZctguNBqmtKdMfr27Tww9V/Ew1qY2jtaAdtcZLqXNfjQtiQID
# AQABo4IB/jCCAfowEgYDVR0TAQH/BAgwBgEB/wIBADBwBgNVHSAEaTBnMGUGC2CG
# SAGG+EUBBxcDMFYwKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNv
# bS9jcHMwKgYIKwYBBQUHAgIwHhocaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3Jw
# YTAOBgNVHQ8BAf8EBAMCAQYwbQYIKwYBBQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1h
# Z2UvZ2lmMCEwHzAHBgUrDgMCGgQUj+XTGoasjY5rw8+AatRIGCx7GS4wJRYjaHR0
# cDovL2xvZ28udmVyaXNpZ24uY29tL3ZzbG9nby5naWYwNAYDVR0fBC0wKzApoCeg
# JYYjaHR0cDovL2NybC52ZXJpc2lnbi5jb20vcGNhMy1nNS5jcmwwNAYIKwYBBQUH
# AQEEKDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC52ZXJpc2lnbi5jb20wHQYD
# VR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMDMCgGA1UdEQQhMB+kHTAbMRkwFwYD
# VQQDExBWZXJpU2lnbk1QS0ktMi04MB0GA1UdDgQWBBTPmanqeyb0S8mOj9fwBSbv
# 49KnnTAfBgNVHSMEGDAWgBR/02Wnwt3su/AwCfNDOfoCrzMxMzANBgkqhkiG9w0B
# AQUFAAOCAQEAViLmNKTEYctIuQGtVqhkD9mMkcS7zAzlrXqgIn/fRzhKLWzRf3Ea
# fOxwqbHwT+QPDFP6FV7+dJhJJIWBJhyRFEewTGOMu6E01MZF6A2FJnMD0KmMZG3c
# cZLmRQVgFVlROfxYFGv+1KTteWsIDEFy5zciBgm+I+k/RJoe6WGdzLGQXPw90o2s
# Qj1lNtS0PUAoj5sQzyMmzEsgy5AfXYxMNMo82OU31m+lIL006ybZrg3nxZr3obQh
# kTNvhuhYuyV8dA5Y/nUbYz/OMXybjxuWnsVTdoRbnK2R+qztk7pdyCFTwoJTY68S
# DVCHERs9VFKWiiycPZIaCJoFLseTpUiR0zGCBHIwggRuAgEBMIHJMIG0MQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlT
# aWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBhdCBodHRw
# czovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVWZXJpU2ln
# biBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBAhBqJba6oqOIHrqYnJL4yw+N
# MAkGBSsOAwIaBQCgcDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYK
# KwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG
# 9w0BCQQxFgQUOwkR8pr/qWpkyqh4STkOI8xYxT8wDQYJKoZIhvcNAQEBBQAEggEA
# Aq4UQsO+YN2gZpZlPxlMA/fT8Jx4DQ34Sq5/o1CJu+IG/UipBk9OdgqZrrxH1aia
# UzBlXc8m+iRDyCyzffD6jZdiZRxA499XgKNBt0vmYXxcKIkckkxfFfeYVh5Mgnqo
# gHGo2MFOtCWFRzsJWaT/RHVx0yYjjsWFr1cEd7zPW9xPF6fNHbidxKSvEz8aUPC+
# 1TumZVbUwGGLa7QTa3fZrCVKhIf9WIu9EOliavjTqYKbuAftP/m5t2Lu9NSODHdP
# RzZKBgjYlm9x83S69MRI/edLvX6rYBC32fDJOpCdEu7nP0ogVySphzK46pZtKHDy
# ZGwXctl8Mj7DkQFBrwjupqGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATBy
# MF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEw
# MC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcy
# AhAOz/Q4yP6/NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTEwMTQxNjQ2NDVaMCMGCSqGSIb3
# DQEJBDEWBBSUs45SsMJU1Cx2jp5j2ICIsZ6fHTANBgkqhkiG9w0BAQEFAASCAQB9
# KYKkQJi8BxCPw82H2JFfmIadol1sIRPmCAzPFPeZT3YxfaScx8Me+kH21jGygELW
# jhyqFUN/89jB2b+AZTn04wNQE1IS6vBKHeHZ87Mgw9Wp2+a3jm+T0R+IOseYt4bD
# lLjZlUeyMQz0MPcF/7XbqyNOXQCfQfGc/aiT7ANdVrXVGjcl9nsLy0uvLmWJxMYG
# EIpxzTGldWSyK+7P0TnlCuEiA1houvIf1FfaM/j1lRArjYzIF8lfCVifS0s9Inal
# 2Ss7yQRr5xXAdo7nhcK5ecQ9jjwagSM+AjusZ9WH34CxY6i9bn/oaNmefo5WWMjA
# uzM5A04QYzJYmAMbEHi4
# SIG # End signature block
