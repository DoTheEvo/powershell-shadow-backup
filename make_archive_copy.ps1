#
# zips content of $important_dir
# archive is created in %temp%
# named e.g. 2017-06-30_1497105218.zip
# then the file is moved to $backup_path
# $log_file is the desired location of the logs
# requires WMF 5.0+
#

$important_dir = "C:\test"
$backup_path = $env:HOMEPATH
$log_file = "$env:HOMEPATH\robocopy_log.txt"
$compression_level = "Fastest" # Optimal / Fastest / NoCompression

# ----------------------------------------------

$date = Get-Date -format yyyy-MM-dd
$unix_time = Get-Date -UFormat %s -Millisecond 0
$archive_filename = $date + "_" + $unix_time + ".zip"
$temp_archive_full_path = Join-Path -Path $env:TEMP -ChildPath $archive_filename

echo "------------------------------------------------------------------------------" >> $log_file
echo "CREATING ARCHIVE: $archive_filename `nIN $env:TEMP" >> $log_file

Compress-Archive -Path $important_dir -DestinationPath $temp_archive_full_path -CompressionLevel $compression_level -ErrorAction Stop

echo "------------------------------------------------------------------------------" >> $log_file
echo "MOVING THE FILE..." >> $log_file

robocopy $env:TEMP $backup_path $archive_filename /MOVE /R:3 /np >> $log_file

echo "------------------------------------------------------------------------------" >> $log_file
echo "ALL DONE" >> $log_file

# single line, packing at the destination
# Get-ChildItem $important_dir | Compress-Archive  -DestinationPath $backup_path\$archive_filename -Verbose
