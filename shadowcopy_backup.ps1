#
# backups $target as a zip archive to $backup_path
# uses volume shadowcopy service to also backup opened files
# script is written for C:\ drive
# place in "C:\Windows\System32\WindowsPowerShell\v1.0"
# requires WMF 5.0 and Volume Shadow Copy (VSS) service running
#

$target = "C:\test"
$backup_path = $env:HOMEPATH
$log_file = "$env:HOMEPATH\shadowcopy_log.txt"
$compression_level = "NoCompression" # Optimal / Fastest / NoCompression

# ----------------------------------------------

$temp_shadow_link = "$env:TEMP\shadowcopy_link"
$date = Get-Date -format yyyy-MM-dd
$unix_time = Get-Date -UFormat %s -Millisecond 0
$archive_filename = $date + "_" + $unix_time + ".zip"
$temp_archive_path = Join-Path -Path $env:TEMP -ChildPath $archive_filename

$t = Get-Date -format yyyy-MM-dd_HH:mm:ss
echo " " >> $log_file
echo "###################################   $t   ###################################" >> $log_file
echo "- USER: $(whoami)" >> $log_file
echo "- BACKUP TARGET: $target" >> $log_file
echo "- TO DESTINATION: $backup_path" >> $log_file

# true or false running as admin
$running_as_admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $running_as_admin){
    echo "NOT RUNNING AS ADMIN" >> $log_file
    echo "THE END" >> $log_file
    exit
}

# check if $target path exists on the system
if (-Not (Test-Path $target)) {
    echo "NOT A VALID TARGET PATH" >> $log_file
    echo $target >> $log_file
    exit
}

# check if $backup_path path exists on the system
if (-Not (Test-Path $backup_path)) {
    echo "NOT A VALID TARGET PATH" >> $log_file
    echo $target >> $log_file
    exit
}

echo "CREATING NEW SHADOWCOPY SNAPSHOT" >> $log_file

$s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
$s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
$d  = $s2.DeviceObject + "\"

if (Test-Path $temp_shadow_link) {
    echo "$temp_shadow_link EXISTS, DELETING" >> $log_file
    cmd /c rmdir $temp_shadow_link
}

cmd /c mklink /d $temp_shadow_link $d >> $log_file
$shadow_snapshot_path = $target -ireplace "^C:", $temp_shadow_link

if (-Not (Test-Path $shadow_snapshot_path)) {
    echo "NOT A VALID SHADOW COPY PATH" >> $log_file
    echo $shadow_snapshot_path >> $log_file
    exit
}

echo "-------------------------------------------------------------------------------" >> $log_file
echo "CREATING ARCHIVE: $archive_filename `nIN $env:TEMP" >> $log_file
Compress-Archive -Path $shadow_snapshot_path -DestinationPath $temp_archive_path -CompressionLevel $compression_level -ErrorAction Stop

echo "-------------------------------------------------------------------------------" >> $log_file
echo "DELETING SNAPSHOT AND THE LINK" >> $log_file
$s2.Delete()
cmd /c rmdir $temp_shadow_link

Vssadmin list shadowstorage >> $log_file

echo "-------------------------------------------------------------------------------" >> $log_file
echo "MOVING THE ARCHIVE..." >> $log_file
robocopy $env:TEMP $backup_path $archive_filename /MOVE /R:3 /np >> $log_file

echo "-------------------------------------------------------------------------------" >> $log_file
$t = Get-Date -format yyyy-MM-dd_HH:mm:ss
echo "ALL DONE   $t   ALL DONE" >> $log_file

# ----------------------------------------------

function MAKE_SCHEDULED_TASK {
    #$Stt = New-ScheduledTaskTrigger -Once -At 23:45
    #$Stt = New-ScheduledTaskTrigger -Daily -At 23:45
    #$Stt = New-ScheduledTaskTrigger -Daily -DaysInterval 3 -At 23:45
    #$Stt = New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -DaysOfWeek Sunday -At 23:45
    #$Stt = New-ScheduledTaskTrigger -AtLogon

    #Create a new trigger that is configured to trigger at startup
    $STTrigger = New-ScheduledTaskTrigger -AtLogon
    #Name for the scheduled task
    $STName = "shadowcopy_backup"
    #Action to run as
    $STAction = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command "shadowcopy_backup.ps1"'
    #Configure when to stop the task and how long it can run for. In this example it does not stop on idle and uses the maximum possible duration by setting a timelimit of 0
    $STSettings = New-ScheduledTaskSettingsSet -DontStopOnIdleEnd -ExecutionTimeLimit ([TimeSpan]::Zero)
    #Configure the principal to use for the scheduled task and the level to run as
    $STPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel "Highest"
    #Register the new scheduled task if it does not exists
    If (Get-ScheduledTask | Where-Object {$_.TaskName -like $STName}){
        echo "SCHEDULED TASK ALREADY EXISTS"
    } else {
        Register-ScheduledTask $STName -Action $STAction -Trigger $STTrigger -Principal $STPrincipal -Settings $STSettings
    }

}
