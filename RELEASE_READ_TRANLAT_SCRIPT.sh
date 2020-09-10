#!/bin/sh
JOB_NAME="RELEASE_READ_TRANLAT_SCRIPT"
DATE_TIME=$(date +%Y%m%d%H%M%S)
DATE_NOW=$(date +%Y%m%d)
HOSTNAME=`hostname -s | tr '[A-Z]' '[a-z]'`
PROMOTION_PACKAGE_LOCATION=$1
ENVIRONMENT=$2
STD_OUT="/ipelogs/jboss/sgp/release-management/${JOB_NAME}-${ENVIRONMENT}-${HOSTNAME}-${DATE_TIME}.log"

echo "ENVIRONMENT is $ENVIRONMENT before" >> ${STD_OUT} 2>&1
if [ $ENVIRONMENT == "SIT_SGP" ]; then
echo "ENVIRONMENT change entered for sit" >> ${STD_OUT} 2>&1
ENVIRONMENT='SIT'
fi

if [ $ENVIRONMENT == "UAT_SGP" ]; then
echo "ENVIRONMENT change entered for uat" >> ${STD_OUT} 2>&1
ENVIRONMENT='UAT'
fi

if [ $ENVIRONMENT == "PROD_SGP" ]; then
echo "ENVIRONMENT change entered for Prod" >> ${STD_OUT} 2>&1
ENVIRONMENT='PROD'
fi 
echo "ENVIRONMENT is $ENVIRONMENT After " >> 	${STD_OUT} 2>&1

# check if Release Config file is present
#RELEASE_CONFIG_FILE="/tmp/RELEASE_CONFIG.txt"
#if [ ! -f "$RELEASE_CONFIG_FILE" ]; then
#	echo "**************ERROR : The Release config file $RELEASE_CONFIG_FILE is either missing or empty.**************" >> ${STD_OUT} 2>&1
#	exit 0;
#fi
#echo "Release config file : $RELEASE_CONFIG_FILE" >> ${STD_OUT} 2>&1

# get the Promotion Package location and environment
#PROMOTION_PACKAGE_LOCATION=`grep "PROMOTION_PACKAGE_LOCATION=" $RELEASE_CONFIG_FILE | cut -d"=" -f2`
#ENVIRONMENT=`grep "ENVIRONMENT=" $RELEASE_CONFIG_FILE | cut -d"=" -f2`

#check log folder
if [ ! -d "/ipelogs/jboss/sgp/release-management/"  ]; then
	mkdir -p /ipelogs/jboss/sgp/release-management/
	chown jboss:ipebatch /ipelogs/jboss/sgp/release-management/
	chmod 755 /ipelogs/jboss/sgp/release-management
	echo "the log folder not existed,created dir /ipelogs/jboss/sgp/release-management/ ."
else
	echo "the log folder existed,checked ok."
fi

touch $STD_OUT
chown jboss:ipebatch $STD_OUT
chmod 755 $STD_OUT

########################## FUNCTION DEFINITIONS ############################

# function to remove control M characters 
removeControlM()
{
	tr -d '\015' < $1 > $1-tmp
	rm -rf $1
	mv $1-tmp $1
}

############################################################################


########################## BEGIN MAIN ######################################


echo "Reading of Release translation sheet begin." >> ${STD_OUT} 2>&1

# check if the promotion package location was specified
if [ "" = "$PROMOTION_PACKAGE_LOCATION" ]; then
	echo "**************ERROR : The PROMOTION_PACKAGE_LOCATION has invalid value.**************" >> ${STD_OUT} 2>&1
	exit 0;
fi

# check if the ENVIRONMENT was specified
if [ "" = "$ENVIRONMENT" ]; then
	echo "**************ERROR : The ENVIRONMENT has invalid value.**************" >> ${STD_OUT} 2>&1
	exit 0;
fi
echo "PROMOTION_PACKAGE_LOCATION property value : $PROMOTION_PACKAGE_LOCATION" >> ${STD_OUT} 2>&1
echo "ENVIRONMENT property value : $ENVIRONMENT" >> ${STD_OUT} 2>&1

cp $PROMOTION_PACKAGE_LOCATION/package/IPE_TRANSLATION_SHEET.csv /tmp/
chmod 755 /tmp/IPE_TRANSLATION_SHEET.csv

TRANSLATION_SHEET="/tmp/IPE_TRANSLATION_SHEET.csv"
# check if the Translation Sheet is present
if [ ! -s "${TRANSLATION_SHEET}" ]; then
	echo "**************ERROR : The translation sheet ${TRANSLATION_SHEET} is either missing or empty.**************" >> ${STD_OUT} 2>&1
	exit 0;
fi
echo "Translation sheet : $TRANSLATION_SHEET" >> ${STD_OUT} 2>&1

$(removeControlM $TRANSLATION_SHEET )

# replace \ with / in the translation sheet
cat $TRANSLATION_SHEET | sed 's/\\/\//g' > $TRANSLATION_SHEET-tmp
rm -rf $TRANSLATION_SHEET
mv $TRANSLATION_SHEET-tmp $TRANSLATION_SHEET
chmod 755 $TRANSLATION_SHEET

