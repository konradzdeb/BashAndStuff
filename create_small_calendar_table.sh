#!/usr/bin/env bash
#
# create_small_calendar_table.sh
# Copyright (C) 2021 Konrad <konrad.zdeb@me.com>
#
# Creates a calendar table via simple Hive query
#
# Distributed under terms of the MIT license.
#

# Settings
set -o errexit # Exit script if command files
set -o nounset # Exit if trying to use undeclared variables
# set -o xtrace  # Trace what is getting executed

# Fetech variables
START_DATE=${1:-$(date -I)} 												# Get start date or use current date
END_DATE=${2:-$(date -I -d "+10 days")}						# Add ten days
TABLE_NAME=${3:-calendar_table}

# Tempoary query file
tmpqry=$(mktemp /tmp/tmp-calendar-table.XXXXXX)

# List parameters
echo "Start date: ${START_DATE}"
echo "End date: ${END_DATE}"
echo "Query file: ${tmpqry}"

# loop vars
I_DATE="${START_DATE}"
declare -a RES_DATES=()

# Provide date value
until [[ ${I_DATE} > ${END_DATE} ]]; do
	I_DATE=$(date -I -d "${I_DATE} + 1 day")    # Add one day from given I_DATE
	RES_DATES+=(${I_DATE})											 # Collect results in array
done

# Populate query file
NOW=$(date)
echo "-- Automatically generated script file on ${NOW}" >> ${tmpqry}
echo "CREATE TEMPORARY TABLE tmp_calendar (str_date STRING);" >> ${tmpqry}

# Append insert statement for each date
for i in "${RES_DATES[@]}"; do
	echo "INSERT INTO tmp_calendar VALUES ('"${i}"');" >> ${tmpqry}
done

# Clean table if exists
echo "DROP TABLE IF EXISTS ${TABLE_NAME};" >> ${tmpqry}

# Create nicely formatted calendar table
# TODO: weekday name
echo "CREATE TABLE ${TABLE_NAME} AS"  >> ${tmpqry}
echo -e "\t WITH tmp_dates AS (SELECT TO_DATE(str_date) AS cal_dte FROM tmp_calendar)" >> ${tmpqry}
echo -e "\t \t SELECT cal_dte AS calendar_date," >> ${tmpqry}
echo -e "\t \t YEAR(cal_dte) AS calendar_year,"  >> ${tmpqry}
echo -e "\t \t MONTH(cal_dte) AS calendar_month," >> ${tmpqry}
echo -e "\t \t DAY(cal_dte) AS calendar_day," >> ${tmpqry}
echo -e "\t \t WEEKOFYEAR(cal_dte) AS week_year," >> ${tmpqry}
echo -e "\t \t QUARTER(cal_dte) AS quarter_year" >> ${tmpqry}
echo -e "\t \t FROM tmp_dates"	>> ${tmpqry}
echo -e "\t \t ORDER BY calendar_date DESC;" >> ${tmpqry}
echo "SELECT * FROM calendar_table LIMIT 5;" >> ${tmpqry}

echo "Executing:"
cat ${tmpqry}

# Execute
/opt/hive/bin/beeline --color=true -u jdbc:hive2://localhost:10000 --verbose -f ${tmpqry}
