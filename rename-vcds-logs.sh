#!/bin/bash

######################## about start #########
# rename a VCDS CSV log file:
# - all CSV files within the execution dir of this script will be
#   prefixed with 20230603_1151_ aka '%Y%m%d_%H%M'
######################## about end #########

IFS="
"

function getDateFromLogTimeStamp() {
    local fileName="$1"
    # lazy test as we only accept a single log per file otherwise bail out or ignore if (--ignore was used)
    # check single timestamp
    # egrep matches for dates like: 'Tuesday,30,November,2021,18:15:16'
    local timestamps="`egrep '[a-zA-Z]*,[0-9]{1,2},[a-zA-Z]*,[0-9]{4},[0-9]{2}:[0-9]{2}:[0-9]{2}' "$fileName"`"
    local noOfTimestamps="`echo "$timestamps" | wc -l`"
    if [ "a${noOfTimestamps}b" == "a0b" ] ; then
        echo [error]: $x has no timestamp. Please check the file for timestamps like 'Tuesday,30,November,2021,18:15:16'
        exit 1
    elif $DO_ALLOW_ONLY_LOGS_WITH_ONE_TIMESTAMP && [ "a${noOfTimestamps}b" != "a1b" ] ; then
        echo [error]: $x has more than 1 initial timestamp. Please split the file and retry.
        echo "$timestamps"
        exit 1
    else
        if $DO_TOUCH ; then
            timestamps="`echo "$timestamps" | head -n1`" # grab the first timestamp in case there are more
            touchLikesThisDateFormat="`busybox date -d "$timestamps" -D '%A,%d,%B,%Y,%H:%M:%S'`"
            touch -d "$touchLikesThisDateFormat" "$fileName"
        fi

        FNC_RETURN="`busybox date -u '+%Y%m%d_%H%M' -d "$timestamps" -D '%A,%d,%B,%Y,%H:%M:%S'`"
    fi
}

function renameFile() {
    local x="$1"
    if ! test -e "$x" ; then
        echo "[error]: file $x does not exist"
        exit 1
    fi
    if $USE_DATE_FROM_LOG ; then
        getDateFromLogTimeStamp "$x"
        datePart="$FNC_RETURN"
    else
        datePart="`stat -c %y $x`"
        datePart=${datePart//[-:]/}
        datePart=${datePart// /_}
        [[ $datePart =~ $re ]]
        datePart=${BASH_REMATCH[1]}
    fi

    #echo $datePart
    [[ $x =~ $re2 ]]
    local newFileName="${datePart}_${BASH_REMATCH[2]}"
    if [ "$x" == "$newFileName" ] ; then
        echo "[info]: is same "$x""
    else
        echo "[info]: changed "$x" -> "$newFileName""
        mv "$x" "$newFileName"
    fi
}

function testForTools() {
    local isToolMissing=false
    local missingTools=""
    for tool in busybox egrep; do
        if ! type $tool &> /dev/null ; then
            isToolMissing=true
            missingTools+="[Error]: \"$tool\" is missing. Please install!\n"
        fi
    done

    if $isToolMissing ; then
        echo -e "$missingTools"
        exit 1
    fi
}

function printHelp() {
    input="`egrep -o -- '--.*]].*;.*#.*' $0`"
    inputCopy="$input"

    # find longest argument to get the output nice
    bigest=0
    while [[ "$input" =~ (--[a-zA-Z0-9-]*)\"\ *]][^#]*#\ *([^#]*)#(.*) ]] ; do
        if [ ${#BASH_REMATCH[1]} -gt $bigest ] ; then
            bigest=${#BASH_REMATCH[1]}
        fi
        input=${BASH_REMATCH[3]}
    done

    # print the help
    let bigest+=5 # spaces more
    while [[ "$inputCopy" =~ (--[a-zA-Z0-9-]*)\"\ *]][^#]*#\ *([^#]*)#(.*) ]] ; do
        printf "%-${bigest}s %s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        inputCopy=${BASH_REMATCH[3]}
    done
    exit 0
}

########### script flow ###########
USE_DATE_FROM_LOG=false
DO_TOUCH=false
DO_SINGLE_FILE=false
DO_ALLOW_ONLY_LOGS_WITH_ONE_TIMESTAMP=true
argCount=${#@}
while [ $argCount -gt 0 ] ; do

    if [[ "$1" == "--date-from-log" ]]; then # read creation date from inside log file#
        shift; let argCount-=1
        USE_DATE_FROM_LOG=true
    elif [[ "$1" == "--touch" ]]; then # set file creation date to --date-from-log#
        shift; let argCount-=1
        DO_TOUCH=true
    elif [[ "$1" == "--single" ]]; then # operate on single file --single YOUR.csv #
        shift; let argCount-=1
        DO_SINGLE_FILE=true
        if [ "a${1}b" == "ab" ] ; then
            echo "ERROR: You have to specify a single file for --single"
            echo "-->eg. --single LOG-17-003-xxx-xxx.csv"
            exit 1
        fi
        SINGLE_FILE=$1
        shift; let argCount-=1
    elif [[ "$1" == "--ignore" ]]; then # ignore multiple timestamps in log file, process the first only #
        shift; let argCount-=1
        DO_ALLOW_ONLY_LOGS_WITH_ONE_TIMESTAMP=false
    elif [[ "$1" == "--help" ]]; then # show this help #
        shift; let argCount-=1
        printHelp
    else
        echo "ERROR unknown parameter: $1"
        exit
    fi
done

testForTools

re='([0-9_]{0,13})'
re2='(.*)(LOG.*)'
# read the input files from current dir
inputFiles=($(ls *.CSV *.csv 2>/dev/null))
if [ ${#inputFiles[@]} -eq 0 ] ; then
    echo "[info]: no csv files to convert"
    exit 1
fi

if $DO_SINGLE_FILE ; then
    renameFile "$SINGLE_FILE"
else
    for x in ${inputFiles[@]} ; do
        renameFile "$x"
    done
fi
