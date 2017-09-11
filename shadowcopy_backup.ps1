# ------------------------------------------------------------------------------
# -----------------------------   SHADOWCOPY_BACKUP   --------------------------
# ------------------------------------------------------------------------------
# - requirements: 7-zip, WMF 5.0+, Volume Shadow Copy (VSS) service enabled
# - this script backups $target as a zip archive to $backup_path
# - uses volume shadowcopy service to also backup opened files
#
# ----  values expected in config txt file  ----
#
# target=C:\test
# backup_path=C:\
# compression_level=0
# delete_old_backups=true
# keep_last_n=5
# keep_monthly=true
# keep_weekly=true

# ----------------------------------------------

# get full path to config txt file passed as parameter, throw error if theres none
Param( [string]$config_txt_path=$(throw "config file is mandatory, please provide as parameter.") )
$config_txt_fullpath = Resolve-Path -Path $config_txt_path
$config_txt_file_name = (Get-Item $config_txt_fullpath).name
$pure_config_name = $config_txt_file_name.Substring(0,($config_txt_file_name.Length)-11)

# start loging in to a log file, named samed as the config file
$log_file_name = $pure_config_name + ".log"
$log_file_full_path = Join-Path -Path $PSScriptRoot -ChildPath "logs" | Join-Path -ChildPath $log_file_name
Start-Transcript -Path $log_file_full_path -Append -Force

# read the content of the config file, ignore lines starting with #, rest load as variables
Get-Content $config_txt_fullpath | Foreach-Object{
    if (-NOT $_.StartsWith("#")){
        $var = $_.Split('=')
        # load preset variables as booleans
        if (@('delete_old_backups','keep_monthly','keep_weekly') -contains $var[0]) {
            New-Variable -Name $var[0] -Value  ($var[1] -eq $true)
        # load what looks like numbers as integers
        } ElseIf ($var[1] -match "^[\d\.]+$") {
            $integer_version = [convert]::ToInt32($($var[1]), 10)
            New-Variable -Name $var[0] -Value $integer_version
        # rest as string
        } else {
            New-Variable -Name $var[0] -Value $var[1]
        }
    }
}

# some variables used through out the script
$ErrorActionPreference = "Stop"
$script_start_date = Get-Date
$date = Get-Date -format "yyyy-MM-dd"
$unix_time = Get-Date -UFormat %s -Millisecond 0
$archive_filename = $pure_config_name + "_" + $date + "_" + $unix_time + ".zip"
$temp_shadow_link = "C:\ProgramData\shadowcopy_backup\shadowcopy_link"
$temp_archive_path = Join-Path -Path "C:\ProgramData\shadowcopy_backup" -ChildPath $archive_filename

$t = Get-Date -format "yyyy-MM-dd || HH:mm:ss"
echo " "
echo "################################################################################"
echo "#######                      $t                      #######"
echo " "
echo "- user: $(whoami)"
echo "- target: $target"
echo "- target partition: $target_partition"
echo "- backup to destination: $backup_path"
echo "- compression_level: $compression_level"
echo "- delete_old_backups: $delete_old_backups"
echo "- keep_last_n: $keep_last_n"
echo "- keep_monthly: $keep_monthly"
echo "- keep_weekly: $keep_weekly"

# running with admin privilages check
$running_as_admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT $running_as_admin){
    throw "NOT RUNNING AS ADMIN, THE END"
}
# check if $target path exists on the system
if (-NOT (Test-Path $target)) {
    throw "NOT A VALID TARGET PATH: " + $target
}
# check if $backup_path path exists on the system
if (-NOT (Test-Path $backup_path)) {
    throw "NOT A VALID BACKUP PATH: " + $backup_path
}

echo "-------------------------------------------------------------------------------"
echo "CREATING NEW SHADOWCOPY SNAPSHOT"

