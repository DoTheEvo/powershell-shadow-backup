#
# backups $important_dir as a zip archive to $backup_path
# uses volume shadowcopy service to also backup opened files
# the partition needs to be C:\
# requires WMF 5.0
#

$important_dir = "C:\test"
$backup_path = $env:HOMEPATH
$log_file = "$env:HOMEPATH\robocopy_log.txt"
$compression_level = "NoCompression" # Optimal / Fastest / NoCompression

# ----------------------------------------------

$temp_shadow_link = "C:\shadowcopy23412"
$date = Get-Date -format yyyy-MM-dd
$unix_time = Get-Date -UFormat %s -Millisecond 0
$archive_filename = $date + "_" + $unix_time + ".zip"
$temp_archive_path = Join-Path -Path $env:TEMP -ChildPath $archive_filename

$t = Get-Date -format yyyy-MM-dd_HH:mm:ss
echo "###################################   $t   ###################################" >> $log_file
echo "CREATING NEW SHADOWCOPY SNAPSHOT" >> $log_file

$s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
$s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
$d  = $s2.DeviceObject + "\"

if (Test-Path $temp_shadow_link) {
    echo "$temp_shadow_link EXISTS, DELETING" >> $log_file
    cmd /c rmdir $temp_shadow_link
}

cmd /c mklink /d $temp_shadow_link $d >> $log_file
$shadow_orig_dir = $important_dir -replace "^C:", $temp_shadow_link

if (-Not (Test-Path $shadow_orig_dir)) {
    echo $shadow_orig_dir >> $log_file
    echo "NOT A VALID SHADOW COPY PATH" >> $log_file
    exit
}

echo "-------------------------------------------------------------------------------" >> $log_file
echo "CREATING ARCHIVE: $archive_filename `nIN $env:TEMP" >> $log_file
Compress-Archive -Path $shadow_orig_dir -DestinationPath $temp_archive_path -CompressionLevel $compression_level -ErrorAction Stop

echo "-------------------------------------------------------------------------------" >> $log_file
echo "DELETING SNAPSHOT AND THE LINK TO IT" >> $log_file
$s2.Delete()
cmd /c rmdir $temp_shadow_link

Vssadmin list shadowstorage >> $log_file

echo "-------------------------------------------------------------------------------" >> $log_file
echo "MOVING THE ARCHIVE..." >> $log_file
robocopy $env:TEMP $backup_path $archive_filename /MOVE /R:3 /np >> $log_file

echo "-------------------------------------------------------------------------------" >> $log_file
$t = Get-Date -format yyyy-MM-dd_HH:mm:ss
echo "ALL DONE   $t   ALL DONE`n " >> $log_file