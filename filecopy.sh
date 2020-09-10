#!/bin/sh

# #####################################################################################################################
# This script deploys properties, bizFlow and application WARs.
#
# CARA will invoke this script with the following parameters.
#
#	sh filecopy.sh <environment>
#
#
# #####################################################################################################################


DEPLOYMENT_PACKAGE_PATH=`pwd`

# Imports
source ${DEPLOYMENT_PACKAGE_PATH}/filecopy/deployment/lib/utils.sh
source ${DEPLOYMENT_PACKAGE_PATH}/filecopy/deployment/lib/logger.sh

# -----------------------------------------------------------------------------
# Initialization
#
# The following properties can and should be overridden using country-specific
# `filecopy.conf` file.
# -----------------------------------------------------------------------------

# Country code
COUNTRY=""

# BYPASS_DEPLOYMENT:    Y for "yes" | N for "No"
#
# Whether the deployment should go through
# This property should be set in `filecopy.conf` to BYPASS_<ENVIRONMENT>_DEPLOYMENT variable
BYPASS_DEPLOYMENT=N

# NFS_DEPLOY:    Y for "yes" | N for "No"
#
# Whether to deploy the properties and bizFlow files to mentioned NFS Server only.
# You will want to do this if the single appsdata directory are mounted to all the servers.
NFS_DEPLOY=N


# Whether to create a manual backup of the deployment package and scripts.
# Because RA cleans up the packages after deployment completes.
DEPLOYMENT_PACKAGE_BACKUP=N
DEPLOYMENT_PACKAGE_BACKUP_PATH=""

# -----------------------------------------------------------------------------
# Deployment configuration
# -----------------------------------------------------------------------------

ENVIRONMENT=$1
CONFIGURATION_FILE=${DEPLOYMENT_PACKAGE_PATH}/config/MTX99/filecopy.conf
if [ ! -f "${CONFIGURATION_FILE}" ]; then
    log_error "Deployment configuration file (${CONFIGURATION_FILE}) was not found."
    exit 1
fi

# Load deployment configuration
source ${CONFIGURATION_FILE}

BYPASS_DEPLOYMENT_OVERRIDE=$(eval echo '$BYPASS_'${ENVIRONMENT}'_DEPLOYMENT')
if [ ! -z "${BYPASS_DEPLOYMENT_OVERRIDE}" ]; then
    BYPASS_DEPLOYMENT=${BYPASS_DEPLOYMENT_OVERRIDE}
fi

if ! need_to_deploy 'filecopy' ${BYPASS_DEPLOYMENT}; then
    log_info "'filecopy' deployment is configured to be skipped."
    exit 0
fi

# ${COUNTRY} is available from configuration file
DEPLOY_COUNTRY_CODE=${COUNTRY}
DEPLOY_COUNTRY_CODE_LOW=$(echo ${DEPLOY_COUNTRY_CODE} | tr '[A-Z]' '[a-z]')
CURRENT_SERVER=$(hostname -s | tr '[A-Z]' '[a-z]')

WORKSPACE="/logs/jboss/release-management/${DEPLOY_COUNTRY_CODE_LOW}/$(date +%Y-%m-%d)/"
create_directory ${WORKSPACE}
chmod 777 ${WORKSPACE}

LOG_FILE_PATH="${WORKSPACE}/${CURRENT_SERVER}-filecopy.log"
set_log_file_path "${LOG_FILE_PATH}"

# -----------------------------------------------------------------------------
# Deployment package backup
# -----------------------------------------------------------------------------

