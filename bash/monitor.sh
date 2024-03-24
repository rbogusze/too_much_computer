#!/bin/bash

# This script should be run every 10min, it send monitoring messages when Adas is sitting behind computer for more than agreed time

MESSAGES_FILE=/tmp/kafka_messages.txt
MAX_COMP_TIME_MIN=120

echo "-----------------------------"
date

# read secrets from file
source ~/.monitor_secrets.txt
DATE_I=`date -I`

if [ -z "${SLACK_WEBHOOK}" ]; then
  echo "SLACK_WEBHOOK variable that should be taken from ~/.monitor_secrets.txt is not defined. Exiting."
fi

# get messages
#/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server :9092 --topic activity_desktop-adas --from-beginning --timeout-ms 2000 > ${MESSAGES_FILE} 2>&1

# get messages from two topics
/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server :9092 --whitelist 'activity_desktop-adas|activity_laptop_adasia|activity_laptop-adasia' --from-beginning --timeout-ms 4000  > ${MESSAGES_FILE} 2>&1


# check if there were new messages in the last 2 min, if yes that means Adas is still sitting behind the computer and ignores my ask to do something else
LAST_READING=`cat ${MESSAGES_FILE} | grep ${DATE_I} | grep -v "ERROR" | sort -k2 | tail -1 | awk '{print $2}' | tr -d "," | tr -d '"'`
echo "LAST_READING: ${LAST_READING}"

# if there are no messages from today let's set last message as from yesterday
if [ -z "${LAST_READING}" ]; then
  echo "Last reading is older than today, setting it like yesterday"
  LAST_READING=`date -d "yesterday 13:00" '+%Y-%m-%d'`
else
  echo "looks like he played today already"
fi

LAST_READING_EPOCH=`date -d ${LAST_READING} +"%s"`
echo "LAST_READING_EPOCH: ${LAST_READING_EPOCH}"
NOW_EPOCH=`date +"%s"`
echo "NOW_EPOCH: ${NOW_EPOCH}"
LAST_READING_SEC=`expr ${NOW_EPOCH} - ${LAST_READING_EPOCH}`
echo "LAST_READING_SEC: ${LAST_READING_SEC}"

# if last reading is older than 1min ago (trick is this script is supposed to run every 10min) then let's assume the computer is off
# if comparing to 60 then I can miss some activity, but there is no false positive
# if comparing to 600 then I do not miss on any activity, but there is a 10min window of false positive
# deciding now to 300 as with 60 I missed some of his short activities
if [ ${LAST_READING_SEC} -gt 300 ]; then
  echo "No need to shout now, he is not there any more. Exiting."
  exit 0
else
  echo "Nice, Adas is still sitting behind his computer, let's check if this is legit."
fi

# filter messages to know how long was computer on today
COMP_TIME=`cat ${MESSAGES_FILE} | grep ${DATE_I} | grep -v "ERROR" | awk '{print $2}' | sed -e 's/\(.*\):../\1:00/' | sort -u | wc -l`
echo "COMP_TIME: $COMP_TIME"

if [ ${COMP_TIME} -gt ${MAX_COMP_TIME_MIN} ]; then
  echo "Notty boy!"
  # compute extra time (above the allowed MAX_COMP_TIME_MIN) in minutes
  EXTRA_TIME=`expr ${COMP_TIME} - ${MAX_COMP_TIME_MIN}`
  echo "EXTRA_TIME: $EXTRA_TIME"

  # now is the fun part, be noisy depending on how much he pushed the limit
  
  # between 1min and 30min
  if [ ${EXTRA_TIME} -gt 1 ]; then
    echo "Warning level 1"
    #echo "SLACK_WEBHOOK: $SLACK_WEBHOOK"
    curl -X POST --data-urlencode "payload={\"channel\": \"#monitoring\", \"username\": \"too_much_computer_monitor\", \"text\": \"Adas is already playing for ${COMP_TIME} min which is ${EXTRA_TIME} min above the limit.\", \"icon_emoji\": \":ghost:\"}" ${SLACK_WEBHOOK}
  fi

  # between 30min and 60min

  
  # above 60min

else
  echo "Good boy!"
fi
