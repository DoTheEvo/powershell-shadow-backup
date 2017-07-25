# ------------------------------------------------------------------------------
# ---------------------   DEPLOY_AND_MAKE_SCHEDULED_TASK   ---------------------
# ------------------------------------------------------------------------------
# - requirements: script shadowcopy_backup.ps1 in the same directory
# - create folder C:\ProgramData\shadowcopy_backup
# - copy in to it "shadowcopy_backup.ps1" and "shadowcopy_backup_deploy.ps1"
# - create new scheduled task

$log_file = "C:\ProgramData\shadowcopy_backup\deploy.txt"
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
echo "DEPLOING THE SCRIPT"

$deploy_folder = 'C:\ProgramData\Shadowcopy_Backup'
$full_deploypath1 = 'C:\ProgramData\Shadowcopy_Backup\shadowcopy_backup.ps1'
$full_deploypath2 = 'C:\ProgramData\Shadowcopy_Backup\shadowcopy_backup_deploy.ps1'
echo "- deploy folder: $deploy_folder"

if (Test-Path $deploy_folder) {
    echo "- the folder already exists"
} else {
    New-Item C:\ProgramData\Shadowcopy_Backup -type directory
    echo "- the folder created"
}

if ($PSScriptRoot -eq "C:\ProgramData\Shadowcopy_Backup") {
    echo "- running script that is already in C:\ProgramData\Shadowcopy_Backup"
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
    robocopy $PSScriptRoot $deploy_folder shadowcopy_backup.ps1 shadowcopy_backup_deploy.ps1 example_config.txt SHADOWCOPY_BACKUP_DEPLOY.BAT /NFL /NDL /NJS
}

echo "CREATING NEW SCHEDULED TASK"

$schedule = "DAILY" # MINUTE HOURLY DAILY WEEKLY MONTHLY ONCE ONSTART ONLOGON ONIDLE
$modifier = 1 # 1 - every day, 7 - every 7 days, behaves differently depending on unit in schedule
$day = "THU" # MON,TUE,WED,THU,FRI,SAT,SUN
$start_time = "20:19"
$title = "Shadowcopy Backup"
$command_in_trigger = "'& C:\ProgramData\Shadowcopy_Backup\shadowcopy_backup.ps1 -config_txt_path C:\ProgramData\Shadowcopy_Backup\example_config.txt'"
$trigger = "Powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command $command_in_trigger"
# using cmd for the compatibility with windows 7
cmd /c SchTasks /Create /SC $schedule /MO $modifier /ST $start_time /TN $title /TR $trigger /RL HIGHEST /F /RU SYSTEM

# with the day option, needs schedule to be set to WEEKLY and then day of the week
# cmd /c SchTasks /Create /SC $schedule /MO $modifier /D $day /ST $start_time /TN $title /TR $trigger /RL HIGHEST /F /RU SYSTEM

echo " "
echo "################################################################################"
cmd /c pause
