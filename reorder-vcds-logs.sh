#!/bin/bash

######################## about start #########
# reorder a VCDS CSV log file so that the measurement
# blocks are in ascending order:
# - -> blocks: 008-004-001 will be reordered like this 001-004-008
# - all CSV files within the execution dir of this script will be
#   converted and stored into $outputDir.
# - The filenames will also be changed to reflect the CSV reordering
######################## about end #########

########### global variables definition start ###########
outputDir="converted"
# format: 'measuring block;group id;start column;end column'
reGroupDataPattern='(.*);(.*);(.*);(.*)'
MARK_REORDERED_FILE=".reordered"
########### global variables definition end ###########

########### function definition start ###########
function testForTools() {
    local isToolMissing=false
    local missingTools=""
    for tool in cat head tail sed awk tee dos2unix unix2dos; do
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

function extractGroupDataRow() {
    local inputFile="$1"
    local extraColumnSeparaters=",,,,"
    local groupRow="`cat "$inputFile" | head -n 4 | tail -n 1 | sed -e 's@@@g'`$extraColumnSeparaters"
    # test data groupRow=",Group A:,'011,,,,Group B:,'003,,,,Group C:, Not Running${extraColumnSeparaters}"
    echo "$groupRow"
}

# output globals: groups
function extractGroupDataColumnRanges() {
    local inputFile="$1"
    local wasThereAGroupBefore=false

    # format for group see $reGroupDataPattern
    local group=""
    OLDIFS="$IFS"
    IFS=","
    local groupRow=($(extractGroupDataRow "$inputFile"))
    local length=${#groupRow[@]}

    local column=0
    for part in ${groupRow[@]} ; do
        if [[ $part =~ (Group.*) ]] ; then
            local grpName=${BASH_REMATCH[1]}
            grpName=${grpName// /-}
            if  [[ ${groupRow[$column+1]} =~ \'*([0-9]*|\ Not\ Running) ]]; then

                if $wasThereAGroupBefore ; then
                    group+=";$(($column-1))"
                    groups+=($group)
                else
                    wasThereAGroupBefore=true
                fi

                if [ "a${BASH_REMATCH[1]}b" == "a Not Runningb" ]; then
                    group="xxx;$grpName;$column"
                else
                    group="${BASH_REMATCH[1]};$grpName;$column"
                fi
            fi
        fi

        let column+=1
        if [ $length -eq $(($column+1)) ]; then # -> last column -> finish last group
            group+=";$column"
            groups+=($group)
        fi
    done
    IFS="$OLDIFS"
}

# uses globals: sortedData
# output globals: argsStatement, formatStatement, sedStatements
prepareRenamingOfGroupRow() {
    local startAbcInAscci=65
    local colFormat="%s,"

    for group in ${sortedData[@]}; do

        [[ $group =~ $reGroupDataPattern ]]
        local grpName=${BASH_REMATCH[2]}
        local grpBegin=$((${BASH_REMATCH[3]} + 1))
        local grpEnd=$((${BASH_REMATCH[4]} + 1))

        local newGrpId="`awk 'BEGIN{printf "%c", '$startAbcInAscci'}'`"
        let startAbcInAscci+=1

        sedStatements+=" -e \"s@${grpName}@Group $newGrpId:@g\""
        #echo "DBG grpBegin=$grpBegin grpEnd=$grpEnd"
        for column in $(seq $grpBegin $grpEnd) ; do
            argsStatement+="\$${column},"
            formatStatement+="$colFormat"
        done
    done
}

# uses globals: argsStatement, formatStatement, sedStatements
function reArrangeCsvFile() {
    local inputFile="$1"
    local outputFile="$2"
    local forStLe=$((${#formatStatement}-1))
    local argStLe=$((${#argsStatement}-1))

    cat "$inputFile" | dos2unix | head -n 3 | unix2dos | tee "$outputFile" > /dev/null
    cat "$inputFile" | dos2unix | tail -n +4 | eval "awk -F',' '{printf \"${formatStatement:0:$forStLe}\\n\" , ${argsStatement:0:$argStLe}}' | sed $sedStatements" | unix2dos | tee -a "$outputFile" > /dev/null


    # keep the timestamps for the file
    touch -r "$inputFile" "$outputFile"
}

# uses global: groups
# output global: sortedData
function sortGroupData() {
    local sortData="${groups[*]}"
    sortData="${sortData// /\\n}"
    sortedData=`echo -e $sortData | sort`
    sortedData="${sortedData/// }"
}

reFilePattern='(.*LOG-[0-9]{2})-([0-9x]{3})-([0-9x]{3})-([0-9x]{3})(.*)'
# uses return global: FNC_RETURN
function reorderFileName() {
    local oldFileName="$1"
    local sortedGroupsData="$2"
    sortedGroupsData=($sortedGroupsData)

    if ! [[ $oldFileName =~ $reFilePattern ]] ; then
        echo "$oldFileName is bad. Please adjust manually to be like: $reFilePattern"
        exit 1
    fi
    local fileNameParts=${BASH_REMATCH[2]}
    fileNameParts+=" ${BASH_REMATCH[3]}"
    fileNameParts+=" ${BASH_REMATCH[4]}"
    local preName=${BASH_REMATCH[1]}
    local postName=${BASH_REMATCH[5]}

    local sortDataPrepared="${fileNameParts// /\\n}"
    local sortedFileNameParts=`echo -e $sortDataPrepared | sort`

    sortedFileNameParts="${sortedFileNameParts/// }"
    sortedFileNameParts=($sortedFileNameParts)

    local newFileName="${preName}-${sortedFileNameParts[0]}-${sortedFileNameParts[1]}-${sortedFileNameParts[2]}${postName}"

    # verify new filename matches proposed CSV order
    local cnt=0
    for part in ${sortedFileNameParts[@]} ; do
        [[ ${sortedGroupsData[$cnt]} =~ $reGroupDataPattern ]]
        let cnt+=1
        measurementBlock=${BASH_REMATCH[1]}
        if ! [ "$part" == "$measurementBlock" ] ; then
            echo "[Error]: $oldFileName the name of the file somehow does not match the reordered content"
            exit 1
        #else
        #    echo  "DB SAME: "$part" == "$measurementBlock" "
        fi
    done

    FNC_RETURN=$newFileName
}

function printHelp() {
    local input="`egrep -o -- '--.*]].*;.*#.*' $0`"

    #### internal helper functions -- start
    function __determineLongest() {
        local option="$1"
        if [ ${#option} -gt $longest ] ; then
            longest=${#option}
        fi
    }

    function __printOptionAndText() {
        local option="$1"
        local text="$2"
        printf " %-${longest}s %s\n" "${option}" "${text}"
    }

    local reAllOptions='(--[a-zA-Z0-9-]*)\"\ *]][^#]*#\ *([^#]*)#(.*)'
    local reArgAndHelp='>>(.*)<<\ (.*)'
    function __processHelpOptions() {
        local input="$1"
        local methodPointer="$2"
        while [[ "$input" =~ $reAllOptions ]] ; do
            local option=${BASH_REMATCH[1]}
            local text=${BASH_REMATCH[2]}
            local remaining=${BASH_REMATCH[3]}

            # check if option has arg specified in $text
            if [[ "$text" =~ $reArgAndHelp ]] ; then
                arg=${BASH_REMATCH[1]}
                text=${BASH_REMATCH[2]}
                option+=" $arg"
            fi

            $methodPointer "$option" "$text"
            input="${remaining}"
        done
    }
    #### internal helper functions -- end

    # find longest option to get the output nice
    local longest=0
    __processHelpOptions "$input" "__determineLongest"
    let longest+=1 # more space(s)

    # print the help
    echo -e "Usage: ` basename $0` [OPTION]...\n"
    __processHelpOptions "$input" "__printOptionAndText"
    exit 0
}

function readUserAnswerAndExitIfNotYes() {
    read answer
    if [ "a${answer}b" != "aYESb" ] ; then
        einfo "You did well and double check everything now!!!"
        exit 0
    fi
}
########### function definition end ###########


########### script flow ###########
DO_CHECK=false
DO_ALLOW_ONLY_LOGS_WITH_ONE_TIMESTAMP=true
DO_CLEAN=false
argCount=${#@}
while [ $argCount -gt 0 ] ; do

    if [[ "$1" == "--check" ]]; then # use md5sum to compare the input file with the output#
        shift; let argCount-=1
        DO_CHECK=true
    elif [[ "$1" == "--ignore" ]]; then # ignore multiple timestamps in log file #
        shift; let argCount-=1
        DO_ALLOW_ONLY_LOGS_WITH_ONE_TIMESTAMP=false
    elif [[ "$1" == "--clean" ]]; then # remove the outputDir and unmark dir as processed #
        shift; let argCount-=1
        DO_CLEAN=true
    elif [[ "$1" == "--help" ]]; then # show this help #
        shift; let argCount-=1
        printHelp
    else
        echo "ERROR unknown parameter: $1"
        exit
    fi
done


if $DO_CLEAN ; then
    if [ "a${outputDir}b" != "ab" ] && [ "a${outputDir}b" != "a/b" ] \
        &! [[ ${outputDir} =~ \* ]] && test -e "$outputDir" ; then
        echo "[info]: DELETE old outputDir \"$outputDir\". Type YES to do so!"
        readUserAnswerAndExitIfNotYes
        rm -rf -- "$outputDir"
        test -e "$MARK_REORDERED_FILE" && rm -- "$MARK_REORDERED_FILE"
    fi
fi

if test -e "$MARK_REORDERED_FILE" ; then
    echo "[info]: this directory only contains ordered files. If you still want to try to reorder remove the file \"$MARK_REORDERED_FILE\" first."
    exit 1
fi

# read the input files from current dir
inputFiles=($(ls *.CSV *.csv 2>/dev/null))
if [ ${#inputFiles[@]} -eq 0 ] ; then
    echo "[info]: no csv files to convert"
    exit 1
fi

testForTools
if test -e "$outputDir" ; then
    echo "OUTPUT DIR: \"$outputDir\" already exists, please remove first"
    exit 1
else
    mkdir -p "$outputDir"
fi

sedReplaceSpaceTemporary=" -e 's@Group \(.\):@Group-\1:@g'"
for x in ${inputFiles[@]} ; do
    # lazy test as we only accept a single log per file otherwise bail out or ignore if (--ignore was used)
    # check single timestamp
    timestamps="`egrep '[a-zA-Z]*,[0-9]{1,2},[a-zA-Z]*,[0-9]{4},[0-9]{2}:[0-9]{2}:[0-9]{2}' "$x"`"
    noOfTimestamps="`echo "$timestamps" | wc -l`"
    if [ "a${noOfTimestamps}b" == "a0b" ] ; then
        echo [error]: $x has no timestamp. Please check the file for timestamps like 'Tuesday,30,November,2021,18:15:16'
        exit 1
    elif $DO_ALLOW_ONLY_LOGS_WITH_ONE_TIMESTAMP && [ "a${noOfTimestamps}b" != "a1b" ] ; then
        echo [error]: $x has more than 1 initial timestamp. Please split the file and retry.
        echo "$timestamps"
        exit 1
    fi
    groups=()
    sortedData=""
    extractGroupDataColumnRanges $x
    sortGroupData

    baseName="$(basename "$x")"
    reorderFileName "$baseName" "$sortedData"
    newFileName="$FNC_RETURN"

    argsStatement="\$1,"
    formatStatement="%s,"

    sedStatements="$sedReplaceSpaceTemporary"

    prepareRenamingOfGroupRow

    sedRemoveTrailingCommasFromGroupRowAsRossTechLikesItThatWay=" -e 's|,*\$||'"
    sedRemoveTrailingCommasFromGroupRowAsRossTechLikesItThatWay=" -e '/Group.*/{ s|,*\$|| }'"
    sedStatements+="$sedRemoveTrailingCommasFromGroupRowAsRossTechLikesItThatWay"

    outputFileName="$outputDir/$newFileName"
    reArrangeCsvFile "$x" "$outputFileName"

    if $DO_CHECK ; then
        firstChecksum="`md5sum "$x" | awk '{print $1}'`"
        secondChecksum="`md5sum "$outputFileName" | awk '{print $1}'`"

        if [ "$firstChecksum" == "$secondChecksum" ] ; then
            echo "[info]: is same "$x" ->  "$outputDir/$newFileName""
        else
            echo "[info]: changed "$x" ->  "$outputDir/$newFileName""
        fi
    else
        echo ""$x" -> "$outputDir/$newFileName""
    fi
done
touch "$MARK_REORDERED_FILE"
