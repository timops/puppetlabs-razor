#!/bin/bash

set -e

SITE='http://apt.puppetlabs.com/'
REMOTE_FILE='puppetlabs-release-precise.deb'
INSTALL=1
DPKG_ARGS='-i'
RESULT=0

# prerequisite packages
OTHER_PKGS='curl git unzip'

# retrieve repo dpkg from puppetlabs
function dl()
{
  if [ -z $3 ]; then
    curl -O $1$2
  else
    curl -O $1$2 -x $3
  fi
}

# install repo configurator
function install()
{
  dpkg $1 $2
}

function help()
{
  echo 'shell script to deploy and execute initial puppet run'
  echo 'currently only supports ubuntu 12.04'
  echo ''
  echo 'puppet_install.sh [-dhp]'
  echo ''
  echo '-d: download (deb) only'
  echo '-h: help'
  echo '-p: url of proxy server (for curl)'
  echo '-b: name of the puppet zipfile to bootstrap from'
  echo '-r: re-run puppet client'
  echo ''
}

function prereqs_install()
{
  apt-get update -yq
  apt-get install $1 -yq
}

function agent_install()
{
  apt-get update -yq
  apt-get install unzip git puppet -yq
}

# extract modules and depedent manifests in current directory, then invoke the run
function puppet_run()
{
    if [ -d $PWD/$2 ]; then
      echo "[INFO]: manifest directory already exists, skipping extraction..."
    else
      unzip -qq $1 -d $PWD
    fi
    puppet apply  --modulepath=$PWD/$2/modules $PWD/$2/manifests/default.pp
}

# if no options a specified the script will perform download AND install
while getopts "b:p:dhr:" OPT
do
  case $OPT in
    h) help; exit 2;;
    d) INSTALL=0;;
    p) PROXY=$OPTARG;;
    b) BOOTSTRAP=$OPTARG;;
    r) BOOTSTRAP="${OPTARG}.zip"; PUPDIR=$OPTARG; puppet_run $BOOTSTRAP $PUPDIR; exit $?;;
    *) echo 'invalid syntax'; help;;
  esac
done

prereqs_install $OTHER_PKGS
dl $SITE $REMOTE_FILE $PROXY

if [ $INSTALL -eq 1 ]; then
  install $DPKG_ARGS $REMOTE_FILE
  agent_install
  if [ $BOOTSTRAP ]; then
    PUPDIR=${BOOTSTRAP/%.[a-z]*}
    puppet_run $BOOTSTRAP $PUPDIR
  fi
fi