# get the letter of the partition of the target, like - "C:\"
$target_partition = $target.Substring(0,3)
# same as above just without backslash, like - "C:"
$target_partition_no_slash = $target.Substring(0,2)

$s1 = (Get-WmiObject -List Win32_ShadowCopy).Create($target_partition, "ClientAccessible")
$s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
$d  = $s2.DeviceObject + "\"

echo "- new snapshot created $d"

if (Test-Path $temp_shadow_link) {
    echo "- $temp_shadow_link exists, deleting"
    cmd /c rmdir $temp_shadow_link
}

cmd /c mklink /d $temp_shadow_link $d
$shadow_snapshot_target_path = $target -ireplace "^$target_partition_no_slash", $temp_shadow_link
$shadow_snapshot_target_path
if (-Not (Test-Path $shadow_snapshot_target_path)) {
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
echo "- the VSS snapshot deleted"
cmd /c rmdir $temp_shadow_link
echo "- the link to the snapshot deleted"

Vssadmin list shadowstorage

echo "-------------------------------------------------------------------------------"
echo "MOVING THE ARCHIVE USING ROBOCOPY"
robocopy "C:\ProgramData\shadowcopy_backup" $backup_path $archive_filename /MOVE /R:3 /np

echo "-------------------------------------------------------------------------------"
echo "DELETING OLD BACKUPS"

if ($delete_old_backups -eq $true) {
    # get list of old backups at the $backup_path
    # wrapping with @() to always get list and not just object when its single item
    $all_previous_backups = Get-ChildItem -Path "$backup_path\$pure_config_name*.zip"
    $sorted_by_cration_date = @($all_previous_backups | Sort-Object -Descending CreationTime)
    echo "- backups on the disk: $($sorted_by_cration_date.count)"

    $backups_to_keep = @()

    # always at least 1 backup
    if ($keep_last_n -lt 1) {Set-Variable -Name "keep_last_n" -Value 1}
    echo "- keeping last: $keep_last_n backups"

    # keeping the set number of backups
    for ($i = 0; $i -lt $keep_last_n; $i++) {
        $backups_to_keep += $sorted_by_cration_date[$i].FullName
    }

    # serparate by year
    $years_separates = @{}
    foreach($i in $sorted_by_cration_date) {
        $years_separates[(get-date $i.CreationTime -format "yyyy")] += ,$i
    }

    function month_week_cleanup_per_year(){
        Param( [array]$file_list, [boolean]$one_a_week, [boolean]$one_a_month )
        # hashtables are used to get only single file per month or week
        $keeping_this_files = @()
        $month_hashtable = @{}
        $week_hashtable = @{}
        foreach($i in $file_list) {
            $month_hashtable[($i.CreationTime).Month] = $i.FullName
            $week_hashtable[(get-date $i.CreationTime -UFormat %V)] = $i.FullName
        }

        if ($one_a_week -eq $true) {
            foreach($i in $week_hashtable) {
                $keeping_this_files += $i.Values
            }
        }
        if ($one_a_month -eq $true) {
            foreach($i in $month_hashtable) {
                $keeping_this_files += $i.Values
            }
        }

        return $keeping_this_files
    }

    foreach($i in $years_separates.Keys) {
        $backups_to_keep += month_week_cleanup_per_year $years_separates[$i] $keep_weekly $keep_monthly
    }
    $backups_to_keep
    # actual deletion of old backups
    foreach($i in $sorted_by_cration_date) {
        if (-NOT ($backups_to_keep -contains $i.FullName)){
            Remove-Item $i.FullName
            echo "- $($i.FullName) deleted"
        }
    }
} else {
    echo "- deletion is disabled"
}

$runtime = (Get-Date) - $script_start_date
$readable_runtime = "{0:dd} days {0:hh} hours {0:mm} minutes {0:ss} seconds" -f $runtime

echo " "
echo "#######              $readable_runtime              #######"
echo "################################################################################"
echo " "
