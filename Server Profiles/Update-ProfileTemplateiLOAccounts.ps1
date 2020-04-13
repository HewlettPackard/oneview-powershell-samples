
# ------------------- iLO Attribute: Local Accounts
$user1                      = @{
    userName                 = 'user1';
    displayName              = 'user1';
    password                 = 'password';
    loginPriv                = $True;       # Used for local login
    userConfigPriv           = $True;
    remoteConsolePriv        = $True;
    virtualMediaPriv         = $False;
    iLOConfigPriv            = $False;
    hostBIOSConfigPriv       = $False;  
    hostNICConfigPriv        = $False;   
    hostStorageConfigPriv    = $False; 
    virtualPowerAndResetPriv = $False
}

$user2                      = @{
userName                 = 'user2';
displayName              = 'user2';
password                 = 'password';
loginPriv                = $True;       # Used for local login
userConfigPriv           = $True;
remoteConsolePriv        = $False;
virtualMediaPriv         = $False;
iLOConfigPriv            = $False;
hostBIOSConfigPriv       = $False;  
hostNICConfigPriv        = $False;   
hostStorageConfigPriv    = $False; 
virtualPowerAndResetPriv = $False
}

$mpLocalAccounts            = @{
    settingType = 'LocalAccounts';
    args        = @{
            localAccounts = @($user1, $user2)
    }
}

$managementProcessor        = @{
    manageMp            = $True;
    complianceControl   = 'Checked';
    mpSettings          = @($mpLocalAccounts)            
}

# ----------------- Get SPT
$spt                        = get-HPOVserverprofileTemplate -name 'my-spt'
# ----------------- Update iloSettings
$spt.managementProcessor    = $managementProcessor
Set-HPOVResource -InputObject $spt | Wait-HPOVTaskComplete | fl *
