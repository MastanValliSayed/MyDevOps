#!/bin/sh
###############################################################################################################
#	Bank 			Apartment			Project Name
#	DBS Bank 		IPE 				IPE_SG2
#	the scripts is use for to deploy SQL via CICD
#	it will copy file from CARA to DB server and execute it
#
#	Parameter : based on custom environment & Custom paraments SQL deployment will be deployed , 
#	CUSTOM ENVIRONMENT values placed in deploy.json file
#
#	DATE				Author					Version
#	2023-06-16		    Mastan Valli SAYED			 2.0
#################################################################################################################

DEPLOYMENT_PACKAGE_PATH=`pwd`
env=$1

# Country code
COUNTRY_FILE="${DEPLOYMENT_PACKAGE_PATH}/COUNTRY"
. $COUNTRY_FILE

CTRY=${country}
#COUNTRY_CODE=$(echo ${country} | python -c 'import sys; print sys.stdin.read().lower()')
COUNTRY_CODE=$(echo "${country}" | python -c 'import sys; print (sys.stdin.read().lower())')

# release version is SQL_VERSION
RELEASE_VERSION="${DEPLOYMENT_PACKAGE_PATH}/SQL_VERSION"
. $RELEASE_VERSION


DATE=$(date +%Y%m%d)
DATE_TIME=$(date +%Y%m%d%H%M%S)
WORK_SP="/ipelogs/jboss/sgp/release-management/DB_DEPLOYMENT/${DATE}"
log_file=${WORK_SP}/log_mariadeployer_${env}_${DATE_TIME}-sqllog.log

#################################################################################################################

# Set Log Dir
if [ ! -d "$WORK_SP" ]; then
	echo "WARNING: $WORK_SP is not existing, it will be created"
	mkdir -p $WORK_SP
    chown -R jboss:ipebatch $WORK_SP
	chmod -R 775 $WORK_SP
fi

#################################################################################################################

id=`whoami`
host_name=`hostname`
host="${host_name:0:13}"
scripts_dir=$(dirname $0)

if [ $scripts_dir == "." ]; then
        scripts_dir=`pwd`
fi
PARAM_CNT=$#
PARAMS=$@

echo "$env - DB Deployment Started" >> $log_file

countrycd=`python -c "import sys,re,json; f=open('deploy.json'); data=json.load(f); print(data['$env'][0]['opt-params']['country'])"`
ip=`python -c "import sys,re,json; f=open('deploy.json'); data=json.load(f); print(data['$env'][0]['opt-params']['ip-address'])"`
port=`python -c "import sys,re,json; f=open('deploy.json'); data=json.load(f); print(data['$env'][0]['opt-params']['port'])"`
db_user=`python -c "import sys,re,json; f=open('deploy.json'); data=json.load(f); print(data['$env'][0]['opt-params']['db-user'])"`
folder=`python -c "import sys,re,json; f=open('deploy.json'); data=json.load(f); print(data['$env'][0]['opt-params']['folder'])"`

db_pwd=${cyberark_pwd}
sub_folder=''
sql_exe_type=''
EMPTY=""
script_ver=$3 ## DDL,IUCT-2302_cd_tbl
arg1=$1
arg2=$2
arg3=$3
arg4=$4

echo "arg1:$arg1, arg2:$arg2, arg3:$arg3, arg4:$arg4" >> $log_file
if [[ "$script_ver" == "" ]]; then
  sql_exe_type='*'
fi
if [[ "$env" == *"RELEASE"* ]]; then
  sub_folder='RELEASE'
fi
if [[ "$env" == *"ROLLBACK"* ]]; then
  sub_folder='ROLLBACK'
fi
if [[ "$env" == *"FLAGON"* ]]; then
  sub_folder='FLAGON'
fi
if [[ "$env" == *"FLAGOFF"* ]]; then
  sub_folder='FLAGOFF'
fi

if [[ "$script_ver" == "DDL"* ]]; then
  sql_exe_type='DDL'
  script_ver=$(echo "${script_ver/DDL,/$EMPTY}") 
  script_ver=$(echo "${script_ver/DDL/$EMPTY}")
