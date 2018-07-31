#!/bin/bash
#-------------------------------------------------------------------------------#
#  Project:     Range Tooling Project                                           #
#  Description: Reference data extraction using Teradata Parralel Transporter   #
#  Version:     1.0                                                             #
#  Style:       https://google.github.io/styleguide/shell.xml                   #
#  Date:        05/09/2017                                                      #
#  Author:      James Armitage                                                  #
#  Company:     Teradata                                                        #
#  Email:	james.armitage@teradata.com                                     # 
#-------------------------------------------------------------------------------#


#-------------------------------------------------------------------------------#
# STEP 1                                                                        #
# clear screen for interactive terminal session                                 #
# declare environmental variables, constants and initial variables              #
# set present working directory for execution and put the Linux PID             #
# (process id) into the file pid                                                #
#-------------------------------------------------------------------------------#

# clear screen
#clear

# echo step for interactive terminal sessions
#echo refTPT STEP 1  
echo REFERENCE DATA

# delcare environmental variable PATH for system execution
export PATH="/opt/teradata/client/15.10/bin:/usr/local/bin:/bin:/usr/bin:\
            /usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:\
            /usr/local/hadoop/hadoop-2.8.0/bin:\
            /usr/lib/apache-hive-2.1.0-bin/bin:\
            /usr/lib/apache-hive-1.2.2-bin/bin:\
            /usr/lib/db-derby-10.13.1.1-bin/bin:\
            /home/ec2-user/.local/bin:/home/ec2-user/bin"

# declare constants
readonly TYP="REFERENCE"
readonly LOG="log"
readonly PRM="params"
readonly TPT="tpt"
readonly MET="metadata"

# assign reference data object file, date and time to initial variables
ref="$PRM/refs.txt"
dte=$(date +%Y%m%d)
tme=$(date | awk '{print $4}')

# set present working directory for bash execution from anywhere
cd "$(dirname "$0")"

# put the PID into a file.  Useful for admin if there are execution issues
echo "$$" > pid

#-------------------------------------------------------------------------------#
# STEP 2                                                                        #
# If statement checks for the to do and done files. If the files exist a diff   #
# is peformed between the two to facilitate a checkpoint restart.  If the files #
# do not exist then the full list of reference data objects (refs.txt) is       #
# copied to the to do list file (too_do.txt)                                    #
#-------------------------------------------------------------------------------#

# echo step for interactive terminal sessions
#echo refTPT STEP 2

if [ -f to_do.txt ] && [ -f done.txt ]; then
  echo CHECKPOINT START
  # assign diff output to variable z
  z=$(diff "to_do.txt" "done.txt") 
  # using awk to pipe the object names to to do file
  echo "$z" | grep "<" | awk '{print $2}' > to_do.txt
else 
  echo NO CHECKPOINT START
  # copy all reference data objects from refs.txt into to to_do.txt
  cp $ref "to_do.txt"
fi

# assign too_do list to to_do variable
to_do="to_do.txt"

#--------------------------------------------------------------------------------#
# STEP 3                                                                         #
# read in to_do list from file assigning database and tablename to variables     #
# $db and $obj. The file format is databasename:tablename. The databasename and  #
# tablename are passed to the tpt tbuild string. The tablename is used for S3    #
# folder and file creation.  The filenames also contain the loaded date. This    #
# date is generated by the Linux Bash not sourced from the data warehouse        #
# system (not all files have a load date). The databasename and object name are  #
# passed into a while loop and processed sequentially.  Errors are piped to      #
# stderr as well as object and job log files                                     #
#--------------------------------------------------------------------------------#
# Variables used:                                                                #
# $dte :the system date                                                          #
# $tme :the system time                                                          #
# $db  :source database                                                          #
# $obj :source table                                                             #
# $x   :tpt exit code                                                            #
# $f   :filepath                                                                 #
# $n   :filename                                                                 #
# $b   :filesize in bytes                                                        #
# $T   :constant for object type                                                 #
#--------------------------------------------------------------------------------#

# echo step for interactive terminal sessions
#echo refTPT STEP 3

# set International Field Seperator (delimiter)
IFS=':'

