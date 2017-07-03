#!/bin/bash

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export PATH=$PATH:/u01/app/oracle/product/11.2.0/xe/bin
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export ORACLE_SID=XE

for i in /tmp/sql/01/*.sql
do
  echo "> Importing file $i ..."
  sqlplus system/oracle @"$i"
done

for i in /tmp/sql/02/*.sql
do
  echo "> Importing file $i ..."
  sqlplus GGAS_ADMIN/GGAS_ADMIN @"$i"
done
