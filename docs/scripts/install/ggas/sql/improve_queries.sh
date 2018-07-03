#!/bin/bash

cd /tmp/ggas/sql

dos2unix *.sql

for i in *.sql ; do echo " " >> "$i" ; done
for i in *.sql ; do echo "exit;" >> "$i" ; done

FILE=GGAS_SCRIPT_INICIAL_ORACLE_02_ESTRUTURA_CONSTRAINTS_CARGA_INICIAL.sql
SEARCH_STRING="CREATE OR REPLACE FUNCTION \"GGAS_ADMIN\".\"SQUIRREL_GET_ERROR_OFFSET\""
sed -i "s|$SEARCH_STRING|-- $SEARCH_STRING|" $FILE

# 2
FILE=GGAS_SCRIPT_INICIAL_ORACLE_01_ROLES.sql

FIND='DATAFILE'\''C:\\oracle\\product\\10.2.0\\oradata\\GGAS_DADOS01.DBF'\'''
REPLACE='DATAFILE'\''/u01/app/oracle/oradata/XE/GGAS_DADOS01.DBF'\'''

sed -i "/$FIND/ a $REPLACE" $FILE

sed -i "s|$FIND|--$FIND|g" $FILE

FIND='DATAFILE'\''C:\\oracle\\product\\10.2.0\\oradata\\GGAS_INDEX01.DBF'\'''
REPLACE='DATAFILE'\''/u01/app/oracle/oradata/XE/GGAS_INDEX01.DBF'\'''

sed -i "/$FIND/ a $REPLACE" $FILE

sed -i "s|$FIND|--$FIND|g" $FILE

# 3
FILE=GGAS_Ver-2.2.0_Seq-016_130.sql

sed -i "s|\t\t$||; s|\t$||; /^  --$/ d; /^  $/ d;" $FILE

#4
FILE=GGAS_Ver-2.2.0_Seq-018_130.sql

sed -i "/^    $/ d;" $FILE

#5
FILE=GGAS_Ver-2.2.0_Seq-022_130.sql

sed -i "/^    $/ d;" $FILE

#6
FILE=GGAS_Ver-2.2.0_Seq-034_130.sql

sed -i "/^  $/ d;" $FILE

#7
FILE=GGAS_Ver-2.2.0_Seq-057_MASTER_1464005.sql

sed -i "/^    $/ d;" $FILE

#8
FILE=GGAS_Ver-2.3.0_Seq-008_MASTER_1568768.sql

sed -i "/^insert into contrato_aba_atributo/,/^  select SQ_COAA_CD/ { /^insert into contrato_aba_atributo/ b ; /^  select SQ_COAA_CD/ b ; /^$/ d ; }" $FILE

sed -i "/^Insert into CONSTANTE_SISTEMA/,/^\tselect SQ_COST_CD/ { /^Insert into CONSTANTE_SISTEMA/ b ; /^\tselect SQ_COST_CD/ b ; /^$/ d ; }" $FILE

sed -i "/^Insert into TABELA_COLUNA/,/^  select SQ_TACO_CD/ { /^Insert into TABELA_COLUNA/ b ; /^  select SQ_TACO_CD/ b ; /^  $/ d ; }" $FILE

#9

#10
FILE=GGAS_Ver-2.7.9_Seq-012.sql

sed -i "s/^commit/commit;/" $FILE

#11
FILE=GGAS_Ver-2.7.9_Seq-016.sql

sed -i "s/^commit/commit;/" $FILE
