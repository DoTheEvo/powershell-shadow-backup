#
# backups $target as a zip archive to $backup_path
# uses volume shadowcopy service to also backup opened files
# script is written for C:\ drive
# place in "C:\Windows\System32\WindowsPowerShell\v1.0"
# requires x64, 7-zip, WMF 5.0 and Volume Shadow Copy (VSS) service running
#

$ErrorActionPreference = "Stop"

function MAKE_BACKUP {
    $target = "C:\test"
    $backup_path = "C:\"
    $log_file = "C:\shadowcopy_log.txt"
    $compression_level = 0 # 0=no-compression,5=default,9=ultra

    # ----------------------------------------------
    $start_time = Get-Date
    # every output goes in to log file
    Start-Transcript -Path $log_file -Append -Force

    $temp_shadow_link = "$env:TEMP\shadowcopy_link"
    $date = Get-Date -format "yyyy-MM-dd"
    $unix_time = Get-Date -UFormat %s -Millisecond 0
    $archive_filename = $date + "_" + $unix_time + ".zip"
    $temp_archive_path = Join-Path -Path $env:TEMP -ChildPath $archive_filename

    $t = Get-Date -format "yyyy-MM-dd || HH:mm:ss"
    " "
    "################################################################################################"
    "#######                              $t                              #######"

    "- USER: $(whoami)"
    "- BACKUP TARGET: $target"
    "- TO DESTINATION: $backup_path"

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
        "NOT A VALID TARGET PATH"
        $target
        exit
    }
    "-------------------------------------------------------------------------------"
    "CREATING NEW SHADOWCOPY SNAPSHOT"

    $s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
    $s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
    $d  = $s2.DeviceObject + "\"

    if (Test-Path $temp_shadow_link) {
        "$temp_shadow_link EXISTS, DELETING"
        cmd /c rmdir $temp_shadow_link
    }

    cmd /c mklink /d $temp_shadow_link $d
    $shadow_snapshot_path = $target -ireplace "^C:", $temp_shadow_link

    if (-Not (Test-Path $shadow_snapshot_path)) {
        "NOT A VALID SHADOW COPY PATH"
        $shadow_snapshot_path
        exit
    }

    "-------------------------------------------------------------------------------"
    "CREATING ARCHIVE: $archive_filename `nIN $env:TEMP"
    if (-NOT (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {
        throw "$env:ProgramFiles\7-Zip\7z.exe NEEDED!"
    }

    Start-Process -WindowStyle hidden -FilePath "$env:ProgramFiles\7-Zip\7z.exe" -ArgumentList "a","-snl","-mx=$compression_level","$temp_archive_path","$target" -Wait

    "-------------------------------------------------------------------------------"
    "DELETING SNAPSHOT AND THE LINK"
    $s2.Delete()
    cmd /c rmdir $temp_shadow_link

    Vssadmin list shadowstorage
    "-------------------------------------------------------------------------------"
    "MOVING THE ARCHIVE USING ROBOCOPY"
    robocopy $env:TEMP $backup_path $archive_filename /MOVE /R:3 /np

    $end_time = Get-Date
    $runtime = $end_time - $start_time
    $readable_runtime = "{0:dd} days {0:hh} hours {0:mm} minutes {0:ss} seconds" -f $runtime

    "#######       ALL DONE       $readable_runtime       ALL DONE       #######"
    "################################################################################################"
    " "
}

# -----------------------------------------------------------------------------------
# -----------------------------   MAKE_SCHEDULED_TASK   -----------------------------
# -----------------------------------------------------------------------------------

# copy the script itself to "C:\Windows\System32\WindowsPowerShell\v1.0\shadowcopy_backup.ps1"
# if one is already there, back it up and replace with the new one
# create new scheduled task - shadowcopy_backup

function MAKE_SCHEDULED_TASK {
    $storage_path = "C:\Windows\System32\WindowsPowerShell\v1.0"
    $full_storage_path = "C:\Windows\System32\WindowsPowerShell\v1.0\shadowcopy_backup.ps1"

    "COPYING THIS SCRIPT(shadowcopy_backup.ps1) IN TO $storage_path"
    # if file already exists, rename the original
    if (Test-Path $full_storage_path) {
        if (-NOT ($PSCommandPath -eq $full_storage_path)) {
            $unix_time = Get-Date -UFormat %s -Millisecond 0
            $new_name = "shadowcopy_backup.ps1." + $unix_time
            Rename-Item $full_storage_path $new_name
            "- the script is already present on the system"
            "- renaming old one to $new_name"
        }
    }

    "- copying this script"
    robocopy $PSScriptRoot $storage_path shadowcopy_backup.ps1 /NFL /NDL /NJS

    "CREATING NEW SCHEDULED TASK"
    # $Stt = New-ScheduledTaskTrigger -Once -At 23:45
    # $Stt = New-ScheduledTaskTrigger -Daily -At 23:45
    # $Stt = New-ScheduledTaskTrigger -Daily -DaysInterval 3 -At 23:45
    # $Stt = New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -DaysOfWeek Sunday -At 23:45
    # $Stt = New-ScheduledTaskTrigger -AtLogon

    # Create a new trigger that is configured to trigger at startup
    $STTrigger = New-ScheduledTaskTrigger -Daily -At 20:19
    # Name for the scheduled task
    $STName = "shadowcopy_backup"
    # Action to run as
    $STAction = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command "shadowcopy_backup.ps1"'
    # Configure when to stop the task and how long it can run for. In this example it does not stop on idle and uses the maximum possible duration by setting a timelimit of 0
    $STSettings = New-ScheduledTaskSettingsSet -DontStopOnIdleEnd -ExecutionTimeLimit ([TimeSpan]::Zero)
    # Configure the principal to use for the scheduled task and the level to run as
    $STPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel "Highest"
    # Remove any old scheduled task with the same name
    If (Get-ScheduledTask | Where-Object {$_.TaskName -like $STName}){
        "- scheduled task already exists, deleting old one"
        Unregister-ScheduledTask -TaskName $STName -Confirm:$false
    }
    # Register the new scheduled task
    "- creating new scheduled task with trigger: " + $STTrigger.Frequency.ToString()
    Register-ScheduledTask $STName -Action $STAction -Trigger $STTrigger -Principal $STPrincipal -Settings $STSettings
}

# -----------------------------------------------------------------------------------
# -------------------------------   FUNCTIONS CALLS   -------------------------------
# -----------------------------------------------------------------------------------


# MAKE_SCHEDULED_TASK
MAKE_BACKUP
