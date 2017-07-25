function add_24_hours_and_make_backup(){
    Set-Date (Get-Date).AddHours(+24)
    Start-ScheduledTask -TaskName "Shadowcopy Backup"
}

function add_24_hours_and_create_empty_file(){
    Set-Date (Get-Date).AddHours(+24)
    $date = Get-Date -format "yyyy-MM-dd"
    $unix_time = Get-Date -UFormat %s -Millisecond 0
    New-Item ("C:\backups\example_config_$date" + "_" + "$unix_time.zip") -type file
}

1..900 | % {
    add_24_hours_and_create_empty_file
    # add_24_hours_and_make_backup
    # while ((Get-ScheduledTask -TaskName 'Shadowcopy Backup').State  -ne 'Ready') {}
}

