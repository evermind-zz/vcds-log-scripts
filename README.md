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
```

## rename-vcds-logs.sh
```
# rename a VCDS CSV log file:
# - all CSV files within the execution dir of this script will be
#   prefixed with 20230603_1151_ aka '%Y%m%d_%H%M'
```
