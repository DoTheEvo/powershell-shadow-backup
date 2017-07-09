# ------------------------------------------------------------------------------
# -----------------------------   SHADOWCOPY_BACKUP   --------------------------
# ------------------------------------------------------------------------------
# - requires: 7-zip, WMF 5.0+, Volume Shadow Copy (VSS) service enabled
# - backups $target as a zip archive to $backup_path
# - uses volume shadowcopy service to also backup opened files
# - C:\ drive only
#

$ErrorActionPreference = "Stop"
$script_start_date = Get-Date

$log_file = "C:\shadowcopy_log.txt"
Start-Transcript -Path $log_file -Append -Force

function MAKE_BACKUP {
    # ----------------------------------------------
    $target = "C:\test"
    $backup_path = "C:\"
    $compression_level = 0 # 0=no-compression,5=default,9=ultra
    # ----------------------------------------------


    $temp_shadow_link = "$env:TEMP\shadowcopy_link"
    $date = Get-Date -format "yyyy-MM-dd"
    $unix_time = Get-Date -UFormat %s -Millisecond 0
    $archive_filename = $date + "_" + $unix_time + ".zip"
    $temp_archive_path = Join-Path -Path $env:TEMP -ChildPath $archive_filename

    $t = Get-Date -format "yyyy-MM-dd || HH:mm:ss"
    " "
    "################################################################################"
    "#######                      $t                      #######"
    " "
    "- user: $(whoami)"
    "- backup target: $target"
    "- to destination: $backup_path"

    # true or false running as admin
    $running_as_admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-NOT $running_as_admin){
        "NOT RUNNING AS ADMIN"
        "THE END"
        exit
    }

    # check if $target path exists on the system
    if (-Not (Test-Path $target)) {
        "NOT A VALID TARGET PATH"
        $target
        exit
    }

    # check if $backup_path path exists on the system
    if (-Not (Test-Path $backup_path)) {
        "NOT A VALID BACKUP PATH"
        $backup_path
        exit
    }
    "-------------------------------------------------------------------------------"
    "CREATING NEW SHADOWCOPY SNAPSHOT"

    $s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
    $s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
    $d  = $s2.DeviceObject + "\"

    "- new snapshot created $d"

    if (Test-Path $temp_shadow_link) {
        "- $temp_shadow_link exists, deleting"
        cmd /c rmdir $temp_shadow_link
    }

    cmd /c mklink /d $temp_shadow_link $d
    $shadow_snapshot_path = $target -ireplace "^C:", $temp_shadow_link

    if (-Not (Test-Path $shadow_snapshot_path)) {
        "- not a valid shadow copy path"
        $shadow_snapshot_path
        exit
    }

    "-------------------------------------------------------------------------------"
    "CREATING ARCHIVE"
    if (-NOT (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {
        throw "$env:ProgramFiles\7-Zip\7z.exe NEEDED!"
    }
    # 7zip in action
    "- creating $temp_archive_path"
    "- waiting for 7zip to finish..."
    Start-Process -WindowStyle hidden -FilePath "$env:ProgramFiles\7-Zip\7z.exe" -ArgumentList "a","-snl","-mx=$compression_level","$temp_archive_path","$target" -Wait
    "- done"

    "-------------------------------------------------------------------------------"
    "DELETING SHADOWCOPY SNAPSHOT AND THE LINK"
    $s2.Delete()
    "- the vss snapshot deleted"
    cmd /c rmdir $temp_shadow_link
    "- the link to the snapshot deleted"
    Vssadmin list shadowstorage

    "-------------------------------------------------------------------------------"
    "MOVING THE ARCHIVE USING ROBOCOPY"
    robocopy $env:TEMP $backup_path $archive_filename /MOVE /R:3 /np

    $runtime = (Get-Date) - $script_start_date
    $readable_runtime = "{0:dd} days {0:hh} hours {0:mm} minutes {0:ss} seconds" -f $runtime

    "#######              $readable_runtime              #######"
    "################################################################################"
    " "
}

# ------------------------------------------------------------------------------
# ---------------------   DEPLOY_AND_MAKE_SCHEDULED_TASK   ---------------------
# ------------------------------------------------------------------------------
# - copy the script itself to "C:\Windows\System32\WindowsPowerShell\v1.0\"
# - if one is already there, back it up and replace with the new one
# - create new scheduled task - shadowcopy_backup

function DEPLOY_AND_MAKE_SCHEDULED_TASK {

    $t = Get-Date -format "yyyy-MM-dd || HH:mm:ss"
    " "
    "################################################################################"
    "#######                      $t                      #######"
    " "
    $deploy_path = "C:\Windows\System32\WindowsPowerShell\v1.0"
    $full_deploypath = "C:\Windows\System32\WindowsPowerShell\v1.0\shadowcopy_backup.ps1"

    "DEPLOY THE SCRIPT"

    # if this is NOT the deployed script being run but a new script
    if (-NOT ($PSCommandPath -eq $full_deploypath)) {
        # if the script already exists on the system rename
        if (Test-Path $full_deploypath) {
            $unix_time = Get-Date -UFormat %s -Millisecond 0
            $new_name = "shadowcopy_backup.ps1." + $unix_time
            Rename-Item $full_deploypath $new_name
            "- the script is already present at the target destination"
            "- renaming old one to $new_name"
        }
        "- copying this script to $full_deploypath"
        robocopy $PSScriptRoot $deploy_path shadowcopy_backup.ps1 /NFL /NDL /NJS
    } else {
        "- running already deployed script, nothing to copy"
    }

    "CREATING NEW SCHEDULED TASK"
    $schedule = "DAILY" # MINUTE HOURLY DAILY WEEKLY MONTHLY ONCE ONSTART ONLOGON ONIDLE
    $modifier = 1 # 1 - every day, 7 - every 7 days, or whatever unit is set in schedule
    $day = "THU" # MON,TUE,WED,THU,FRI,SAT,SUN
    $start_time = "20:19"
    $title = "shadowcopy_backup"
    $trigger = "Powershell.exe shadowcopy_backup.ps1"

    cmd /c SchTasks /Create /SC $schedule /MO $modifier /ST $start_time /TN $title /TR $trigger /RL HIGHEST /F /RU SYSTEM

    # with the day option, needs schedule to be set to WEEKLY and then day of the week
    # cmd /c SchTasks /Create /SC $schedule /MO $modifier /D $day /ST $start_time /TN $title /TR $trigger /RL HIGHEST /F /RU SYSTEM

    $runtime = (Get-Date) - $script_start_date
    $readable_runtime = "{0:dd} days {0:hh} hours {0:mm} minutes {0:ss} seconds" -f $runtime
    " "
    "#######              $readable_runtime              #######"
    "################################################################################"
}

# -----------------------------------------------------------------------------------
# -------------------------------   FUNCTIONS CALLS   -------------------------------
# -----------------------------------------------------------------------------------

# DEPLOY_AND_MAKE_SCHEDULED_TASK
MAKE_BACKUP
