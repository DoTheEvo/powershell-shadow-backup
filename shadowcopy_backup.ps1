# ------------------------------------------------------------------------------
# -----------------------------   SHADOWCOPY_BACKUP   --------------------------
# ------------------------------------------------------------------------------
# - requirements: 7-zip, WMF 5.0+, Volume Shadow Copy (VSS) service enabled
# - backups $target as a zip archive to $backup_path
# - uses volume shadowcopy service to also backup opened files
# - C:\ drive only
#

# ----------------------------------------------
$target = "C:\test"
$backup_path = "C:\"
$compression_level = 0 # 0=no-compression,5=default,9=ultra
# ----------------------------------------------

$log_file = "C:\ProgramData\shadowcopy_backup\shadowcopy_log.txt"
Start-Transcript -Path $log_file -Append -Force
$ErrorActionPreference = "Stop"
$script_start_date = Get-Date

$temp_shadow_link = "$env:TEMP\shadowcopy_link"
$date = Get-Date -format "yyyy-MM-dd"
$unix_time = Get-Date -UFormat %s -Millisecond 0
$archive_filename = $date + "_" + $unix_time + ".zip"
$temp_archive_path = Join-Path -Path $env:TEMP -ChildPath $archive_filename

$t = Get-Date -format "yyyy-MM-dd || HH:mm:ss"
echo " "
echo "################################################################################"
echo "#######                      $t                      #######"
echo " "
echo "- user: $(whoami)"
echo "- target: $target"
echo "- backup to destination: $backup_path"

# true or false running as admin
$running_as_admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $running_as_admin){
    throw "NOT RUNNING AS ADMIN, THE END"
}
# check if $target path exists on the system
if (-Not (Test-Path $target)) {
    throw "NOT A VALID TARGET PATH: $target"
}
# check if $backup_path path exists on the system
if (-Not (Test-Path $backup_path)) {
    throw "NOT A VALID BACKUP PATH: $backup_path"
}

echo "-------------------------------------------------------------------------------"
echo "CREATING NEW SHADOWCOPY SNAPSHOT"

$s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
$s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
$d  = $s2.DeviceObject + "\"

echo "- new snapshot created $d"

if (Test-Path $temp_shadow_link) {
    "- $temp_shadow_link exists, deleting"
    cmd /c rmdir $temp_shadow_link
}

cmd /c mklink /d $temp_shadow_link $d
$shadow_snapshot_path = $target -ireplace "^C:", $temp_shadow_link

if (-Not (Test-Path $shadow_snapshot_path)) {
    throw "- not a valid shadow copy path"
}

echo "-------------------------------------------------------------------------------"
echo "CREATING ARCHIVE"
if (-NOT (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {
    throw "$env:ProgramFiles\7-Zip\7z.exe NEEDED!"
}
# 7zip in action
echo "- creating $temp_archive_path"
echo "- waiting for 7zip to finish..."
Start-Process -WindowStyle hidden -FilePath "$env:ProgramFiles\7-Zip\7z.exe" -ArgumentList "a","-snl","-mx=$compression_level","$temp_archive_path","$target" -Wait
echo "- done"

echo "-------------------------------------------------------------------------------"
echo "DELETING SHADOWCOPY SNAPSHOT AND THE LINK"
$s2.Delete()
echo "- the vss snapshot deleted"
cmd /c rmdir $temp_shadow_link
echo "- the link to the snapshot deleted"

Vssadmin list shadowstorage

echo "-------------------------------------------------------------------------------"
echo "MOVING THE ARCHIVE USING ROBOCOPY"
robocopy $env:TEMP $backup_path $archive_filename /MOVE /R:3 /np

$runtime = (Get-Date) - $script_start_date
$readable_runtime = "{0:dd} days {0:hh} hours {0:mm} minutes {0:ss} seconds" -f $runtime

echo " "
echo "#######              $readable_runtime              #######"
echo "################################################################################"
echo " "
