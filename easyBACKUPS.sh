#!/bin/bash

# easyBACKUPS
# BACKUP SYSTEM FOR WEM'S SERVERS.
# MANAGER: EASYENGINE.
# 1) MySQL dump. DONE
# 2) Compress accounts folders DONE
# 3) Transfer all mysql files, tars, and logs to remote location. DONE
# 4) Cleanup files older than 7 days on primary locations. DONE
# 5) Cleanup files older than 7 days in remote locations. DONE
# 7) Cron
#
# Created on 2016-07-18
# Author: Otháner Kasiyas
# Version: 1.0

# START
#INIT. VARIABLES FOR FILENAMING, TIMESTAMPS AND PATHS.
TIMESTAMP=$(date +"%F")
THIS_SERVER="REMOTE_SERVER_NAME"
REMOTE_SERVER="REMOTE_SERVER_IP"
BACKUP_CLEANUP_DIR="/backups/easyBACKUPS/"
BACKUP_DIR="/backups/easyBACKUPS/$TIMESTAMP"
MYSQL_USER="BACKUP_MYSQL_USER"
MYSQL=/usr/bin/mysql
MYSQL_PASSWORD="XXXXXXXXXXXXXXXXXXXXXX"
MYSQLDUMP=/usr/bin/mysqldump
OLDER_THAN=7

mkdir -p $BACKUP_CLEANUP_DIR

# Setting up all sites
echo -e "########################################"
echo -e "         CURRENT SITES ENABLED          "
echo -e "########################################"
SitesEnabled=(/etc/nginx/sites-enabled/*)
for f in "${SitesEnabled[@]}";
do
   echo "$f"
done

# BACKUP MYSQL DATABASES
echo -e "########################################"
echo -e "         BACKUP MYSQL DATABASES         "
echo -e "########################################"
echo "Creating temporary directory"
mkdir -p "$BACKUP_DIR/mysql"
databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`

for db in $databases; do
  echo "Mysqldump for $db"
  $MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | gzip > "$BACKUP_DIR/mysql/$db.gz"
done

echo "Compress MySQL Backup directory"
tar cvzf "$BACKUP_DIR/mysql-${TIMESTAMP}.tar.gz" "$BACKUP_DIR/mysql/" --absolute-names
echo "Deleting MySQL Backup temporary directory"
rm -rfv $BACKUP_DIR/mysql/

# Archive and compress dirctories
echo -e "########################################"
echo -e "       BACKUP WEBSITES DIRECTORIES      "
echo -e "########################################"
cd /var/www/;
for dir in */
  do
    base=$(basename "$dir")
    echo "Compressing ${base}"
    tar czf "${base}.tar.gz" "$dir"
    echo "Moving ${base} to $BACKUP_DIR"
    mv "${base}.tar.gz" $BACKUP_DIR
done

# Create placeholders in remote server.
echo -e "#########################################"
echo -e "        TRANSFER TO REMOTE SERVER        "
echo -e "#########################################"
echo "Conecting to $REMOTE_SERVER and creating directory."
ssh root@$REMOTE_SERVER "mkdir -p $BACKUP_DIR/$THIS_SERVER/"
echo "Directory $BACKUP_DIR/$THIS_SERVER/ created on $REMOTE_SERVER."
# Cleaning up remote backups olders than 7 days
echo "Cleaning REMOTE backups older than $OLDER_THAN days."
ssh root@$REMOTE_SERVER "cd $BACKUP_CLEANUP_DIR && find . -type d -ctime $OLDER_THAN -ls"
echo "Cleaned up!"
#Transfer backup to remote server.
echo "Transfer backup to ${REMOTE_SERVER}"
scp ${BACKUP_DIR}/* "root@${REMOTE_SERVER}:$BACKUP_DIR/$THIS_SERVER/"
echo -e "#########################################"
echo -e "BACKUP TRANSFERRED SUCCESSFULLY, COWGIRL!"
echo -e "#########################################"

# Cleaning up local backups olders than 7 days
echo -e "########################################"
echo -e "         CLEANING LOCAL BACKUPS         "
echo -e "########################################"
echo "Cleaning LOCAL backups older than $OLDER_THAN days."
find ${BACKUP_CLEANUP_DIR}* -type d -ctime $OLDER_THAN | xargs rm -rfv
echo "Cleaned up!"

#THE END.
echo -e "#############################"
echo -e "         GOODBYE! ;)         "
echo -e "#############################"