# iterate thru the sheet
current_line_number=0
for line in `cat $TRANSLATION_SHEET`; do

	current_line_number=`expr $current_line_number + 1`
	
	if [ "$current_line_number" = "1" ]; then
		# skip header
		continue
	fi
	echo "-------------------------------------------------------------" >> ${STD_OUT} 2>&1
	echo "Processing line : $current_line_number" >> ${STD_OUT} 2>&1
	
	ENV=`echo $line | cut -d"," -f1`
	SOURCE=`echo $line | cut -d"," -f2`
	DEST=`echo $line | cut -d"," -f3`
	FILE_OWNER=`echo $line | cut -d"," -f4`
	FILE_OWNER_GROUP=`echo $line | cut -d"," -f5`
	FILE_ATTRIB=`echo $line | cut -d"," -f6`
	BACKUP=`echo $line | cut -d"," -f7`
	CLEAN=`echo $line | cut -d"," -f8`
	
	# check if the line has the same enviroment as the server
	if [ ! "$ENVIRONMENT" = "$ENV" ]; then
		continue
	fi
	
	# check if source exist and is not empty
	if [ -s $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE ]; then
	    echo "The source file $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE exists. Checking if to clean the file..." >> ${STD_OUT} 2>&1
	    if [ "$CLEAN" = "Y" ]; then
		    echo "     Translation sheet says to clean the file of control-M chars." >> ${STD_OUT} 2>&1
			echo "     Removing Control-M characters in source file : $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE" >> ${STD_OUT} 2>&1
			$(removeControlM $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE )
			echo "     Control-M characters in source file : $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE were successfully removed." >> ${STD_OUT} 2>&1
		else 
			echo "     Translation sheet says no need to clean the file of control-M chars." >> ${STD_OUT} 2>&1
		fi
	else
		echo "     **************ERROR : The source file $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE is either missing or empty. Skipping.**************" >> ${STD_OUT} 2>&1
		continue
	fi
	
	# check if destination directory exist
	DEST_DIR=`dirname $DEST`
	if [ ! -d "$DEST_DIR" ]; then
		echo "     Destination directory $DEST_DIR does not exists. Skiping...." >> ${STD_OUT} 2>&1
		continue 
		#arr=$(echo $DEST_DIR | tr "/" "\n") 
		#for i in $arr; do
		#	curr_dest_dir="$curr_dest_dir/$i"
		#	# check if dir exist
		#	if [ ! -d "$curr_dest_dir" ]; then
		#	    echo "     Destination dir $curr_dest_dir does not exists. creating..." >> ${STD_OUT} 2>&1
		#		mkdir $curr_dest_dir
		#		chown $FILE_OWNER $curr_dest_dir
		#		chmod 750 $curr_dest_dir
		#		echo "     Destination dir $curr_dest_dir created." >> ${STD_OUT} 2>&1
		#	fi
		#done
	fi
	
	# check if to backup original file
	if [ "$BACKUP" = "Y" ]; then
		echo "     Translation sheet says to backup the original file. Checking if the original file exists..." >> ${STD_OUT} 2>&1
		if [ -f "$DEST" ]; then
		    echo "     The original file exists.Backing up..." >> ${STD_OUT} 2>&1
		    mv $DEST $DEST-$DATE_TIME
			echo "     Backup of the original file competed. Backup filename : $DEST-$DATE_TIME" >> ${STD_OUT} 2>&1
		else
			echo "     The original file does not exists. Will not do a backup." >> ${STD_OUT} 2>&1
		fi
	fi
	   
	# copy the source to destination 
	cp $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE $DEST
	if [ $? -ne 0 ]; then
		echo "     **************ERROR : The copying of file $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE to $DEST failed.**************" >> ${STD_OUT} 2>&1
		continue
	else
		echo "     The copying of file $PROMOTION_PACKAGE_LOCATION/package/promotion_files$SOURCE to $DEST completed." >> ${STD_OUT} 2>&1
	fi
	
	# check if owner is valid
	RES=`grep $FILE_OWNER /etc/passwd`
	if [ "$RES" = "" ]; then
	    echo "**************ERROR : The owner id $FILE_OWNER is not a valid id.**************" >> ${STD_OUT} 2>&1
		continue
	else
		RES=`grep $FILE_OWNER_GROUP /etc/group`
		if [ "$RES" = "" ]; then
			echo "**************ERROR :The group id $FILE_OWNER_GROUP is not a valid group.**************" >> ${STD_OUT} 2>&1
			continue
		else
			# owner and group is valid, proceed to change the ownership
			echo "Changing the owner:group of the file to $FILE_OWNER:$FILE_OWNER_GROUP..." >> ${STD_OUT} 2>&1
			chown $FILE_OWNER:$FILE_OWNER_GROUP $DEST
			echo "Successfully changed the owner:group of the file to $FILE_OWNER:$FILE_OWNER_GROUP." >> ${STD_OUT} 2>&1
		fi
	fi
	
	# check if the attribute is not blank
	if [ ! "$FILE_ATTRIB" = "" ]; then
		echo "Changing the file attribute of the file $DEST to $FILE_ATTRIB." >> ${STD_OUT} 2>&1
		chmod $FILE_ATTRIB $DEST
		echo "Successfully changed the file attribute of the file $DEST to $FILE_ATTRIB." >> ${STD_OUT} 2>&1
	fi
	
	# show the destination file
	ls -lrt $DEST >> ${STD_OUT} 2>&1
	
done

rm -rf $TRANSLATION_SHEET

echo "#######################################################" >> ${STD_OUT} 2>&1
echo "Reading of Release translation sheet completed." >> ${STD_OUT} 2>&1

############################ END MAIN ######################################
