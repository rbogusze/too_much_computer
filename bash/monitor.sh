#!/bin/bash

MESSAGES_FILE=/tmp/kafka_messages.txt
MAX_COMP_TIME_MIN=120

# get messages
#/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server :9092 --topic activity_desktop-adas --from-beginning --timeout-ms 2000 > ${MESSAGES_FILE} 2>&1

# filter messages to know how long was computer on today
DATE_I=`date -I`
COMP_TIME=`cat ${MESSAGES_FILE} | grep ${DATE_I} | grep -v "ERROR" | awk '{print $2}' | sed -e 's/\(.*\):../\1:00/' | sort -u | wc -l`
echo "COMP_TIME: $COMP_TIME"

if [ ${COMP_TIME} -gt ${MAX_COMP_TIME_MIN} ]; then
  echo "Notty boy!"
  # compute extra time (above the allowed MAX_COMP_TIME_MIN) in minutes
  EXTRA_TIME=`expr ${COMP_TIME} - ${MAX_COMP_TIME_MIN}`
  echo "EXTRA_TIME: $EXTRA_TIME"

  # now is the fun part, be noisy depending on how much he pushed the limit
  
  # between 1min and 30min
  if [ ${EXTRA_TIME} > 10 ]; then
    echo "Warning level 1"
  fi

  # between 30min and 60min

  
  # above 60min

else
  echo "Good boy!"
fi
