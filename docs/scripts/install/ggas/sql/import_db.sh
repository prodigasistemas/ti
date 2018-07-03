#!/bin/bash

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export PATH=$PATH:/u01/app/oracle/product/11.2.0/xe/bin
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export ORACLE_SID=XE
export LOG_FILE=/tmp/ggas_import_database.log

[ -e "$LOG_FILE" ] && rm $LOG_FILE 

for i in /tmp/sql/01/*.sql
do
  echo "> Importing file $i ..." | tee -a $LOG_FILE
  sqlplus system/oracle @"$i" | tee -a $LOG_FILE
done

for i in /tmp/sql/02/*.sql
do
  echo "> Importing file $i ..." | tee -a $LOG_FILE
  sqlplus GGAS_ADMIN/GGAS_ADMIN @"$i" | tee -a $LOG_FILE
done
