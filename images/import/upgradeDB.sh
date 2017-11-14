#!/bin/bash

run_sql_upgrade_scripts() {

   echo "Running SQL upgrade scripts...."
   # The following is the preferred way of comparing the
   # version.  supported upgrade path to 11.0 start from 10.2.x
   if [[ $version -le 100202 ]]; then
      echo "Running 10.2.2 upgrade  logic"
      run_sql_script "$script_home/ddl/upgrade" "cloud" "upgrade-10.2.1-10.2.2.sql" "upgrade10.2.2.log" "Running SQL upgrade script upgrade-10.2.1-10.2.2.sql"
   fi;
   if [[ $version -le 100204 ]]; then
      echo "Running 10.2.4 upgrade  logic"
      run_sql_script "$script_home/ddl/upgrade" "cloud" "upgrade-10.2.3-10.2.4.sql" "upgrade10.2.4.log" "Running SQL upgrade script upgrade-10.2.3-10.2.4.sql"
   fi;
   if [[ $version -le 100205 ]]; then
      echo "Running 10.2.5 upgrade  logic"
      run_sql_script "$script_home/ddl/upgrade" "cloud" "upgrade-10.2.4-10.2.5.sql" "upgrade10.2.5.log" "Running SQL upgrade script upgrade-10.2.4-10.2.5.sql"
   fi;
   if [[ $version -le 100207 ]]; then
      echo "Running 10.2.7 upgrade  logic"
      run_sql_script "$script_home/ddl/upgrade" "cloud" "upgrade-10.2.6-10.2.7.sql" "upgrade10.2.7.log" "Running SQL upgrade script upgrade-10.2.6-10.2.7.sql"
   fi;
   if [[ $version -le 100210 ]]; then
      echo "Running 10.2.10 upgrade  logic"
      run_sql_script "$script_home/ddl/upgrade" "cloud" "upgrade-10.2.9-10.2.10.sql" "upgrade10.2.10.log" "Running SQL upgrade script upgrade-10.2.9-10.2.10.sql"
   fi;
   if [[ $version -le 110000 ]]; then
      echo "Running 11.0.0 upgrade  logic"
      convertSqlFileName="$script_home/ddl/upgrade/storageEngineConvert.sql"
      # Moving tables to InnoDb Engine, to support group replication.
      convert_tables_to_innodb "$script_home/ddl/upgrade" $convertSqlFileName
      run_sql_script "$script_home/ddl/upgrade" "cloud" "$convertSqlFileName" "upgrade1100-engineconvert.log" "Running SQL upgrade script to convert storage engine to InnoDB."
      run_sql_script "$script_home/ddl/upgrade" "cloud" "jbpm.sql" "jbpm.log" "Adding jbpm tables if they are missing."
      # indicies file
      run_sql_script "$script_home/ddl/upgrade" "cloud" "indices.sql" "indices-11.0.0.log" "Agility 11.0.0 index changes"
      # Adding Primary keys
      run_sql_script "$script_home/ddl/upgrade" "cloud" "add-11.0.0-primarykeys.sql" "add-11.0.0-primarykeys.log" "Adding Primary key for tables with missing Primary key."
      # primary key update
      run_sql_script "$script_home/ddl/upgrade" "cloud" "primaryKeyUpdate.sql" "primaryKeyUpdate.log" "Creating procedures for Updating Primary keys."
      # Other 11.0 schema changes
      run_sql_script "$script_home/ddl/upgrade" "cloud" "upgrade-10.2.x-11.0.0.sql" "upgrade-10.2.x-11.0.0.log" "Additional 11.0.0 database changes"
      run_sql_script "$script_home/ddl/upgrade" "cloud" "upgrade-os-10.2.x-11.0.0.sql" "upgrade-os-10.2.x-11.0.0.log" "Upgrading osTaxonomy with recent Linux OS versions"
      run_sql_script "$script_home/ddl/upgrade" "cloud" "TempConstraintTable.sql" "TempConstraintTable.log" "Upgrading a stored procedure."

   fi;
}

run_sql_script() {
  reqArgCount=5
  baseFolder=$1
  dbSchema=$2
  scriptFile=$3
  logFile=$4
  message=$5

  if [ $# -lt $reqArgCount ]
  then
    echo "invalid run_sql_upgrade() usage. needs $reqArgCount arguments, but recieved only $#"
    exit -1
  fi
  echo $message
  cd $baseFolder
  mysql $MYSQLOPTS $dbSchema < $scriptFile 2>&1 | tee  /var/spool/agility/upgrades/$logFile
  if  [[ "${PIPESTATUS[0]}" != "0" ]]; then
    echo "Failure occurred in $scriptFile script."
    exit -1;
  fi
}

convert_tables_to_innodb() {
  reqArgCount=2
  baseFolder=$1
  sqlFileName=$2

  if [ $# -lt $reqArgCount ]
  then
    echo "invalid convert_tables_to_innodb() usage. needs $reqArgCount arguments, but recieved only $#"
    exit -1
  fi
  echo "Generating script for converting storage engine to InnoDB to suport MyySQL group replication."
  cd $baseFolder
  echo "SELECT concat('ALTER TABLE \`', TABLE_SCHEMA, '\`.\`', TABLE_NAME,'\` ENGINE=InnoDB; #was ', engine)
               As '# Script to move tables to InnoDB storage engine to support group replication '
  FROM Information_schema.TABLES
  WHERE ENGINE != 'InnoDB'
  AND TABLE_SCHEMA in ('metric', 'event', 'activity', 'cloud')" | mysql -N $MYSQLOPTS cloud > $sqlFileName
}

waitForMysql() {
   while
      mysqladmin $MYSQLOPTS -s status
      (($? != 0))
   do
      sleep 5
   done
}

setup() {
   echo "Starting mysqld to updgrade the db"
   mysqld --user=mysql &
   waitForMysql
   mkdir /var/spool/agility/upgrades
   /usr/bin/mysql_upgrade -p$MYSQL_PASSWORD
}

cleanup() {
   mysqldPID=`pgrep mysql`
   kill -9 $mysqldPID
   rm -f /var/lib/mysql/mysql.sock*
}

#################
##### MAIN ######

script_home=`pwd`
version=""
dbpresent=""
vers_present=""

MYSQLOPTS="-u$MYSQL_USER -p$MYSQL_PASSWORD"

setup

dbpresent=`mysql $MYSQLOPTS -s -f -e "show databases" | grep "^cloud$"`

if [ "$dbpresent" == "cloud" ]; then
  vers_present=`mysql $MYSQLOPTS -s -D cloud -f -e "show tables like 'product_version'" | grep product_version`
fi;

if [ "$vers_present" == "product_version" ]; then
  echo "Checking current product version."
  version=`mysql $MYSQLOPTS -s -f -e "select max(major*10000+minor*100+build) from cloud.product_version" | tail -1`
  if [ "$version" == "NULL" ]; then
           echo "Current product version is empty: Nothing to do";
           exit 0;
  fi;
  echo "Current product version: $version"
fi;

echo "Upgrading Database from Version $version";
run_sql_upgrade_scripts
cleanup
