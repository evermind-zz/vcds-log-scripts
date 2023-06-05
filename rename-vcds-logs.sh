#!/bin/bash

######################## about start #########
# rename a VCDS CSV log file:
# - all CSV files within the execution dir of this script will be
#   prefixed with 20230603_1151_ aka '%Y%m%d_%H%M'
######################## about end #########

IFS="
"

re='([0-9_]{0,13})'
re2='(.*)(LOG.*)'
for x in *.CSV ; do
    datePart="`stat -c %y $x`"
    datePart=${datePart//[-:]/}
    datePart=${datePart// /_}
    [[ $datePart =~ $re ]]
    datePart=${BASH_REMATCH[1]}

    #echo $datePart
    [[ $x =~ $re2 ]]
    mv $x ${datePart}_${BASH_REMATCH[2]}
done
