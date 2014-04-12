#!/bin/bash

# Script to install the smstasks

PATH_DIR="$(pwd)"
PURPOSE_DIR="/opt"
PROGRAM_NAME="smstasks"
ADDITIOANL_PATH="additional_scripts"
CHK_DEP_SCRIPT="check_depending.pl"
PERL="/usr/bin/perl"


set -e
set -u

function chk_fail {
    if [ "$1" -ne 0 ]; then
        echo -e "\nLast process return error, program will terminate...\n"
        exit 1
    fi
}

function chk_os {
    if ! [ -e /etc/debian_version ]; then
        echo "Your operation system are not Debian based. You must manually set the following programs:"
        echo -e "Redis-server (>=2.6.12)\nMysql or MariaDB\n"
        return 1
    else
        return 0
    fi
}

echo -e "\nChecking required perl modules...\n"
$PERL $PATH_DIR/$ADDITIOANL_PATH/$CHK_DEP_SCRIPT

echo -e "\nChecking required programms...\n"

missing_packages=0

if chk_os
then
    echo -ne "Checking redis-server...\t"
    PKG_REDIS=$(dpkg-query -W --showformat='${Status}\n' redis-server|grep "install ok installed")
    if [ "$PKG_REDIS" == "" ]; then
        missing_packages=`expr $missing_packages + 1`
        echo "[fail]"
    else
        echo "[ok]"
    fi

    echo -ne "Checking mysql-server...\t"
    PKG_MYSQL=$(dpkg-query -W --showformat='${Status}\n' mysql-server-*|grep "install ok installed" | uniq)
    PKG_MARIADB=$(dpkg-query -W --showformat='${Status}\n' mariadb-server-*|grep "install ok installed" | uniq)
    
    if [ "$PKG_MYSQL" == "" ]; then
        echo "[fail]"
        echo -ne "Checking mariadb-server...\t"
        if [ "$PKG_MARIADB" == "" ]; then
            missing_packages=`expr $missing_packages + 1`
            echo "[fail]"
        else
            echo "[ok]"
        fi
    else
        echo "[ok]"
    fi

    if [ "$missing_packages" -gt "0" ]; then
        echo "found not installed packages."
        echo "You need to install the missing packages and re-run the script install.sh"
        exit 1
    fi
fi

echo -e "\nInstallation...\n"
echo -e "Checking the previous version...\n"

# проверяем ранее установленную версию
# ...

exit 0