fi
if [[ "$script_ver" == "DML"* ]]; then
  sql_exe_type='DML'
  script_ver=$(echo "${script_ver/DML,/$EMPTY}")
  script_ver=$(echo "${script_ver/DML/$EMPTY}")
fi
if [[ "$script_ver" == "SP"* ]]; then
  sql_exe_type='SP'
  script_ver=$(echo "${script_ver/SP,/$EMPTY}")
  script_ver=$(echo "${script_ver/SP/$EMPTY}")
fi

echo "DB Details:$countrycd $ip $port $db_user $folder $sub_folder $version" >> $log_file

#################################################################################################################
#                                       SQL Deployment Starts                                                   #
#################################################################################################################
echo "Full Path: package/DBScripts/$countrycd/$sub_folder/$sql_exe_type/${release_version}/$folder/$script_ver" >> $log_file
for file in package/DBScripts/$countrycd/$sub_folder/$sql_exe_type/${release_version}/$folder/$script_ver*; do
    if [ -f "$file" ]; then
		echo "Running File: $file" >> $log_file
		#db_schema=${file##*/}
		#db_schema=${db_schema%.*}
		echo "Running DB Scripts" >> $log_file
		echo "ip= $ip, port= $port, db user= $db_user" >> $log_file
		mysql --force -h $ip -u $db_user -P $port -p"$db_pwd" < $file >> /${WORK_SP}/$ip-${env}-${DATE_TIME}-sqllog.log 2>&1
		if [ $? -eq 0 ]; then
			echo "DB Deployment is successful" >> $log_file
			echo "##############################################" >> $log_file
sleep 10
tar -cvf SG_SQL_deployment_verification.tar  /ipelogs/jboss/sgp/release-management/DB_DEPLOYMENT/${DATE}/*-sqllog.log
gzip SG_SQL_deployment_verification.tar
echo "Hey.!
        
Please find attached SG_SQL_deployment_verification report.
        
Completed successfully, Thank you!!!!..
        
Thanks & Regards,
Team DevOps" | mail -s "SG post SQL deployment logs" -a "SG_SQL_deployment_verification.tar.gz"  "mastanvallis@dbs.com" "IPEDAH2DevOps@DBS1Bank.onmicrosoft.com" "ysumanth@dbs.com" "sachinkrsingh@dbs.com" "guntupalli1@dbs.com" "ipedah2leads@dbs1bank.onmicrosoft.com" "to-dah2-ibgt-gtscash-ipe@DBS1Bank.onmicrosoft.com" "ganapatirao@dbs.com" "rajamanikantag@dbs.com" "satyarajeshr@dbs.com" "koteswararao3@dbs.com" "krishnaja@dbs.com" "guntupalli1@dbs.com" "jeebannath@dbs.com" "radhikagodugu@dbs.com" "sudheepthi@dbs.com" "keerthanashank1@dbs.com" "kshitizjain@dbs.com" "vengamamba@dbs.com" "srinivasgeddam@dbs.com" "nirajkumarkumar@dbs.com" "anurag3@dbs.com" "atanubasak@dbs.com" "dilipraj@dbs.com" "madhusudhanb@dbs.com" "prasanthap@dbs.com" "sharduld@dbs.com" "ksivasai@dbs.com" "abhishekrathore@dbs.com" "venkateshk@dbs.com" "pramitranjan@dbs.com" "sridharsidda@dbs.com" "sandeepreddy@dbs.com"
		else
			echo "DB Deployment failed. Check /${WORK_SP}/$ip-${env}-${DATE_TIME}-sqllog file for more details" >> $log_file
			echo "##############################################" >> $log_file
			echo "##############################################" >> $log_file
			exit 1
		fi
   fi
done

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "MariaDB deployment failed" >> $log_file
  echo "Check logs created at ${log_file} " >> $log_file
  exit 1
fi

echo "$ip :: $env - DB Deployment Completed" >> $log_file
echo "##############################################" >> $log_file
echo "##############################################" >> $log_file
