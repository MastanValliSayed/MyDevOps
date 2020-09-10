
#!/bin/sh

# #####################################################################################################################
# App deployment script
# 
# This script copies WARs to `deployments` folders of respective Jboss servers.
# For Gateway, it will copy properties as well.
#
#	sh app_deploy.sh <deploy-package-path> <environment> <apps-to-deploy> <deploy-country-code>
#
# #####################################################################################################################

HOME=$1
ENVIRONMENT=$2
FILE_DEPLOY=$3
CONF_FILE=$4

#Load and execute config file
. $CONF_FILE

# ${COUNTRY} is available from configuration file
CTRY=${COUNTRY}
COUNTRY_CODE=$(echo ${COUNTRY} | python -c 'import sys; print sys.stdin.read().lower()')

JOB_NAME="APP_DEPLOYMENT"
DATE=$(date +%Y-%m-%d)
DATE_TIME=$(date +%Y-%m-%d-%H-%M-%S)
HOSTNAME=`hostname -s | python -c 'import sys; print sys.stdin.read().lower()'`

WORK_SP="/logs/jboss/release-management/${COUNTRY_CODE}/${DATE}"
PKG_DIR="$WORK_SP/${JOB_NAME}-${HOSTNAME}-${DATE}"
BACKUP_DIR="$WORK_SP/backup_apps/${DATE}_${COUNTRY_CODE}"
STD_OUT="$WORK_SP/${JOB_NAME}-${HOSTNAME}-${DATE_TIME}.log"
PUB_FUNCTION="$HOME/filecopy/public_function.sh"
. $PUB_FUNCTION
#####################################
createDir $WORK_SP
chown jboss:jboss $WORK_SP
chmod 775 $WORK_SP
createDir $BACKUP_DIR
chown jboss:jboss $BACKUP_DIR
chmod 775 $BACKUP_DIR
createFile $STD_OUT
chown jboss:jboss $STD_OUT
chmod 775 $STD_OUT
if [ "${FILE_DEPLOY}" = "N" ]; then
	createFile "$WORK_SP/FILE_DEPLOYMENT-${DATE}.DONE"
	chown jboss:jboss "$WORK_SP/FILE_DEPLOYMENT-${DATE}.DONE"
	chmod 775 "$WORK_SP/FILE_DEPLOYMENT-${DATE}.DONE"
fi
#####################################

echo " INFO: Preparing Environment" >> ${STD_OUT}
echo " INFO: Created $WORK_SP" >> ${STD_OUT}
echo " INFO: Created Log FIle ${STD_OUT}" >> ${STD_OUT}

if [ ! -d "$HOME" ]; then
echo "ERROR: '$HOME' is not a valid path."  >> ${STD_OUT}
exit 1
fi

#To check config file
if [ ! -s "$CONF_FILE" ]; then
echo "	ERROR: Configuration file $CONF_FILE is either missing or empty." >> ${STD_OUT}
exit 1
else
echo " INFO: Loading and executing config file $CONF_FILE ." >> ${STD_OUT}
. $CONF_FILE
fi

#To check function file
if [ ! -s "$PUB_FUNCTION" ]; then
echo "	ERROR: Function file $PUB_FUNCTION is either missing or empty." >> ${STD_OUT}
exit 1
else
echo " INFO: loading Public functions file $PUB_FUNCTION ." >> ${STD_OUT}
. $PUB_FUNCTION
fi

# Set Log Dir
#if [ ! -d "$WORK_SP" ]; then
#	echo "WARNING: $WORK_SP is not existing, it will be created"
#	mkdir -p $WORK_SP

#fi



echo >> ${STD_OUT}
echo "=====================================================================" >> ${STD_OUT}

for i in $(seq 60); do
	if [ -f "$WORK_SP/FILE_DEPLOYMENT-${DATE}.DONE" ]; then
		APP_DEPLOYMENT_STATUS=START
        #echo "FILE_DEPLOYMENT completed !!!" >> ${STD_OUT}
        echo "Skipping File deployment" >> ${STD_OUT}
		break
	else
		echo "WARNING: $i - FILE_DEPLOYMENT is not completed, waiting 5 seconds" >> ${STD_OUT} 
		sleep 5
	fi
done

echo "=====================================================================" >> ${STD_OUT}
echo >> ${STD_OUT}

echo >> ${STD_OUT}
echo "=====================================================================" >> ${STD_OUT}
if [ ${APP_DEPLOYMENT_STATUS}X == "STARTX" ]; then
	echo "BEGIN APP deployment" >> ${STD_OUT}
else
	echo "	ERROR: FILE_DEPLOYMENT time out, APP_DEPLOYMENT is stopped" >> ${STD_OUT}
	exit 1
fi

echo "Deploy APP starting..."