# while read inputs to_do.txt 
while read -r db obj
do  	
  
  echo $obj TPT EXPORT JOB STARTED 
  # remove existing extract file from S3 bucket. Pattern is truncate and reload
  # aws s3 rm --recursive s3://rap-backend-testing/static-files/"$obj"/ 2>"$LOG"/"$obj$dte".log 1>&2  
  
  # set seconds to 0
  SECONDS=0
  
  # tbuild statement to execute Teradata Parallel Transporter 1>&2 pipe to stdout
  tbuild -s1 -f "$TPT"/tptRef -v "$PRM"/vTpt.txt -u "databasename='"$db"' \
  tablename='"$obj"', FileName='"$obj"' Date1='"$dte"'" 2>"$LOG"/"$obj$dte".log 1>&2  
  
  # capture duration of tpt job execution and assign to duration variable
  duration=$SECONDS 
  
  # add object name to twb_status.txt - required for performance metrics
  echo $(sed 's/^/'"$db"' '"$obj"' '"$dte"' /' "$MET"/twb_status.txt) > "$MET"/twb_status.txt
  
  # format twb_status.txt as pipe delimited file as db and tb name are 
  # variable length.  This is a change to tpt default status job file format
  echo $(cat "$MET"/twb_status.txt | awk '{print $1"|"$2"|"$3"|"$4"|"$5"|"$6"|"$7\
  "|"$8"|"$9"|"$10"|"$11$12$13"|"$14"|"$15"|"$16"|"$17"|"$18"|"$19"|"$20"|"$21\
  "|"$22"|"$23}') > "$MET"/twb_status.txt
 
  # string manipulation - assign output to variables described in STEP2 comment
  # $x get exit code from tpt log file
  x=$(cat "$LOG/$obj$dte.log" | grep "TPT Exit code set to" | awk '{gsub( \
  "[.]+","",$8); print $8}')

  # $f get file path from tpt log file remvoving single quotes
  f=$(cat "$LOG/$obj$dte.log" | grep "Operator instance 1 processing file" | awk '{\
  print $7}' | tr -d \')
   
  # $f remove trailing . from $f string
  f=$(echo ${f%?})
  
  # $n get filename from filepath $f
  n=${f#*A/}

  # $b get file size in bytes
  b=$(ls -l "$f" | awk '{print $5}')

  # $c get row count
  c=$(cat "$LOG/$obj$dte.log" | grep "Total Rows Exported" | awk -F ":" '{\
  gsub(" ", "", $3); print $3}')
  
  # create job control table load file
  echo "$dte"\|"$db"\|"$obj"\|"$TYP"\|"$tme"\|`date | awk '{print \
  $4}'`\|"$duration"\|"$c"\|"$x"\|"$f"\|"$n"\|"$b" >> "$MET"/meta.txt

  # create job control table load file
  #echo "$dte"\|"$db"\|"$obj"\|"$TYP"\|"$tme"\|`date | awk '{print \
  #$4}'`\|"$duration"\|`cat "$LOG/$obj$dte.log" | grep "Total Rows Exported" | awk -F ":" '{\
  #gsub(" ", "", $3); print $3}'`\|"$x"\|"$f"\|"$n"\|"$b" >> "$MET"/meta.txt  
  
  # call tptStatus job to load the job status metadata
  tbuild -f "$TPT"/tptStatus -v "$PRM"/vTpt.txt 2>>"$LOG"/"$obj$dte".log 1>&2
  
  # copy object and load status metadata to main job log file
  echo $(cat "$LOG/$obj$dte".log) >> "$LOG"/job"$dte".log
  
  # kill tbuild process.
  pkill -f tbuildexe
  
  # echo output to interactive terminal session
  echo "$obj" TPT EXPORT COMPLETED "$c" ROWS EXPORTED $b BYTES DURATION "$duration" SECONDS

  # copy databasename:objectname to done list
  echo "$db":"$obj" >> done.txt 

done < "$to_do"

#--------------------------------------------------------------------------------#
# STEP 4                                                                         #
# execute metadata load to control table.  Once the metadata has been loaded     #
# perform tidy up of files                                                       #
#--------------------------------------------------------------------------------#

# echo step for interactive terminal sessions
echo LOADING METDATA TO THE JOB CONTROL TABLE

# call tpt data load job.  More efficient to load metadata at the end than 
# executing tbuild for this inside while loop
tbuild -s1 -f $TPT/tptMeta -v $PRM/vTpt.txt 2>>$LOG/job$dte.log 1>&2

# perform tidy up of runtime files as tpt loop has completed
# remove to do and done files in readiness for next execution
rm to_do.txt done.txt

# copy metadata load file to a date stamped copy for audit. 
cp "$MET"/meta.txt "$MET"/meta"$dte".txt

# remove the metadata file in readiness for the next execution
rm "$MET"/meta.txt

# ensure all tbuildexe processes are stopped
pkill -f tbuildexe

# echo step for interative terminal sessions
echo REFERENCE DATA EXPORT JOB COMPLETED SUCCESSFULLY

