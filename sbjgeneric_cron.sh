#!/bin/sh
function description
{
echo -e "
Purpose: Execute sqlplus using a desired sql file and if
    output exists then email it to specified recipients.

    This script expects the following:
     -The environment setup script must use the
      following naming convention, jobenv_<Instance>.
        -Refer to setupenv function in this script
         to alter location.
     -The sql password must be correct in the
      text file named sqlpasswords which is called
      in the environment setup script.
     -The SQL file must use the following naming
      convention, <Job Name>.sql
     -If an email is desired, the SQL file must spool
      to a file with the following naming convention,
      $OUTPUT_HOME/<Job Name>.lis
        -This value can be overridden using the
         '-o' or '--output' parameter. If using this
         parameter you must use the full path of the
         file because $OUTPUT_HOME which is read in
         from the environment setup script will not
         be used. When overriding, it is expected that
         the file will reside in the same directory as
         shell script so if that is the case then the full
         path is not needed and instead the filename is ok.
     -The following parameters must be filled:
      Database Instance, Job Name, Database Username.
     -Refer to arguments and usage examples for
      additional functionality."
}

function usage
{
description
echo -e "
Usage: $0 -i <DB Instance> -j <Job Name> [-e <Email Recipients>] [-f <Email Sender>] [-a <Email Attachments>] -u <SQL Username> [-p <SQL Parameters>] [-o <Output File>] [-l <Log File Name>] [-x <Filename] [-n] [-z <Banner EXE Parameter Filename>] [-d]
       $0 -i INST -j szrggg -e auser@here.com -f jobs@here.com -a \"some_data.lis some_data.csv\" -u ajobs_user -p \"201210 201140\" -o szrggg.sql -l szrggg.log -x szrggg -n -z szrggg.parms -d

Arguments:
         -i | --instance\tDatabase Instance
         -j | --job\t\tJob Name
         -e | --email\t\tEmail Recipients
         -f | --from\t\tEmail Sender
         -a | --attach\t\tEmail Attachment Filename(s)
         -u | --user\t\tDatabase Username
         -p | --parms\t\tSQL*Plus Parameters
         -o | --output\t\tUsed to override the default output
                         \tfile naming convention of <Job Name>.lis
         -l | --log\t\tUsed to override the default log
                         \tfile naming convention of <Job Name>.log
         -x | --exe\t\tBanner EXE Filename
         -n | --noenv\t\tDon't Set Oracle/Banner Environment
         -z | --exeparm\t\tBanner EXE Parameter Filename
         -d | --debug\t\tDisplay Debugging Output
         -h | --help\t\tDisplay This Message
"
}

function setupenv
{
   . /home/jobsuser/batch/$INSTANCE/jobenv_$INSTANCE
}

JMKDEBUG=0;
## Pick up command line arguments
while [ "$1" != "" ]; do
   case $1 in
      -i | --instance ) shift
                        INSTANCE=$1; export INSTANCE
                        ;;
      -j | --job )      shift
                        JOBNAME=$1; export JOBNAME
                        ;;
      -e | --email )    shift
                        EMAILUSERS=$1; export EMAILUSERS
                        ;;
      -f | --from )     shift
                        EMAILFROM=$1; export EMAILFROM
                        ;;
      -a | --attach )   shift
                        ATTACH=$1; export ATTACH
                        ;;
      -u | --user )     shift
                        SQLUN=$1; export SQLUN
                        ;;
      -p | --parms )    shift
                        SQLPARMS=$1; export SQLPARMS
                        ;;
      -o | --output )   shift
                        OUTPUT_FILE=$1; export OUTPUT_FILE
                        ;;
      -l | --log )      shift
                        LOG_FILE=$1; export LOG_FILE
                        ;;
      -x | --exe )      shift
                        EXE_FILE=$1; export EXE_FILE
                        ;;
      -n | --noenv )    NOENV=1; export NOENV
                        ;;
      -d | --debug )    JMKDEBUG=1; export JMKDEBUG
                        ;;
      -z | --exeparm )  shift
                        EXE_PARM=$1; export EXE_PARM
                        ;;
      -h | --help )     usage
                        exit
                        ;;
      * )               echo -e "Unrecognized Parameter Specified: $1"
                        usage
                        exit 1
                        ;;
   esac
   shift
