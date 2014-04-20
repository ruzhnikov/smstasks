#!/usr/bin/env bash

# Script to install the smstasks

PATH_DIR="$(pwd)"
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


set -e
set -u


function chk_os {
    platform="unknown"
    unamestr=$(uname)
    # TODO: end the function
    if ! [ -e /etc/debian_version ]; then
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

function upgrade {
    # TODO: end the function
    echo "Success!"
    return 0
}

function install {
    # TODO: end the function
    echo "Success!"
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

echo -e "\nChecking required perl modules..."
$PERL $PATH_DIR/$ADDITIOANL_PATH/$CHK_DEP_SCRIPT

echo -e "\nChecking required programms..."

if chk_os
then
    missing_packages=0

    echo -ne " redis-server..."
    PKG_REDIS=$(dpkg-query -W --showformat='${Status}\n' redis-server|grep "install ok installed")
    PKG_REDIS_VERSION=$(dpkg-query -W --showformat='${Version}\n' redis-server )
    version_pattern="^[0-9]+\:2\.[68]"
    if [ "$PKG_REDIS" == "" ]; then
        missing_packages=`expr $missing_packages + 1`
        echo_fail
    else
        if [[ "$PKG_REDIS_VERSION" =~ $version_pattern ]]; then
            echo_ok
        else
            missing_packages=`expr $missing_packages + 1`
            echo_fail
            echo "version of redis-server must be >= 2.6"
        fi
    fi

    echo -ne " mysql-client..."
    PKG_MYSQL_CLIENT=$(dpkg-query -W --showformat='${Status}\n' mysql-client-*|grep "install ok installed" | uniq)
    PKG_MARIADB_CLIENT=$(dpkg-query -W --showformat='${Status}\n' mariadb-client-*|grep "install ok installed" | uniq)

    if [ "$PKG_MYSQL_CLIENT" == "" ]; then
        echo_fail
        echo -ne " mariadb-client..."
        if [ "$PKG_MARIADB_CLIENT" == "" ]; then
            missing_packages=`expr $missing_packages + 1`
            echo_fail
        else
            echo_ok
        fi
    else
        echo_ok
    fi

    if [ "$missing_packages" -gt "0" ]; then
        echo -e "\nFound not installed packages."
        echo "You need to install the missing packages and re-run the script install.sh"
        exit 1
    fi
fi

# echo -e "\nRunning the tests..."
# $PROVE $PATH_DIR/t/*

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