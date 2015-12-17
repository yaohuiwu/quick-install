#!/bin/bash

. ./loader.sh
include ./tools/platform.sh

isd=$(is_debian)
isr=$(is_redhat)

if [ $isd -eq 1 ];then
	echo "use apt-get"
elif [ $isr -eq 1 ];then
	echo "use yum"
else
	echo "use nothin"
fi

tsoft='libaio'
if [ $isd -eq 1 ];then
	tsoft="${tsoft}1"
fi

install $tsoft

add_start_on_boot 'mysql.server'
