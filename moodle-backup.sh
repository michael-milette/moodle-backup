#!/usr/bin/env bash
# Moodle Site Backup
# Version 0.7 (BETA) - 2019-02-11
# Copyright 2005-2019 TNG Consulting Inc (www.tngconsulting.ca)
# Author: Michael Milette
# License: GNU GPL 3.0 or later.
# Dependencies: 
#    ZIP with ZIP64_SUPPORT, PHP, MySQL, grep, cut, sed, find
# Has been tested on Ubuntu Server.
# Installation:
#    1) Place this script in the APPPATH folder.
#    2) Customize the configuration section.
#    3) Make the script executable: chmod +x moodle-backup.sh
# Usage: Run the script as "sudo" or with sufficient permissions.
# -------------------------------------------------------------------------------------
# Configuration section - Assumes Moodle's WEBROOT and DATA are under the APPPATH.
# -------------------------------------------------------------------------------------

# Timezone. See http://manpages.ubuntu.com/manpages/xenial/man3/DateTime::TimeZone::Catalog.3pm.html
TIMEZONE="America/Toronto"

# Path to the "php" executable.
PHP="/usr/bin/php"

# Path to the "mysqldump" executable.
MYSQLDUMP="/usr/local/bin/mysqldump"

# One level up from the webroot.
APPPATH="/var/www" 

# Name of your webroot directory of your Moodle site. Called "public_html" on some systems.
WEBROOT="html"     

# Name of your "moodledata" directory. Expected to be found one level up from your webroot.
DATAROOT="moodledata"

# Name of directory where backups will be stored. Expected to be found one level up from your webroot.
BACKUPPATH="backups"

# Optional: Manage backups
MANAGED=$(false)

# == Cloudways example == #
# MYSQLDUMP="/usr/bin/mysqldump"
# APPPATH="/home/99999999.cloudwaysapps.com/zzzzzzzzzz"
# WEBROOT="public_html"
# DATAROOT="private_html"

# -------------------------------------------------------------------------------------
# Exit script on error.
set -e
NOW=$(TZ=":$TIMEZONE" date +%Y-%m-%dT%H-%M-%S)

BACKUPPATH="$APPPATH/backups"
mkdir -p $BACKUPPATH/$NOW

cd $APPPATH

# Extract the database username, password and database name from the Moodle's config.php.
DBUSER=$(grep CFG-\>dbuser ${APPPATH}/${WEBROOT}/config.php | cut -d \' -f 2)
DBPASS=$(grep CFG-\>dbpass ${APPPATH}/${WEBROOT}/config.php | cut -d \' -f 2)
DBNAME=$(grep CFG-\>dbname ${APPPATH}/${WEBROOT}/config.php | cut -d \' -f 2)

echo 
echo "Moodle site backup - Please be patient, this can take a while..."
echo "Start time: $NOW"
echo "Saved in folder: $BACKUPPATH/$NOW"
echo
pushd $WEBROOT  >/dev/null

echo "Running CRON..."
$PHP admin/cli/cron.php >/dev/null

echo "Clearing Moodle cache..."
$PHP admin/cli/purge_caches.php
popd >/dev/null

echo "Backing up the database..."
$MYSQLDUMP -u ${DBUSER} -p${DBPASS} ${DBNAME} > $BACKUPPATH/$NOW/moodle.sql
DBUSER=;DBPASS=;DBNAME=

echo "Compressing database backup file..."
zip -jq  $BACKUPPATH/$NOW/moodle.sql.zip $BACKUPPATH/$NOW/moodle.sql
rm $BACKUPPATH/$NOW/moodle.sql

echo "Backing up the Moodle files..."
zip -qr $BACKUPPATH/$NOW/moodle.zip ${WEBROOT}

echo "Backing up the moodledata files..."
zip -qr $BACKUPPATH/$NOW/moodledata.zip ${DATAROOT}

if [ $MANAGED ]; then
   # Optional: Combine backup files into single TGZ file and delete TGZ files older than 30 days.
   echo "Combining backups into a single file..."
   tar -zcpf $BACKUPPATH/$NOW.tgz $BACKUPPATH/$NOW/moodle.sql.zip $BACKUPPATH/$NOW/moodle.zip $BACKUPPATH/$NOW/moodledata.zip
   rm -rf $BACKUPPATH/$NOW
   # Automatically delete backups older than 30 days.
   sudo find $BACKUPPATH -name "*.tgz" -mtime +30 -exec rm {} \;
fi

echo "================================================"
echo "Moodle Backup Successfully Completed"
echo "================================================"
echo "Started at $NOW"
NOW=$(TZ=":$TIMEZONE" date +%Y-%m-%dT%H-%M-%S)
echo "Completed at $NOW"
echo "Saved in folder: $BACKUPPATH"
echo
echo "Verify that file sizes are about consistent with previous backups:"
ls -l --block-size=M $BACKUPPATH
echo "================================================"