done

## Make sure required variables have been filled.
if [ -z $INSTANCE ] || [ -z $JOBNAME ] || [ -z $SQLUN ]; then
   echo "You are missing a required variable."
   usage
   exit
fi

## Source some files to populate the environment
## for running Oracle/Banner applications.
if [ -z $NOENV ]; then
   setupenv
fi

if [ -z $OUTPUT_FILE ]; then
   OUTPUT_FILE="$OUTPUT_HOME"/"$JOBNAME.lis"
fi

if [ -z $EXE_PARM ]; then
   EXE_PARM="$JOBNAME.parms"
fi

if [ -z $LOG_FILE ]; then
   LOG_FILE="$OUTPUT_HOME"/"$JOBNAME.log"
fi

if [ -n "$EMAILFROM" ]; then
   EMAILFROMSTR=" -- -f $EMAILFROM"
fi

if [ -z $BATCH/"$JOBNAME".sql ]; then
  echo "Try again, the sql file doesn't exist!"
  usage
  exit 1
fi

## Assign some values to variables
SQLPWTMPVAR=${INSTANCE}_${SQLUN}
SQLPW=${!SQLPWTMPVAR}; export SQLPW

## Determine if the debug variable has been set
## and if so output some values to the console.
if [ "$JMKDEBUG" -eq "1" ]; then
   echo "Database Instance: $INSTANCE"
   echo "SQL Username: $SQLUN"
   echo "SQL Password: $SQLPW"
   echo "SQL*Plus Parameters: $SQLPARMS"
   echo "Mail To: $EMAILUSERS"
   echo "Mail From: $EMAILFROM"
   echo "Attachments: $ATTACH"
   echo "Lis File: $OUTPUT_FILE"
   echo "Log File: $LOG_FILE"
   echo "Bypass Environment Setup: $NOENV"
   echo "Banner EXE File: $EXE_FILE"
   echo "Banner EXE Parameter File: $EXE_PARM"
   echo "Output directory: $OUTPUT_HOME"
fi

## Run the SQL file and email the output if data exists.
echo "Job Name: $JOBNAME"
echo "Begin: `date`"
sqlplus -s "$SQLUN"/"$SQLPW" @$BATCH/"$JOBNAME".sql $SQLPARMS > "$LOG_FILE"
if [ -s "$OUTPUT_FILE" ]; then
   if `chkfl $OUTPUT_FILE "no rows selected"`; then
      echo "Report Not Mailed, 0 rows returned"
   else
      if [ -n "$EMAILUSERS" ]; then
         if [ -n "$ATTACH" ]; then
            (for i in $ATTACH; do uuencode $i $(basename $i); done; echo $JOBNAME) | mailx -s "$JOBNAME Output File" "$EMAILUSERS" $EMAILFROMSTR
         else
            cat "$OUTPUT_FILE" | mailx -s "$JOBNAME Output File" "$EMAILUSERS" $EMAILFROMSTR
         fi
      fi
      echo "Report mailed to: $EMAILUSERS"
   fi
   mv "$OUTPUT_FILE" "$OUTPUT_FILE.archive"
   mv "$LOG_FILE" "$LOG_FILE.archive"
else
   if [ -n "$EMAILUSERS" ]; then
      cat "$LOG_FILE" | mailx -s "$JOBNAME Log File" "$EMAILUSERS" $EMAILFROMSTR
      echo "Failed. Report Not Mailed, 0 byte file. Error Log Mailed Instead."
   fi
   mv "$LOG_FILE" "$LOG_FILE.archive"
fi

if [ -n "$EXE_FILE" ]; then
   "$EXE_HOME"/"$EXE_FILE" -f -o "$OUTPUT_HOME"/"$OUTPUT_FILE" 0< "$PARMS_HOME"/"$EXE_PARM" 1>$LOG_FILE 2>&1
   cat "$OUTPUT_FILE" | mailx -s "$JOBNAME Output File" "$EMAILUSERS" $EMAILFROMSTR
fi

echo -e "End: `date`\n"
