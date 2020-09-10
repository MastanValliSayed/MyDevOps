#!/bin/sh

function createDir() {
DIR=${1}
if [ ! -d "$DIR" ]; then
echo "Creating directory: $DIR." >> ${STD_OUT}
mkdir -p $DIR
else
echo "$DIR already exists." >> ${STD_OUT}
fi
echo >> ${STD_OUT}
}

# Creates a file as jboss and sets necessary permissions
function createFile() {
# $1 - File path

touch "${1}"
chown jboss:jboss "${1}"
chmod 775 "${1}"
}

function fCopy()
{
	echo "#####################################################################"
	CURRENT_PATH=`pwd`
	echo "Current Path: $CURRENT_PATH"
	echo "Step 1: Checking source directory"
	ls -ld $1
	if [ $? -eq 0 ] && [ -n "$1" ];then
		SOURCE_DIR=$1
	else
		echo "	ERROR: Source directory $1 is not existing"
		echo "*********************************************************************"
		return 1
	fi
	
	echo "Step 2: Checking destination directory"
	ls -ld $2
	if [ $? -eq 0 ] && [ -n "$2" ];then
		DEST_DIR=$2
	else
		echo "	ERROR: Destination directory $2 is not existing"
		echo "*********************************************************************"
		return 2
	fi
	
	cp -pR $SOURCE_DIR $DEST_DIR
	
	if [ $? -eq 0 ];then
		echo "Step 3: Sccussful to execute cp -pR $SOURCE_DIR $DEST_DIR"
	else
		echo "	ERROR: Failed to execute cp -pR $SOURCE_DIR $DEST_DIR"
		echo "*********************************************************************"
		return 0
	fi
	
	chown -R jboss:jboss $DEST_DIR
	OWN_FLAG=$?
	
	chmod -R 775 $DEST_DIR
	MOD_FLAG=$?
	
	if [ $OWN_FLAG -eq 0 ] && [ $MOD_FLAG -eq 0 ];then
		echo "Step 4: Sccussful to change permission"
		ls -ld $DEST_DIR
	else
		echo "	ERROR: Failed to change permission for Destination directory $DEST_DIR"
		echo "*********************************************************************"
		return 0
	fi
	
	echo "#####################################################################"
	return 0
}

function checkEnvironment()
{
	# parameter
	# $1 - SIT server list
	# $2 - UAT server list
	# $3 - PROD server list
	
	SIT_SERVERS=`eval echo '$'$1`
	UAT_SERVERS=`eval echo '$'$2`
	PRD_SERVERS=`eval echo '$'$3`
	ENV_TMP=""
	
	if [ ${ENV_TMP}X != "UATX" ] && [ ${ENV_TMP}X != "PRODX" ] && [ -n "$SIT_SERVERS" ]; then
		echo "Matching SIT server ... ..."
		for sit_server in $SIT_SERVERS
		do
			if [ $HOSTNAME == $sit_server ]; then
				ENV_TMP=SIT
				echo "Hostname $HOSTNAME matched SIT server $sit_server"
			fi
		done
		
		if [ ${ENV_TMP}X != "SITX" ]; then
			echo "Hostname $HOSTNAME doesn't match SIT server"
		fi
	else
		echo "Environment is $ENV_TMP, skip to match SIT"
	fi
	
	if [ ${ENV_TMP}X != "SITX" ] && [ ${ENV_TMP}X != "PRODX" ] && [ -n "$UAT_SERVERS" ]; then
		echo "Matching UAT server ... ..."
		for uat_server in $UAT_SERVERS
		do
			if [ $HOSTNAME == $uat_server ]; then
				ENV_TMP=UAT
				echo "Hostname $HOSTNAME matched UAT server $uat_server"
			fi
		done
		
		if [ ${ENV_TMP}X != "UATX" ]; then
			echo "Hostname $HOSTNAME doesn't match UAT server"
		fi
	else
		echo "Environment is $ENV_TMP, skip to match UAT"
	fi
	
	if [ ${ENV_TMP}X != "SITX" ] && [ ${ENV_TMP}X != "UATX" ] && [ -n "$PRD_SERVERS" ]; then
		echo "Matching PROD server ... ..."
		for prd_server in $PRD_SERVERS
		do
			if [ $HOSTNAME == $prd_server ]; then
				ENV_TMP=PROD
				echo "Hostname $HOSTNAME matched PROD server $prd_server"
			fi
		done
		
		if [ ${ENV_TMP}X != "PRODX" ]; then
			echo "Hostname $HOSTNAME doesn't match PROD server"
		fi
	else
		echo "Environment is $ENV_TMP, skip to match PROD"
	fi
	
	ENV=$ENV_TMP
}


##GW jboss deployment
function deployJbossAPP()
{
	# parameter
	# $1 - SWSA
	# $2 - SIT UAT PROD
	# $2 - package name
	
	APP_JBOSS_HOME=${1}_${2}_JBOSS_HOME
	JBOSS_HOME=`eval echo '$'$APP_JBOSS_HOME`
	
	if [ ! -d "$JBOSS_HOME" ];then
		echo "	ERROR: JBOSS_HOME $JBOSS_HOME is not available"
		return 0
	fi
	
	#bring down jboss
	cd $JBOSS_HOME/bin
	./kill.sh
	sleep 3
	
	#backup
	fCopy $JBOSS_HOME/deployments/${3}*.war  $BACKUP_DIR

	#clean
	rm -rf $JBOSS_HOME/deployments/${3}*.*
	rm -rf $JBOSS_HOME/tmp/vfs/*
	rm -rf $JBOSS_HOME/tmp/work/jboss.web/default-host/*

	#deploy
	cp $PKG_HOME/${3}*.war $JBOSS_HOME/deployments/
	
	chown -R jboss:jboss $JBOSS_HOME/deployments/
	OWN_FLAG=$?
	
	chmod -R 775 $JBOSS_HOME/deployments/
	MOD_FLAG=$?
	
	if [ $OWN_FLAG -eq 0 ] && [ $MOD_FLAG -eq 0 ];then
		echo "Step 4: Sccussful to change permission"
		ls -ld $DEST_DIR
	else
		echo "	ERROR: Failed to change permission for Destination directory $DEST_DIR"
		echo "*********************************************************************"
		return 0
	fi
	
	#bring up jboss
	./start.sh
}
