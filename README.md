Some scripts that might help you with your vcds log files.
They are created with only linux in mind. They probably will
run with cygwin.
## reorder-vcds-logs.sh
```
# reorder a VCDS CSV log file so that the measurement
# blocks are in ascending order:
# - -> blocks: 008-004-001 will be reordered like this 001-004-008
# - all CSV files within the execution dir of this script will be
#   converted and stored into $outputDir.
# - The filenames will also be changed to reflect the CSV reordering

 ### reorder-vcds-logs.sh
Usage: reorder-vcds-logs.sh [OPTION]...

 --check   use md5sum to compare the input file with the output
 --ignore  ignore multiple timestamps in log file 
 --clean   remove the outputDir and unmark dir as processed 
 --help    show this help 
```

## rename-vcds-logs.sh
```
# rename a VCDS CSV log file:
# - all CSV files within the execution dir of this script will be
#   prefixed with 20230603_1151_ aka '%Y%m%d_%H%M'

### rename-vcds-logs.sh
Usage: rename-vcds-logs.sh [OPTION]... [FILE(S)]...

 --date-from-log  read creation date from inside log file
 --touch          set file creation date to --date-from-log
 --single CSV     operate on single file --single YOUR.csv 
 --ignore         ignore multiple timestamps in log file, process the first only 
 --help           show this help 
```
