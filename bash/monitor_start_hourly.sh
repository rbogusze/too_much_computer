#!/bin/bash

# This script should be run every 1 min, it send monitoring messages when some activity starts happening on the activity_.* topics, which means someone started the PC, done to catch Natalia playing without consent

MESSAGES_FILE=/tmp/monitor_start_hourly.txt
echo "MESSAGES_FILE: $MESSAGES_FILE"

echo "-----------------------------"
date

# read secrets from file
source ~/.monitor_secrets.txt

if [ -z "${SLACK_WEBHOOK}" ]; then
  echo "SLACK_WEBHOOK variable that should be taken from ~/.monitor_secrets.txt is not defined. Exiting."
  exit 1
fi

echo "MESSAGES_FILE: $MESSAGES_FILE"

#TIMEOUT=15000
#echo "listen for 55s and read any new messages, hm, not sure why timeout-ms $TIMEOUT feels like 1min"
#/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server 192.168.1.104:9092 --whitelist 'activity_.*' --timeout-ms $TIMEOUT > ${MESSAGES_FILE} 2>&1

SLEEP_SEC=550
echo "Running consume from kafka topics, output to ${MESSAGES_FILE} and sleeping for $SLEEP_SEC"
/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server 192.168.1.104:9092 --whitelist 'activity_.*' > ${MESSAGES_FILE} 2>&1 &
CONSUMER_PID=$!
echo "CONSUMER_PID: $CONSUMER_PID"
ps -ef | grep $CONSUMER_PID

sleep 1

echo "Sleeping for $SLEEP_SEC"
sleep $SLEEP_SEC

echo "Killing the kafka-console-consumer.sh command"
kill $CONSUMER_PID
sleep 1
kill -9 $CONSUMER_PID

sleep 1
ps -ef | grep $CONSUMER_PID

echo "THis is what I received:"
cat ${MESSAGES_FILE}

date

echo "Some basic filtering"
MESSAGES_FILE_F1=/tmp/monitor_start_hourly_f1.txt
cat ${MESSAGES_FILE} | grep --text send_time | grep --text -v "Hello there from" > ${MESSAGES_FILE_F1}

echo "Reading each line:"
while read LINE
do
  V_TEXT=`echo $LINE | jq -r '.text'`
  #echo "V_TEXT: $V_TEXT"
  V_WHO=`echo $V_TEXT | awk '{print $3}'`
  echo "V_WHO: $V_WHO"
  echo "Was that reported in last hour?"
  REPORTED_TIMESTAMP="${V_WHO}_`date '+%Y-%m-%d--%H'`"
  echo "REPORTED_TIMESTAMP: ${REPORTED_TIMESTAMP}"
  if [ -f "/tmp/${REPORTED_TIMESTAMP}" ]; then
    echo "File exists. Doing nothing, that was already reported"
  else
    echo "File does not exists. Reporting this activity and creating a file"
    curl -X POST --data-urlencode "payload={\"channel\": \"#monitoring\", \"username\": \"computer_monitor\", \"text\": \"Computer $V_WHO is working on ${REPORTED_TIMESTAMP}.\", \"icon_emoji\": \":ghost:\"}" ${SLACK_WEBHOOK}
    touch /tmp/${REPORTED_TIMESTAMP}
  fi

done < ${MESSAGES_FILE_F1}


