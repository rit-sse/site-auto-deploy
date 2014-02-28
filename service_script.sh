#!/bin/sh

case "$1" in
    start)
        echo "Starting deploy daemon...";
        bundle install >> /dev/null;
        mkdir ./log >> /dev/null;
        touch ./log/deploy_log;
        echo "======================Start======================" >> ./log/deploy_log
        bundle exec ruby main.rb -p 8080 -o 0.0.0.0 >> ./log/deploy_log 2>&1 &
        ;;
    stop)
        echo "Stopping...";
        echo "=======================End========================" >> ./log/deploy_log
        kill -2 `cat ./pids/sinatra`
        ;;
      *)
        ## If no parameters are given, print which are avaiable.
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