#Check SERVER and ENV
echo " INFO: To check MTX99 environment"
echo " INFO: To check MTX99 environment" >> ${STD_OUT}
checkEnvironment MTX99_SIT_SERVER MTX99_UAT_SERVER MTX99_PRD_SERVER >> ${STD_OUT}

if [ ${ENV}X == "SITX" ] || [ ${ENV}X == "UATX" ] || [ ${ENV}X == "PRODX" ]; then
	MTX99_DEPLOY=Y
	MTX99_ENV=$ENV
	echo " INFO: MTX99 will be deployed, The environment is $ENV !!!"
	echo " INFO: MTX99 will be deployed, The environment is $ENV !!!" >> ${STD_OUT}
else
	echo " INFO: This is not MTX99 server" >> ${STD_OUT}
	echo " INFO: This is not MTX99 server"
fi

echo "To check INQ environment" >> ${STD_OUT}
checkEnvironment INQ_SIT_SERVER INQ_UAT_SERVER INQ_PRD_SERVER >> ${STD_OUT}

if [ ${ENV}X == "SITX" ] || [ ${ENV}X == "UATX" ] || [ ${ENV}X == "PRODX" ]; then
	INQ_DEPLOY=Y
	INQ_ENV=$ENV
	echo "INQ will be deployed, The environment is $ENV !!!" >> ${STD_OUT}
else
	echo "	This is not INQ server" >> ${STD_OUT}
fi

echo "To check GUI environment" >> ${STD_OUT}
checkEnvironment GUI_SIT_SERVER GUI_UAT_SERVER GUI_PRD_SERVER >> ${STD_OUT}

if [ ${ENV}X == "SITX" ] || [ ${ENV}X == "UATX" ] || [ ${ENV}X == "PRODX" ]; then
	GUI_DEPLOY=Y
	GUI_ENV=$ENV
	echo "GUI will be deployed, The environment is $ENV !!!" >> ${STD_OUT}
else
	echo "	This is not GUI server" >> ${STD_OUT}
fi

echo "To check GUI environment" >> ${STD_OUT}
checkEnvironment BAH_SIT_SERVER BAH_UAT_SERVER BAH_PRD_SERVER >> ${STD_OUT}

if [ ${ENV}X == "SITX" ] || [ ${ENV}X == "UATX" ] || [ ${ENV}X == "PRODX" ]; then
	BAH_DEPLOY=Y
	BAH_ENV=$ENV
	echo "BAH will be deployed, The environment is $ENV !!!" >> ${STD_OUT}
else
	echo "	This is not BAH server" >> ${STD_OUT}
fi

#Check Package path
if [ ! -d "$HOME" ]; then
	echo "	ERROR: $HOME not available."  >> ${STD_OUT}
	echo "	ERROR: $HOME not available."
	exit 1
fi

if [ ${MTX99_DEPLOY}X != "YX" ] && [ ${STP_DEPLOY}X != "YX" ] && [ ${INQ_DEPLOY}X != "YX" ] && [ ${GUI_DEPLOY}X != "YX" ] && [ ${BAH_DEPLOY}X != "YX" ]; then
	echo "	ERROR: Configuration file error, current server HOSTNAME is $HOSTNAME, please check $CONF_FILE" >> ${STD_OUT}
	exit 1
fi
echo "=====================================================================" >> ${STD_OUT}
echo >> ${STD_OUT}
echo "=====================================================================" >> ${STD_OUT}
#Create backup folder
if [ ! -d "$BACKUP_DIR" ]; then
	#rm -rf $BACKUP_DIR
	echo " INFO: Creating backup folder $BACKUP_DIR" >> ${STD_OUT}
	#mkdir -p $BACKUP_DIR
    #chmod 775 $BACKUP_DIR
else
    echo " INFO: Backup Folder already exists $BACKUP_DIR" >> ${STD_OUT}
fi

if [ "${MTX99_DEPLOY}"X == "YX" ]; then

	PKG_HOME=$HOME/package
	
	##jboss deployment
	GTW_PKG=`ls $PKG_HOME/ipe-mt-x99*.war`
	if [ -n "$GTW_PKG" ]; then
		echo " INFO: deploy GateWay, stage folder : $PKG_HOME" >> ${STD_OUT}
		echo " INFO: deployJbossAPP GTW ${MTX99_ENV} wars processing ... ..." >> ${STD_OUT}
		deployJbossAPP MTX99 "${MTX99_ENV}" ipe-mt-x99 >> ${STD_OUT} 2>&1
	else
		echo "	ERROR: Package ipe-mt-x99.war is missing" >> ${STD_OUT}
	fi
fi

