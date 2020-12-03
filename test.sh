#!/bin/bash

# while :; do echo "###reviving sudo###";sudo -v; sleep 256; done &
# revivesudo=$!
while :
 do
  sudo ps -p $$ -o etime
  echo sleeping for 5:01 mins...
  sleep 301
 done &

# kill "$revivesudo"