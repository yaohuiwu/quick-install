What is Quick Install ?
=======================

Quick Install is a project mainly aims at quickly installing common components like mysql 
with well configuration on linux platform in product environment, which ease a lot of pain 
of system manager. Most of the scripts are written in shell and python.

## Some principles

+ Prefer binary tar ball to rpm or apt packages.
+ Prefer getting software from local storage to network.
+ Zero configuration is needed.
+ Support reinstall.
+ Platform independent (unix like platform).

## Usage

1. How to install Mysql ?

	+ to install master:
			sudo ./installMysql.sh /path/to/mysql-5.6.20-linux-glibc2.5-x86_64.tar.gz
	
	+ to install a slave:
			sudo ./installMysql.sh /path/to/mysql-5.6.20-linux-glibc2.5-x86_64.tar.gz 2 master_ip

## Tested platforms

+ Mysql 5.6.20

	+ Ubuntu 12.10
	+ CentOS 7
