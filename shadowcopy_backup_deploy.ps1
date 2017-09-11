# ------------------------------------------------------------------------------
# ---------------------   DEPLOY_AND_MAKE_SCHEDULED_TASK   ---------------------
# ------------------------------------------------------------------------------
# - this script creates folder C:\ProgramData\shadowcopy_backup
# - copies in to it "shadowcopy_backup.ps1"
# - copies in to it itself - "shadowcopy_backup_deploy.ps1"
# - copies in to it - "SHADOWCOPY_BACKUP_DEPLOY.BAT"
# - creates in it a config file named based on user input
# - creates new ShadowBackupUser account with a password
# - creates new scheduled back up task

# start logging in to a file in %temp%
$log_file = "$env:TEMP\shadowcopy_deploy_log.txt"
Start-Transcript -Path $log_file -Append -Force
$ErrorActionPreference = "Stop"

# check if running as adming
$running_as_admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $running_as_admin){
    echo "NOT RUNNING AS ADMIN, THE END"
    cmd /c pause
    exit
}

$t = Get-Date -format "yyyy-MM-dd || HH:mm:ss"
echo " "
echo "################################################################################"
echo "#######                      $t                      #######"
echo " "

# get the name that will be associated with this backup
echo "ENTER THE NAME OF THE BACKUP"
echo "- config file will be named based on it"
echo "- archives will be named after it"
echo "- shechuled task will have it in the name"
$backup_name = Read-Host "- no spaces, no diacritic, no special characters"
while (!$backup_name) {
    $backup_name = Read-Host "- no spaces, no diacritic, no special characters"
}

# paths in variables that will be used
$deploy_folder = 'C:\ProgramData\Shadowcopy_Backup'
$config_path = "C:\ProgramData\Shadowcopy_Backup\" + $backup_name + "_config.txt"

# check if config with the same name does not alrady exists
if (Test-Path $config_path) {
    echo "THE NAME: $backup_name IS ALREADY IN USE!"
    cmd /c pause
    exit
}

echo "- installation path: $deploy_folder"

if (Test-Path $deploy_folder) {
    echo "- the folder already exists"
} else {
    New-Item C:\ProgramData\Shadowcopy_Backup -type directory
    echo "- the folder created"
}

$config_template = @"
# backups will be named based on this config file name
target=C:\test
backup_path=C:\
# 0=no-compression,5=default,9=ultra [0 | 1 | 3 | 5 | 7 | 9 ]
compression_level=0
# delete applies to zip files at the backup_path
# their name must start the same as the name of this config file
delete_old_backups=true
keep_last_n=10
keep_monthly=false
keep_weekly=false
"@

$config_template | Out-File -FilePath $config_path -Encoding ASCII

echo "- config file created: $config_path"

# change permissions to allow easy editing of the config file
$Acl = Get-Acl -Path $config_path
$Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("USERS","Modify","Allow")
$Acl.SetAccessRule($Ar)
Set-Acl -Path $config_path -AclObject $Acl

echo "- changing config files permissions to allow easy editing"

if ($PSScriptRoot -eq "C:\ProgramData\Shadowcopy_Backup") {
    echo "- running the script from $deploy_folder"
    echo "- nothing is being copied"
    echo "- only a new config file is created and a new scheduled task"
} else {
    echo "- copying the files to $deploy_folder"
    echo "- will overwrite script files if already exist"
    robocopy $PSScriptRoot $deploy_folder shadowcopy_backup.ps1 shadowcopy_backup_deploy.ps1 SHADOWCOPY_BACKUP_DEPLOY.BAT /NFL /NDL /NJS /IS
}

# new user to allow the scheduled task to run without being seen in any way, /RU SYSTEM does not work on win10, and 7/8 had less info in logging
$local_users = Get-LocalUser
if (-NOT ($local_users.Name -contains "ShadowBackupUser")) {
    echo "ADDING NEW USER: ShadowBackupUser"
    echo "- enter new password for this account"
    $Password = Read-Host -AsSecureString
    New-LocalUser -Name "ShadowBackupUser" -Password $Password -Description "Shadow Backup Administrator" -AccountNeverExpires -PasswordNeverExpires
    Add-LocalGroupMember -Group "Administrators" -Member "ShadowBackupUser"
    echo "- added to the Administrators group"

    # editing registry to hide the account from login screen
    $registry_path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
    New-Item $registry_path -Force | New-ItemProperty -Name "ShadowBackupUser" -Value 0 -PropertyType DWord -Force
    echo "- hidding ShadowBackupUser from the login screen"
} else {
    echo "- ShadowBackupUser already exists, youd better remember the password"
}


# scheduled task should be edited manually afterwards using taskschd.msc
echo "CREATING NEW SCHEDULED TASK"

$schedule = "DAILY" # MINUTE HOURLY DAILY WEEKLY MONTHLY ONCE ONSTART ONLOGON ONIDLE
$modifier = 1 # 1 - every day, 7 - every 7 days, behaves differently depending on unit in schedule
$start_time = "20:19"
$title = "Shadowcopy_Backup_$backup_name"
$command_in_trigger = "'& C:\ProgramData\Shadowcopy_Backup\shadowcopy_backup.ps1 -config_txt_path $config_path'"
$trigger = "Powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command $command_in_trigger"

# using cmd for the compatibility with windows 7 instead of Register-ScheduledTask cmdlet
# /RP for password is needed to allow run without being logged in
cmd /c SchTasks /Create /SC $schedule /MO $modifier /ST $start_time /TN $title /TR $trigger /RL HIGHEST /F /RU ShadowBackupUser /RP

echo "- edit the scheduled task using taskschd.msc for the specific needs"

echo "CHECKING IF 7-ZIP IS INSTALLED"
if (-NOT (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {
    for ($i=0; $i -lt 20; $i++){
        echo " INSTALL 7-zip x64 !!!"
    }
} else {
    echo "- 7-zip x64 seems to be installed"
}

echo " "
echo "################################################################################"
cmd /c pause
