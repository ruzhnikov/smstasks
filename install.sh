#!/usr/bin/env bash

# Script to install the smstasks

PATH_DIR=$(pwd)
PURPOSE_DIR="/opt"
PROGRAM_NAME="smstasks"
ADDITIOANL_PATH="additional_scripts"
CHK_DEP_SCRIPT="check_depending.pl"

PERL=$(which perl)
PROVE=$(which prove)

CONFIG_DIR="/etc/smstasks"
CONFIG_NAME="smstasks.conf"

SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

SMSTASKS_VERSION=$($PERL bin/$PROGRAM_NAME.pl --version)
MD5SUM=$(which md5sum)

INIT_SCRIPT=""
INIT_DIR=""
if [ "$(uname)" == "Linux" ]; then
    INIT_DIR="/etc/init.d"
    if [ -e /etc/lsb-release ]; then
        INIT_SCRIPT="linux.lsb"
    else
        INIT_SCRIPT="linux"
    fi
elif [ "$(uname)" == "FreeBSD" ]; then
    INIT_DIR="/etc/rc.d"
    INIT_SCRIPT="freebsd"
fi

INIT_SCRIPT="$PATH_DIR/init/$PROGRAM_NAME.$INIT_SCRIPT"

DEFAULT_LOGDIR="/var/log/smstasks"

set -e
set -u

function chk_deb_os {
    if ! [ -e /etc/debian_version ]; then
        return 0
    else
        return 1
    fi
}

function chk_os {
    if chk_deb_os
    then
        echo "Your operation system are not Debian based. You must manually set the following programs:"
        echo "Redis-server (>=2.6.12)"
        echo "Mysql-client or MariaDB-client"
        echo -e "Mysql-server or MariaDB-server (if necessary)\n"
        return 1
    else
        return 0
    fi
}

function echo_fail {
    $SETCOLOR_FAILURE
    echo -n "$(tput hpa $(tput cols))$(tput cub 6)[fail]"
    $SETCOLOR_NORMAL
    echo
}

function echo_ok {
    $SETCOLOR_SUCCESS
    echo -n "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
    $SETCOLOR_NORMAL
    echo
}

function chk_mysql {
    my_host=$1
    my_dbname=$2
    my_user=$3
    my_pass=$4

    set +e

    mysql_auth="--user=$my_user --password=$my_pass --host=$my_host --database=$my_dbname"
    for i in 1 2 3
    do
        echo -ne "\nChecking MySQL connection..."
        mysql $mysql_auth -e "exit" 2>/dev/null
        dbstatus=$(echo $?)
        if [ $dbstatus -ne 0 ]; then
            echo_fail
            echo -ne "\nCan't connect"
            if [ $i -lt 3 ]; then
                echo ", please retry"
            else
                echo ", exit"
                return 1
            fi
        else
            echo_ok
            return 0
        fi
    done
}

function load_sql {
    my_host=$1
    my_dbname=$2
    my_user=$3
    my_pass=$4

    mysql_auth="--user=$my_user --password=$my_pass --host=$my_host --database=$my_dbname"

    echo "Load tables: "

    set +e

    for file in $PATH_DIR/sql/*sql
    do
        echo -n $file
        mysql $mysql_auth -e "source $file;" 2>/dev/null
        loadstatus=$(echo $?)
        if [ $loadstatus -ne 0 ]; then
            echo_fail
            echo -ne "\nCan't load table $file, exit"
            return 1
        else
            echo_ok
        fi
    done

    return 0
}

function mk_log {
    if ! [[ -e "$DEFAULT_LOGDIR" && -d "$DEFAULT_LOGDIR" ]]; then
        mkdir -p $DEFAULT_LOGDIR
    fi
}

function upgrade {
    /etc/init.d/$PROGRAM_NAME stop

    # check the init-script
    md5_cur=$($MD5SUM $INIT_DIR/$PROGRAM_NAME | awk '{print $1}' )
    md5_new=$($MD5SUM $INIT_SCRIPT | awk '{print $1}' )
    if [ "$md5_cur" != "$md5_new" ]; then
        cp $INIT_SCRIPT $INIT_DIR/$PROGRAM_NAME
    fi

    rm -fr $PURPOSE_DIR/$PROGRAM_NAME/lib
    cp -r $PATH_DIR/lib $PURPOSE_DIR/$PROGRAM_NAME/

    rm $PURPOSE_DIR/$PROGRAM_NAME/bin/$PROGRAM_NAME.pl
    cp $PATH_DIR/bin/$PROGRAM_NAME.pl $PURPOSE_DIR/$PROGRAM_NAME/bin/

    mk_log

    echo "Success!"
    return 0
}

function install {
    echo -n "Enter Mysql host [127.0.0.1]: "
    read my_host
    if [ "$my_host" == "" ]; then
        my_host="127.0.0.1"
    fi

    echo -n "Enter Mysql username: "
    read my_user

    echo -n "Enter Mysql password: "
    read -s my_pass

    echo -ne "\nEnter DB name [smstasks]: "
    read my_dbname
    if [ "$my_dbname" == "" ]; then
        my_dbname="smstasks"
    fi

    chk_mysql $my_host $my_dbname $my_user $my_pass
    if [ $? -eq 1 ]; then
        return 1
    fi

    load_sql $my_host $my_dbname $my_user $my_pass
    if [ $? -eq 1 ]; then
        return 1
    fi

    if ! [ -e $CONFIG_DIR ]; then
        mkdir $CONFIG_DIR
    fi

    cp -f $PATH_DIR/conf/$CONFIG_NAME $CONFIG_DIR/
    sed -ir "s/name\s*=.*/name = $my_dbname/" $CONFIG_DIR/$CONFIG_NAME
    sed -ir "s/host\s*=.*/host = $my_host/" $CONFIG_DIR/$CONFIG_NAME
    sed -ir "s/user\s*=.*/user = $my_user/" $CONFIG_DIR/$CONFIG_NAME
    sed -ir "0,/password/s/password\s*=.*/password = $my_pass/" $CONFIG_DIR/$CONFIG_NAME

    mkdir -p $PURPOSE_DIR/$PROGRAM_NAME
    cp -r $PATH_DIR/lib $PURPOSE_DIR/$PROGRAM_NAME/
    cp -r $PATH_DIR/bin $PURPOSE_DIR/$PROGRAM_NAME/
    cp $INIT_SCRIPT $INIT_DIR/$PROGRAM_NAME

    if chk_deb_os
    then
        insserv -f -d $PROGRAM_NAME
    fi

    mk_log

    echo -e "\nSuccess!"
    return 0
}

