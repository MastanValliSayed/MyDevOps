#!/bin/sh
# #####################################################################################################################
# File Deployment script
#
# Usage:	sh file_deploy.sh <deployment-package-path> <environment> <configuration-file>
#
# #####################################################################################################################


HOME=$1
ENVIRONMENT=$2
CONF_FILE=$3

#execute config file
. $CONF_FILE

CTRY=${COUNTRY}
COUNTRY_CODE_LOW=$(echo ${CTRY} | python -c 'import sys; print sys.stdin.read().lower()')


if [[ "$ENVIRONMENT" =~ "UAT" ]];
then
	ENV_LOW=uat
fi

if [[ "$ENVIRONMENT" =~ "PROD" ]];
then
	ENV_LOW=prod
fi


JOB_NAME="FILE_DEPLOYMENT"
DATE=$(date +%Y-%m-%d)
DATE_TIME=$(date +%Y-%m-%d-%H-%M-%S)
HOSTNAME=`hostname -s | python -c 'import sys; print sys.stdin.read().lower()'`

WORK_SP="/logs/jboss/release-management/${COUNTRY_CODE_LOW}/${DATE}"
PKG_DIR="$WORK_SP/${JOB_NAME}-${HOSTNAME}-${DATE}"
STD_OUT="$WORK_SP/${JOB_NAME}-${HOSTNAME}-${DATE_TIME}.log"
PUB_FUNCTION="$HOME/filecopy/public_function.sh"
. $PUB_FUNCTION
#####################################
createDir $WORK_SP
chown jboss:jboss $WORK_SP
chmod 775 $WORK_SP
createFile $STD_OUT
chown jboss:jboss $STD_OUT
chmod 775 $STD_OUT
#####################################

echo " INFO: Preparing Environment" >> ${STD_OUT}
echo " INFO: Created $WORK_SP" >> ${STD_OUT}
echo " INFO: Created Log FIle ${STD_OUT}" >> ${STD_OUT}

if [ ! -d "$HOME" ]; then
echo "ERROR: '$HOME' is not a valid path."  >> ${STD_OUT}
exit 1
fi

echo "File deployment Running..."

#To check function file
if [ ! -s "$PUB_FUNCTION" ]; then
        echo "	ERROR: Function file $PUB_FUNCTION is either missing or empty." >> ${STD_OUT}
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

echo >> ${STD_OUT}
echo "=====================================================================" >> ${STD_OUT}
#Check SERVER and ENV
echo " INFO: To check MTX99 environment" >> ${STD_OUT}
checkEnvironment "MTX99_SIT_SERVER" "MTX99_UAT_SERVER" "MTX99_PRD_SERVER" >> ${STD_OUT}

if [ ${ENV}X == "SITX" ] || [ ${ENV}X == "UATX" ] || [ ${ENV}X == "PRODX" ]; then
	echo " INFO: The MTX99 environment is $ENV" >> ${STD_OUT}
else
	echo "	ERROR: Configuration file error, current server HOSTNAME is $HOSTNAME, please check $CONF_FILE" >> ${STD_OUT}
	exit 1
fi
echo "=====================================================================" >> ${STD_OUT}
#Check Package path
if [ ! -d "$HOME" ]; then
	echo "	ERROR: $HOME not available."  >> ${STD_OUT}
	exit 1
fi

Properties_HOME=$HOME/externalproperties/${ENV_LOW}
Deploy_Folder=/apps/data/pu/flex

if [ -f "$Deploy_Folder/config.properties" ];
then
	ls $Properties_HOME/config.properties && mv $Deploy_Folder/config.properties $Deploy_Folder/config.properties.bak.$DATE && cp -fr $Properties_HOME/config.properties $Deploy_Folder/
    chown jboss:ipebatch $Deploy_Folder/config.properties
    chmod 775 $Deploy_Folder/config.properties
else
	ls $Properties_HOME/config.properties && cp -fr $Properties_HOME/config.properties $Deploy_Folder/
    chown jboss:ipebatch $Deploy_Folder/config.properties
    chmod 775 $Deploy_Folder/config.properties
fi

#Create temporary folder for unzip
# if [ -d "$PKG_DIR" ]; then
# 	rm -rf $PKG_DIR
# fi

# mkdir -p $PKG_DIR
# chmod 755 $PKG_DIR

# cd $PKG_DIR

#properties deployment
# PKG1=`ls $Properties_HOME/config.properties`
# if [ -f "$PKG1" ]; then
# 	echo "execute: unzip -o $PKG1 -d $PKG_DIR" >> ${STD_OUT}
# 	unzip -o $PKG1 -d $PKG_DIR
# 	echo " INFO: deploy properties, stage folder : $PKG_DIR" >> ${STD_OUT}
# 	echo " INFO: deployProperties processing ... ..." >> ${STD_OUT}
# 	deployProperties $CTRY $ENV >> ${STD_OUT}
# else
# 	echo "	WARNING: Package config.properties is missing, sikp properties deployment" >> ${STD_OUT}
# #	exit 0
# fi

#businessFlow deployment
# PKG2=`ls $PKG_HOME/nipe_businessFlow_*.jar`
# if [ -f "$PKG2" ]; then
# 	echo "execute: unzip -o $PKG2 -d $PKG_DIR" >> ${STD_OUT}
# 	unzip -o $PKG2 -d $PKG_DIR
# 	echo " INFO: deploy BusinessFlow, stage folder : $PKG_DIR" >> ${STD_OUT}
# 	echo " INFO: deployBusinessFlow processing ... ..." >> ${STD_OUT}
# 	deployBusinessFlow $CTRY >> ${STD_OUT}
# else
# 	echo "	WARNING: Package nipe_businessFlow_*.jar is missing, sikp businessFlow deployment" >> ${STD_OUT}
# #	exit 0
# fi

#ADK jar deployment
# PKG3=`ls $PKG_HOME/nipe_adk*.jar`
# if [ -f "$PKG3" ]; then
# 	echo " INFO: deploy nipe_adk, stage folder : $PKG_HOME" >> ${STD_OUT}
# 	echo " INFO: deploy nipe_adk processing ... ..." >> ${STD_OUT}
# 	deployADK $PKG3 >> ${STD_OUT}
# else
# 	echo "	WARNING: Package nipe_adk*.jar is missing, sikp deployADK deployment" >> ${STD_OUT}
# #	exit 0
# fi

#chown -R jboss:ipebatch $PKG_DIR
#chmod -R 775 $PKG_DIR

echo "Completed the $CTRY $HOSTNAME $ENV deployment" >> ${STD_OUT}
echo "Completed, please check log for details. Log: $STD_OUT"

touch $WORK_SP/FILE_DEPLOYMENT-${DATE}.DONE
chown jboss:ipebatch $WORK_SP/FILE_DEPLOYMENT-${DATE}.DONE
chmod 775 $WORK_SP/FILE_DEPLOYMENT-${DATE}.DONE

exit 