if [ "${DEPLOYMENT_PACKAGE_BACKUP}" = "Y" ]; then
    log_info "Creating backup of deployment package."

    DEPLOYMENT_PACKAGE_BACKUP_PATH="${DEPLOYMENT_PACKAGE_BACKUP_PATH}/${DEPLOY_COUNTRY_CODE}_$(date +%Y%m%d%H%M%S)/"

    if create_directory ${DEPLOYMENT_PACKAGE_BACKUP_PATH}; then
        for z in "${DEPLOYMENT_PACKAGE_PATH}"/*.zip; do
            unzip -o ${z} -d "${DEPLOYMENT_PACKAGE_BACKUP_PATH}/"
        done

        chmod -R 777 ${DEPLOYMENT_PACKAGE_BACKUP_PATH}
        log_info "Created backup at ${DEPLOYMENT_PACKAGE_BACKUP_PATH}."
    else
        log_warn "Failed to create a directory at ${DEPLOYMENT_PACKAGE_BACKUP_PATH}. Skipping creating backup of deployment package."
    fi
fi


# -----------------------------------------------------------------------------
# Modules to be deployed
# -----------------------------------------------------------------------------

FILE_DEPLOY=$(deploy_filecopy_module 'Files' && echo 'Y' || echo 'N')
APP_DEPLOY=$(deploy_filecopy_module 'Apps' && echo 'Y' || echo 'N')
SCRIPT_DEPLOY=$(deploy_filecopy_module 'Scripts' && echo 'Y' || echo 'N')
CONFIGURATION_UPDATE=$(deploy_filecopy_module 'Config' && echo 'Y' || echo 'N')

log_info "Filecopy Deployment Indicators:"
log_info "FILE_DEPLOY: ${FILE_DEPLOY}"
log_info "APP_DEPLOY: ${APP_DEPLOY}"
log_info "SCRIPT_DEPLOY: ${SCRIPT_DEPLOY}"
log_info "CONFIGURATION_UPDATE: ${CONFIGURATION_UPDATE}"

# -----------------------------------------------------------------------------
# File deployment
#
# Properties, bizFlow and shell scripts are copied to a directory that is mounted to all
# the servers. Hence, single deployment is enough.
# -----------------------------------------------------------------------------

FILE_DEPLOY_SERVERS=`eval echo '$NFS_'${ENVIRONMENT}'_SERVER'`

FILE_DEPLOYED_INDICATOR="$WORKSPACE/file-deploy.DONE"

if  [ "${NFS_DEPLOY}" = "N" ] || match_servers $CURRENT_SERVER "$FILE_DEPLOY_SERVERS"; then
	if [ "${SCRIPT_DEPLOY}" = "Y" ]; then
	    sh filecopy/script_deploy.sh ${DEPLOYMENT_PACKAGE_PATH} ${ENVIRONMENT} ${CONFIGURATION_FILE}
	fi

	if [ "${FILE_DEPLOY}" = "Y" ]; then
	    sh filecopy/file_deploy.sh ${DEPLOYMENT_PACKAGE_PATH} ${ENVIRONMENT} ${CONFIGURATION_FILE}
	fi

	# Placing a file indicator to allow other servers to continue with App deployment
	touch $FILE_DEPLOYED_INDICATOR
	chmod 777 $FILE_DEPLOYED_INDICATOR
else
    log_info "File Deploy and Script Deploy are not applicable for this server."
fi

# -----------------------------------------------------------------------------
# Configuration Deployment
# -----------------------------------------------------------------------------

# Wait until file deployment completes
APP_DEPLOY_WAITING_INDICATOR="$WORKSPACE/$CURRENT_SERVER-app-deploy.WAITING"
touch $APP_DEPLOY_WAITING_INDICATOR

while [ ! -f "$FILE_DEPLOYED_INDICATOR" ]; do
  sleep 5
done

rm $APP_DEPLOY_WAITING_INDICATOR

# Deployable apps
APPS="MTX99 SWSA GENIE GTW STP BAH_STP GUI BAH_INQ INQ"

# Apps to deploy on current server
apps_to_deploy=""
for app in $APPS; do
	APP_DEPLOY_SERVERS=`eval echo '$'$app'_'${ENVIRONMENT}'_SERVER'`
	if match_servers $CURRENT_SERVER "$APP_DEPLOY_SERVERS"; then
		apps_to_deploy="$apps_to_deploy $app"
	fi
done

if [ "${CONFIGURATION_UPDATE}" = "Y" ]; then
    sh filecopy/configuration_update.sh ${DEPLOYMENT_PACKAGE_PATH} ${ENVIRONMENT} "${apps_to_deploy}" ${CONFIGURATION_FILE} ${WORKSPACE} >> ${LOG_FILE_PATH}
fi

# -----------------------------------------------------------------------------
# App Deployment
# -----------------------------------------------------------------------------

if [ "${APP_DEPLOY}" = "Y" ]; then
    sh filecopy/app_deploy.sh ${DEPLOYMENT_PACKAGE_PATH} ${ENVIRONMENT} "${FILE_DEPLOY}" ${CONFIGURATION_FILE}
fi

log_info "Reached end of filecopy deployment"