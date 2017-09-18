$where_to_make_backups = "C:\"
$backup_title = "test"

function add_24_hours_and_create_empty_file(){
    Set-Date (Get-Date).AddHours(+24)
    $date = Get-Date -format "yyyy-MM-dd"
    $unix_time = Get-Date -UFormat %s -Millisecond 0
    $final_path = $where_to_make_backups +"/" + $backup_title + "_" + $date + "_" + $unix_time + ".zip"
    echo $final_path
    New-Item ($final_path) -type file
}

1..90 | % {
    add_24_hours_and_create_empty_file
}

# -------------------------------------------------------------------------------------------------

# $scheduled_task_name = "Shadowcopy_Backup_test"

# function add_24_hours_and_make_backup(){
#     Set-Date (Get-Date).AddHours(+24)
#     Start-ScheduledTask -TaskName $scheduled_task_name
# }

# 1..97 | % {
#     add_24_hours_and_make_backup
#     while ((Get-ScheduledTask -TaskName $scheduled_task_name).State  -ne 'Ready') {}
# }
