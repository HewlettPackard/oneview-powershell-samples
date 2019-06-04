# From https://github.com/HewlettPackard/POSH-HPOneView/issues/346
# You would use Get-HPOVScope to get the scope you want to perform operations with. Within that [HPOneView.Appliance.Scope] 
# object, there is a Members property that contains the resources that are associated with that scope. Within those resources 
# is an Uri property which you can then get the server object.

$ServerName = "MyServer.domain.com"

# Get Scope resource from API
$Scope = Get-HPOVScope -Name ScopeName -ErrorAction Stop

# Export Scope "members" property for reference later
$scope.Members | Select -Property @{Name = "ScopeName"; Expression = {$Scope.Name}}, `
                                  @{Name = "Name"; Expression = {$_.Name}}, `
                                  @{Name = "Type"; Expression = {$_.Type}}, `
                                  @{Name = "Uri"; Expression = {$_.Uri}}, `
                                  @{Name = "ResourceName"; Expression = { (Send-HPOVRequest $_.uri).name }} | Export-Csv c:\temp\scope_members.csv -NoTypeInformation

# Validate the CSV was created
Test-Path c:\temp\scope_members.csv

# Examine the CSV file.  This should open with your workbook/worksheet editor, or another editor if .csv is registered to a specific application on your PC.
& c:\temp\scope_members.csv

# Remove the server resource
Get-HPOVServer -Name $ServerName -ErrorAction Stop | Remove-HPOVServer -Confirm:$false | Wait-HPOVTaskComplete

# Add the server back, and specify the scope to add it to
Add-HPOVServer -Computername $ServerName -Credential $MyiLOCreds -Scope $Scope

# Validate the resource was added to the scope
If (-not ((Get-HPOVScope -Name ScopeName).Members | ? Name -eq $ServerName)) 
{

    Write-Error ("Server {0} was not added back to {1} scope." -f $ServerName, $Scope)

}