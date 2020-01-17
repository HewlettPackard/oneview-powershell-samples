# Prompt admin for updated password value
Do
{

    # Prompt for new password
    $Password = Read-Host "Password" -AsSecureString

    # Ask for it again
    $Password2 = Read-Host "Confirm password" -AsSecureString

    if ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)) -ne [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password2)))
    {

        Write-HOst "Passwords do not match." -ForegroundColor Red

    }

} Until ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)) -eq [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password2)))

# Get the server profile template object to update
$spt = Get-HPOVServerProfileTemplate -Name spt1

# Set the local administrator password to an updated value
($spt.managementProcessor.mpSettings | ? settingType -eq 'AdministratorAccount').args.password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
Save-HPOVServerProfileTemplate -InputObject $spt

# See which profiles are no longer compliant
Get-HPOVServerProfile -InputObject $spt

# See what will change when executing update profiles to their new configuration
Get-HPOVServerProfile -InputObject $spt | Update-HPOVServerProfile -WhatIf

# Perform update
Get-HPOVServerProfile -InputObject $spt | Update-HPOVServerProfile