if [ ${INQ_DEPLOY}X == "YX" ]; then
	PKG_HOME=$HOME/package/
	##jboss deployment
	INQ_PKG=`ls $PKG_HOME/ipe-mt-x99-api-cn.war`
	if [ -f "$INQ_PKG" ]; then
		echo "deploy INQ, stage folder : $PKG_HOME" >> ${STD_OUT}
		echo "deployJbossAPP INQ $INQ_ENV wars processing ... ..." >> ${STD_OUT}
		deployJbossAPP INQ "${INQ_ENV}" ipe-mt-x99-api-cn >> ${STD_OUT} 2>&1
	else
		echo "	ERROR: Package ipe-mt-x99-api-cn.war is missing" >> ${STD_OUT}
	fi
fi

if [ ${INQ_DEPLOY}X == "YX" ]; then
	PKG_HOME=$HOME/package/
	##jboss deployment
	INQ_PKG=`ls $PKG_HOME/ipe-mt-x99-gui-cn.war`
	if [ -f "$INQ_PKG" ]; then
		echo "deploy INQ, stage folder : $PKG_HOME" >> ${STD_OUT}
		echo "deployJbossAPP INQ $INQ_ENV wars processing ... ..." >> ${STD_OUT}
		deployJbossAPP INQ "${INQ_ENV}" ipe-mt-x99-gui-cn >> ${STD_OUT} 2>&1
	else
		echo "	ERROR: Package ipe-mt-x99-gui-cn.war is missing" >> ${STD_OUT}
	fi
fi

if [ ${GUI_DEPLOY}X == "YX" ]; then

	PKG_HOME=$HOME/package/
	
	##jboss deployment
	GUI_PKG=`ls $PKG_HOME/ipe-mt-x99-api-hk.war`
	if [ -f "$GUI_PKG" ]; then
		echo "deploy GUI, stage folder : $PKG_HOME" >> ${STD_OUT}
		echo "deployJbossAPP GUI $GUI_ENV wars processing ... ..." >> ${STD_OUT}
		deployJbossAPP GUI $GUI_ENV ipe-mt-x99-api-hk >> ${STD_OUT} 2>&1
	else
		echo "	ERROR: Package ipe-mt-x99-api-hk.war is missing" >> ${STD_OUT}
	fi
fi

if [ ${GUI_DEPLOY}X == "YX" ]; then

	PKG_HOME=$HOME/package/
	
	##jboss deployment
	GUI_PKG=`ls $PKG_HOME/ipe-mt-x99-gui-hk.war`
	if [ -f "$GUI_PKG" ]; then
		echo "deploy GUI, stage folder : $PKG_HOME" >> ${STD_OUT}
		echo "deployJbossAPP GUI $GUI_ENV wars processing ... ..." >> ${STD_OUT}
		deployJbossAPP GUI $GUI_ENV ipe-mt-x99-gui-hk >> ${STD_OUT} 2>&1
	else
		echo "	ERROR: Package ipe-mt-x99-gui-hk.war is missing" >> ${STD_OUT}
	fi
fi

if [ ${BAH_DEPLOY}X == "YX" ]; then

	PKG_HOME=$HOME/package/
	
	##jboss deployment
	BAH_PKG=`ls $PKG_HOME/ipe-mt-x99-api-hb.war`
	if [ -f "$BAH_PKG" ]; then
		echo "deploy BAH, stage folder : $PKG_HOME" >> ${STD_OUT}
		echo "deployJbossAPP BAH $BAH_ENV wars processing ... ..." >> ${STD_OUT}
		deployJbossAPP BAH $BAH_ENV ipe-mt-x99-api-hb >> ${STD_OUT} 2>&1
	else
		echo "	ERROR: Package ipe-mt-x99-api-hb.war is missing" >> ${STD_OUT}
	fi
fi

if [ ${BAH_DEPLOY}X == "YX" ]; then

	PKG_HOME=$HOME/package/
	
	##jboss deployment
	BAH_PKG=`ls $PKG_HOME/ipe-mt-x99-gui-hb.war`
	if [ -f "$BAH_PKG" ]; then
		echo "deploy BAH, stage folder : $PKG_HOME" >> ${STD_OUT}
		echo "deployJbossAPP BAH $BAH_ENV wars processing ... ..." >> ${STD_OUT}
		deployJbossAPP BAH $BAH_ENV ipe-mt-x99-gui-hb >> ${STD_OUT} 2>&1
	else
		echo "	ERROR: Package ipe-mt-x99-gui-hb.war is missing" >> ${STD_OUT}
	fi
fi


echo " INFO: Completed the $HOSTNAME $ENV jboss deployment" >> ${STD_OUT}
echo "=====================================================================" >> ${STD_OUT}
echo " INFO: Checking deployment location for current dates" >> ${STD_OUT}
ls -ltr $JBOSS_HOME/deployments >> ${STD_OUT}
echo "=====================================================================" >> ${STD_OUT}
echo "Completed, please check log for details. Log: $STD_OUT"
exit 