function exit_ok {
    echo "All operations were successfully completed"
    exit 0
}

function exit_fail {
    echo "One of the operations has failed"
    echo "the installation will fail"
    exit 1
}

function chek_purpose_dir {
    if [[ -e "$PURPOSE_DIR/$PROGRAM_NAME" &&
        -d "$PURPOSE_DIR/$PROGRAM_NAME" ]]
    then
        return 0
    else
        return 1
    fi
}

check_user=$( id -u )
if [ $check_user -ne 0 ]; then
    echo "!!! This program must be run as root or sudo !!!"
    exit 1
fi

echo -e "\nChecking required perl modules..."
$PERL $PATH_DIR/$ADDITIOANL_PATH/$CHK_DEP_SCRIPT

echo -e "\nChecking required programms..."

if chk_os
then
    missing_packages=0

    echo -ne " redis-server..."
    PKG_REDIS=$(dpkg --get-selections redis-server| wc -l)
    version_pattern="^[0-9]+\:2\.[68]"
    if [ $PKG_REDIS -eq 0 ]; then
        missing_packages=`expr $missing_packages + 1`
        echo_fail
    else
        PKG_REDIS_VERSION=$(dpkg-query -W --showformat='${Version}\n' redis-server )
        if [[ "$PKG_REDIS_VERSION" =~ $version_pattern ]]; then
            echo_ok
        else
            missing_packages=`expr $missing_packages + 1`
            echo_fail
            echo "version of redis-server must be >= 2.6"
        fi
    fi

    echo -ne " mysql-client..."
    PKG_MYSQL_CLIENT=$(dpkg --get-selections mysql-client-*| wc -l)

    if [ $PKG_MYSQL_CLIENT -eq 0 ]; then
        echo_fail
        echo -ne " mariadb-client..."
        PKG_MARIADB_CLIENT=$(dpkg --get-selections mariadb-client-*| wc -l)
        if [ $PKG_MARIADB_CLIENT -eq 0 ]; then
            missing_packages=`expr $missing_packages + 1`
            echo_fail
        else
            echo_ok
        fi
    else
        echo_ok
    fi

    if [ $missing_packages -gt 0 ]; then
        echo -e "\nFound not installed packages."
        echo "You need to install the missing packages and re-run the script install.sh"
        exit 1
    fi
fi

echo -e "\nRunning the tests..."
$PROVE $PATH_DIR/t/*

echo -e "\nChecking the previous version..."
if chek_purpose_dir
then
    echo "Found directory $PURPOSE_DIR/$PROGRAM_NAME"

    if [ -e "$PURPOSE_DIR/$PROGRAM_NAME/bin/$PROGRAM_NAME.pl" ]; then
        cur_version=$(grep 'my $VERSION' $PURPOSE_DIR/$PROGRAM_NAME/bin/$PROGRAM_NAME.pl | sed -r 's/^.*([0-9]+\.[0-9]+).*$/\1/')
        echo "A previous version of $PROGRAM_NAME has been detected on this system"
        echo "Current version of $PROGRAM_NAME: $cur_version"
        echo "New version: $SMSTASKS_VERSION"
    fi

    while [ true ]
    do
        echo "Do you want to update program? [Y/n]: "
        read item
        case "$item" in
            y|Y) upgrade
                case "$?" in
                    0) exit_ok  ;;
                    *) exit_fail ;;
                esac
                ;;
            n|N) echo "Break"
                exit 0
                ;;
        esac
    done
else
    echo -e "Previously installed versions of the program not found\n"
    echo "Installation..."
    install
    case "$?" in
        0) exit_ok ;;
        *) exit_fail ;;
    esac
fi

exit 0
