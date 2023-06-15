#!/bin/bash

readmeFile="README.md"
function echol() {
    echo "$@" >> "$readmeFile"
}

cat <<EOF> $readmeFile
Some scripts that might help you with your vcds log files.
They are created with only linux in mind. They probably will
run with cygwin.
EOF
echol '## reorder-vcds-logs.sh'
echol '```'
echol "`cat reorder-vcds-logs.sh | awk '/######### about start ####/{flag=1; next} /######### about end ####/{flag=0} flag'`"
echol ""
echol " ### reorder-vcds-logs.sh"
echol "`bash reorder-vcds-logs.sh --help`"
echol '```'
echol ''
echol '## rename-vcds-logs.sh'
echol '```'
echol "`cat rename-vcds-logs.sh | awk '/######### about start ####/{flag=1; next} /######### about end ####/{flag=0} flag'`"
echol ""
echol '### rename-vcds-logs.sh'
echol "`bash rename-vcds-logs.sh --help`"
echol '```'
