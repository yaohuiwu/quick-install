#!/bin/sh

fstatus='master_status.txt'

if [ $server_id -ne 1 ];then
    $bin_mysql -u root -p$root_password -s -e "show master status;" > $fstatus
    log_file=`awk '{print $1}' $fstatus`
	log_pos=`awk '{print $2}' $fstatus`

	echo "log file:$log_file"
	echo "log pos:$log_pos"
fi
