#!bin/bash
exec &> >(tee -a "load.log") 
cd "$(dirname "$0")"
clear
echo STARTING REFERENCE DATA
cd refTpt
bash export.sh
echo COMPLETED REFERENCE DATA
#echo starting hive table build....
#bash hivetbls.sh
echo STARTING TRANSACTION DATA
cd ../facTpt
bash export.sh
echo COMPLETED TRANSACTION DATA


