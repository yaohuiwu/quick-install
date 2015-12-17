#!/bin/bash

DIST_UBUNTU='Ubuntu'
DIST_CENTOS='CentOS Linux'
DIST_FEDORA='Fedora'

debian_series=( $DIST_UBUNTU )
redhat_series=("$DIST_CENTOS" $DIST_FEDORA)

is_debian(){
	distnm=`python tools/dist.py`
	for dist in "${debian_series[@]}"
	do
		if [ "$dist" = "$distnm" ]
		then
			echo 1 
			return 0
		fi
	done
	echo 0
}

is_redhat(){
	distnm=`python tools/dist.py`
	for dist in "${redhat_series[@]}"
	do
		if [ "$dist" = "$distnm" ]
		then
			echo 1 
			return 0
		fi
	done
	echo 1
}

add_start_on_boot(){
	echo "add start on boot $1"
    if [ $(is_debian) -eq 1 ];then
		update-rc.d -f $1 defaults
    elif [ $(is_redhat) -eq 1 ];then
		chkconfig --add $1 
		chkconfig $1 on
    else
        echo 'No service tools'
    fi 
}

del_start_on_boot(){
    echo "del start on boot $1"
    if [ $(is_debian) -eq 1 ];then
        update-rc.d -f $1 remove
    elif [ $(is_redhat) -eq 1 ];then
        chkconfig --del $1
    else
        echo 'No service tools'
    fi
}

install(){
	if [ $1 = '' ];then
		return
	fi
	echo "installing soft $1"
	if [ $(is_debian) -eq 1 ];then
		apt-get install -y --force-yes $1
	elif [ $(is_redhat) -eq 1 ];then
		yum install -y $1
	else
		echo 'No install tools'
	fi
}

uninstall(){
	if [ $1 = '' ];then
        return
    fi  
    echo "uninstalling soft $1"
    if [ $(is_debian) -eq 1 ];then
        apt-get remove -y $1
    elif [ $(is_redhat) -eq 1 ];then
        yum remove -y --nodeps $1
    else
        echo 'No uninstall tools'
    fi 
}
