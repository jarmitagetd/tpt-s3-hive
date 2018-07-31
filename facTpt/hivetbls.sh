#!/bin/bash

echo "Starting reference data hive table build..."

rm hive/hivetbls.txt
rm hive/hivetbls.hql
tbuild -f tptDdl -u "tablename='$tbl'" -v vTpt.txt

ref=refs.txt
IFS=':'

x=1

while read -r db tbl
do
 echo "DROP TABLE IF EXISTS $tbl;" >> hive/hivetbls.hql
 echo " "  >> hive/hivetbls.hql
 echo "CREATE EXTERNAL TABLE $tbl" >> hive/hivetbls.hql
 echo "(" >> hive/hivetbls.hql

tb1=$tbl

 col=hive/hivetbls.txt 
 while read -r tb cl dt cm
 do
  if [ "$tb" = "$tbl" ]; then
    echo $cl $dt $cm >> hive/hivetbls.hql
    echo adding $cl $dt $cm ....
  fi

 done < $col

 echo ")" >> hive/hivetbls.hql
 echo "ROW FORMAT DELIMITED" >> hive/hivetbls.hql
 echo "FIELDS TERMINATED BY '\t'" >> hive/hivetbls.hql
 echo "LINES TERMINATED BY '\n'" >> hive/hivetbls.hql
 echo "STORED AS TEXTFILE" >> hive/hivetbls.hql
 echo "LOCATION 's3n://rap-backend-testing/static-files/$tb1/';" >> hive/hivetbls.hql
 echo " " >> hive/hivetbls.txt>> hive/hivetbls.hql
 ((x++))
done < $ref
echo " " >> hive/hivetbls.hql
echo "quit;" >> hive/hivetbls.hql

hive -f hive/hivetbls.hql

echo hive table build complete.....2 reference tables built..
