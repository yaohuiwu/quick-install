#!/bin/bash
usage='用法: （以root用户执行） sudo ./installMysql.sh [/path/to/mysql.tar.gz] [server id(optional)] [master ip (optional)]'
#'server id: set 1 if installing master, other number if installing slaves'
if [ $# -eq 0 ];then
	echo $usage
	exit 0;
fi

. ./loader.sh
include ./tools/platform.sh
quick_dir=$PWD
server_id='1'
master_ip=''

repl_user='repl'
repl_pass='p4ssword'
repl_network='192.168.%.%'

echo "mysql tar file :$1"
if [ $# -gt 1 ] ; then
	server_id=$2
fi
if [ $# -gt 2 ];then
	master_ip=$3
fi

_F=`expr match $1 '.*/\(.*.tar.[gx]z\)'`
_D=`expr match $_F '\(.*\).tar.[gx]z'`
echo "dir of mysql after unzip:$_D"

VERSION=5.6.20
OS=linux-glibc2.5-x86_64

mysql_home=/usr/local/soft/mysql/mysql
normal_home=/usr/local/mysql

normal_admin=$normal_home/bin/mysqladmin
bin_mysqladmin=$mysql_home/bin/mysqladmin

if [ `ps -aux |  awk '{if($11 ~ /mysqld/ ) print $11}'` ] ; then 
	echo "mysql 正在运行, 是否关闭mysql?[Y/n]"
	read closeMysql
	if [ $closeMysql = 'Y' ]; then
		if [ -e $normal_admin ];then
			$normal_admin -u root -p shutdown
			echo "mysql已关闭"
		else
			if [ -e $bin_mysqladmin ];then
				$bin_mysqladmin -u root -p shutdown
				echo "mysql已关闭"
			else
				echo "找不到mysqladmin，请手动停止mysql。"
				exit 0
			fi
		fi
	else
		exit 0
	fi
fi

isd=$(is_debian)
aio='libaio'
if [ $isd -eq 1 ];then
    aio="${aio}1"
fi

install $aio

if [ -z `cat /etc/group | awk -F: '{if($1 ~ /mysql/) print $1}'` ] ; then
	groupadd mysql
else
	echo "用户组mysql已存在"
fi

if [ -z  `cat /etc/passwd | awk -F: '{if($1 ~ /mysql/) print $1}'` ] ; then
	useradd -r -g mysql mysql
else
	echo "用户mysql已存在"
fi

soft_dir=/usr/local/soft
if [ ! -e $soft_dir ];then 
	sudo mkdir -p $soft_dir
	chmod 777 $soft_dir
fi
cd $soft_dir
if [ -e "mysql" ] ; then
	echo "删除$PWD/mysql"
	sudo rm -rf ./mysql 
fi 

mkdir mysql

###################官方文档的安装步骤#################
cd mysql
echo "正在解压..."
tar zxf $1 -C $PWD
ln -s $_D mysql
cd mysql
chown -R mysql .
chgrp -R mysql .
scripts/mysql_install_db --user=mysql
chown -R root .
chown -R mysql data

echo "配置my.cnf"
if [ ! -e my.cnf ] ; then 
	echo "my.cnf不存在"
	exit 0
fi

sed -i '/\[mysqld\]/ a\bind-address=0.0.0.0 \
lower_case_table_names=1 	\
character-set-server=utf8 	\
collation-server=utf8_general_ci \
max_connections=1000 \
log_bin=mysql-bin \
server_id='${server_id}'' my.cnf

sed -i '/\[mysqld\]/ a\basedir='$mysql_home'' my.cnf

if [ $server_id -ne 1 ];then
	sed -i '/\[mysqld\]/ a\relay_log=mysql-relay-bin \
log_slave_updates=1 \
read_only=1' my.cnf
fi

sed	-i '$ a\[client] \
default_character_set=utf8' my.cnf

#bin/mysqld_safe --user=mysql &

if [ -e /etc/init.d/mysql.server ]; then
	echo "删除/etc/init.d/mysql.server"
	rm -rf /etc/init.d/mysql.server
fi
# Next command is optional
if [ -e /etc/my.cnf ];then
	echo "删除/etc/my.cnf"
	rm -rf /etc/my.cnf
fi
cp my.cnf /etc
cp support-files/mysql.server /etc/init.d/mysql.server

s_name='mysql.server'
last_dir=$PWD
cd $quick_dir
del_start_on_boot $s_name
add_start_on_boot $s_name
cd $last_dir
######################################################

sudo /etc/init.d/mysql.server start
sudo /etc/init.d/mysql.server status

echo "Do you want to config security of mysql ? [y/n]"
read is_ensure_security
if [ $is_ensure_security = 'y' ];then
	bin/mysql_secure_installation
fi

bin_mysql=bin/mysql

echo "设置root远程访问"
read -s -p "Enter root password:" root_password 
$bin_mysql -u root -p$root_password -e "GRANT ALL PRIVILEGES ON *.* TO root@'%' IDENTIFIED BY '"$root_password"';flush PRIVILEGES;"

echo "创建本地复制帐号"
$bin_mysql -u root -p$root_password -e "GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO ${repl_user}@'${repl_network}' IDENTIFIED BY '${repl_pass}';FLUSH PRIVILEGES;"

if [ $server_id -ne 1 -a  -n "$master_ip" ] ; then
	echo '配置slave复制'
	fmstatus='mstatus.txt'
	$bin_mysql -u root -p$root_password -h $master_ip -s -e "show master status;" | grep "mysql-bin" > $fmstatus
	log_file=`awk '{print $1}' $fmstatus`
	log_pos=`awk '{print $2}' $fmstatus`

	echo "master log-> log file:$log_file log pos:$log_pos"

	if [ -n "$log_file" -a -n "$log_pos" ];then
		change_master_cmd="CHANGE MASTER TO MASTER_HOST='${master_ip}', MASTER_USER='${repl_user}', MASTER_PASSWORD='${repl_pass}', MASTER_LOG_FILE='${log_file}', MASTER_LOG_POS=${log_pos};"
		$bin_mysql -u root -p$root_password -e "$change_master_cmd"
		echo "Start slave now?(y/n)"
		read is_start_now
		if [ $is_start_now = 'y' ];then
			echo "开启复制"
			$bin_mysql -u root -p$root_password -e "start slave;"
			echo "验证复制"
			echo "在master: ${master_ip}中创建数据库mydb，表t（包含整型列num）,写入行1"
			test_db='mydb'
			test_t='t'
			$bin_mysql -u root -p$root_password -h $master_ip -e "drop database if exists ${test_db}; create database ${test_db}; use ${test_db}; create table if not exists ${test_t} (num int); insert into ${test_t}(num) values(1);" 
			sleep 0.1 
			echo "0.1秒后，在slave中查询"
			$bin_mysql -u root -p$root_password -e "select * from ${test_db}.${test_t};"
			echo "清理测试"
			$bin_mysql -u root -p$root_password -h $master_ip -e "drop database if exists ${test_db};"
		fi
	else
		echo "不能配置slave复制：无法得到日志文件和位置。"
	fi

	#rm status file finally
	rm -rf $fmstatus
fi

ver=`$bin_mysql --version`
echo "VERSION: $ver"
echo "安装成功。Mysql安装在$mysql_home 。"

