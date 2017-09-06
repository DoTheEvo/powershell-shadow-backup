# ------------------------------------------------------------------------------
# ---------------------   DEPLOY_AND_MAKE_SCHEDULED_TASK   ---------------------
# ------------------------------------------------------------------------------
# - requirements: script shadowcopy_backup.ps1 in the same directory
# - scripts creates folder C:\ProgramData\shadowcopy_backup
# - copies in to it "shadowcopy_backup.ps1" and "shadowcopy_backup_deploy.ps1"
# - create new scheduled task

# start logging
$log_file = "$env:TEMP\shadowcopy_deploy.txt"
Start-Transcript -Path $log_file -Append -Force
$ErrorActionPreference = "Stop"

# true or false running as admin
$running_as_admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $running_as_admin){
    throw "NOT RUNNING AS ADMIN, THE END"
}

$t = Get-Date -format "yyyy-MM-dd || HH:mm:ss"
echo " "
echo "################################################################################"
echo "#######                      $t                      #######"
echo " "

# name associated with this backup
echo "ENTER THE NAME OF THE BACKUP"
echo "- config file will be named based on it"
echo "- archive names will be named after it"
echo "- shechuled task will have it in the name"
$backup_name = Read-Host "Enter the name, no spaces, no diacritic"
while (!$backup_name) {
    $backup_name = Read-Host "Enter the name, no spaces, no diacritic"
}

echo "DEPLOING THE SCRIPT"

$deploy_folder = 'C:\ProgramData\Shadowcopy_Backup'
$full_deploypath1 = 'C:\ProgramData\Shadowcopy_Backup\shadowcopy_backup.ps1'
$full_deploypath2 = 'C:\ProgramData\Shadowcopy_Backup\shadowcopy_backup_deploy.ps1'
$config_path = "C:\ProgramData\Shadowcopy_Backup\" + $backup_name + "_config.txt"
echo "- installation path: $deploy_folder"

if (Test-Path $deploy_folder) {
    echo "- the folder already exists"
} else {
    New-Item C:\ProgramData\Shadowcopy_Backup -type directory
    echo "- the folder created"
}

$example_config = @"
# backups will be named based on this config file name
target=C:\test
backup_path=C:\backups
# 0=no-compression,5=default,9=ultra [0 | 1 | 3 | 5 | 7 | 9 ]
compression_level=0
# delete applies to zip files at the backup_path
# their name must start the same as the name of this config file
delete_old_backups=true
keep_last_n=10
keep_monthly=false
keep_weekly=false
"@

$example_config | Out-File -FilePath $config_path -Encoding ASCII


if ($PSScriptRoot -eq "C:\ProgramData\Shadowcopy_Backup") {
    echo "- running script that is already in C:\ProgramData\Shadowcopy_Backup"
    echo "- nothing is copied, only a new config file is created and a new scheduled task"
} else {
    # if the script already exists on the system rename old one
    if (Test-Path $full_deploypath1) {
        $unix_time = Get-Date -UFormat %s -Millisecond 0
        $new_name = "shadowcopy_backup.ps1." + $unix_time
        Rename-Item $full_deploypath1 $new_name
        echo "- the backup script is already present at the target destination"
        echo "- renaming old one to $new_name"
    }
    # if the deploy script already exists on the system rename old one
    if (Test-Path $full_deploypath2) {
        $unix_time = Get-Date -UFormat %s -Millisecond 0
        $new_name = "shadowcopy_backup_deploy.ps1." + $unix_time
        Rename-Item $full_deploypath2 $new_name
        echo "- the deploy script is already present at the target destination"
        echo "- renaming old one to $new_name"
    }
    echo "- copying the scripts to $deploy_folder"
    robocopy $PSScriptRoot $deploy_folder shadowcopy_backup.ps1 shadowcopy_backup_deploy.ps1 SHADOWCOPY_BACKUP_DEPLOY.BAT /NFL /NDL /NJS
}

echo "CREATING NEW SCHEDULED TASK"

$schedule = "DAILY" # MINUTE HOURLY DAILY WEEKLY MONTHLY ONCE ONSTART ONLOGON ONIDLE
$modifier = 1 # 1 - every day, 7 - every 7 days, behaves differently depending on unit in schedule
$day = "THU" # MON,TUE,WED,THU,FRI,SAT,SUN
$start_time = "20:19"
$title = "Shadowcopy_Backup_$backup_name"
$command_in_trigger = "'& C:\ProgramData\Shadowcopy_Backup\shadowcopy_backup.ps1 -config_txt_path $config_path'"
$trigger = "Powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command $command_in_trigger"

# using cmd for the compatibility with windows 7
cmd /c SchTasks /Create /SC $schedule /MO $modifier /ST $start_time /TN $title /TR $trigger /RL HIGHEST /F /RU SYSTEM

# with the day option used, needs schedule to be set to WEEKLY and then day of the week
# cmd /c SchTasks /Create /SC $schedule /MO $modifier /D $day /ST $start_time /TN $title /TR $trigger /RL HIGHEST /F /RU SYSTEM

echo "CHECKING IF 7-ZIP IS INSTALLED"
if (-NOT (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {
    for ($i=0; $i -lt 10; $i++){
        echo " 7-zip x64 needs to be installed!!! !!! !!!!!!!!!!!!!!!"
    }
} else {
    echo "- 7-zip x64 seems to be installed"
}

echo " "
echo "################################################################################"
cmd /c pause
