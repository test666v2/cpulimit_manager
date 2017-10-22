#!/bin/bash
export LANG=C
# ==============================================================
# cpulimit_manager.sh
# ==============================================================

# requires sysstat installation because mpstat is needed to get average %CPU use

# variables
max_known_hogs=70     # max %CPU consumption by known hogs
max_other_hogs=80     # max percentage consumption by a process that is not in the known hogs list
cpu_alarm=90           # if %CPU usage is above this threshold, use cpulimit
known_hogs="ssh | ntop | firefox-esr | firefox | qupzilla | midori | epiphany | WebKitWebProcess" # known hogs (this is my usual hogs list, ymmv)
no_limit=""                   # do not limit these processes: it can be empty as ""; use "process" for one process; use "process_1 | process_2 | process_3" for many processes
how_many_processes=20         # number of top cpu processes to check in case of %CPU usage exceeding threshold
cpu_check_interval=2
cpu_check_rounds=10           # 2 x 10 = 20 seconds wait time
grep_ignore="CPU | PID | COMMAND"   # ignore lines with these word produced by command "ps aux"; please DO NOT REMOVE or ALTER
wait_before_activation=3m           # waiting time before restricting high cpu usage (3m - 3 minutes; 33 - 33 seconds; 1h - 1 hour); leave empty, make it equal zero or delete line for no waiting time)

# main
sleep $wait_before_activation 2>/dev/null  # suppress sleep error message if variable $wait_before_activation is empty
IFS=$'\n'
[ ! -z $known_hogs ] || known_hogs=$(</dev/urandom tr -dc 'A-Za-z0-9' | head -c 16  ; echo) #   the variables   $known_hogs
[ ! -z $no_limit ] || no_limit=$(</dev/urandom tr -dc 'A-Za-z0-9' | head -c 16  ; echo) #                       $no_limit     cannot be empty, auto-populate with random characters if needed
while true
   do
      cpu_current=$(mpstat $cpu_check_interval $cpu_check_rounds | grep -a Average | awk '{print $3}' | awk '{print int($1+0.5)}')  # get average CPU use as an integer
      if (( cpu_current >= cpu_alarm ))
         then
            detected_hogs=$(ps aux --sort=-pcpu | head -n $how_many_processes | grep -E -a -v "$grep_ignore" | grep -E "$known_hogs" | grep -E -v "$no_limit" | grep -v "cpulimit -m -q -p" | grep -v grep)
            for process in $detected_hogs
               do
                  process_cpu=$(echo "$process" | awk '{print $3}' | awk '{print int($1+0.5)}')
                  ! (( process_cpu > max_known_hogs )) || /usr/bin/cpulimit -m -q -p $(echo "$process" | awk '{print $2}') -l $max_known_hogs -z &
               done
            other_hogs=$(ps aux --sort=-pcpu | head -n $how_many_processes | grep -E -a -v "$grep_ignore" | grep -E -v "$known_hogs" | grep -E -v "$no_limit" | grep -v "cpulimit -m -q -p" | grep -v grep)
            for process in $other_hogs
               do
                  process_cpu=$(echo "$process" | awk '{print $3}' | awk '{print int($1+0.5)}')
                  ! (( process_cpu > max_other_hogs )) || /usr/bin/cpulimit -m -q -p $(echo "$process" | awk '{print $2}') -l $max_other_hogs -z &
               done
         else
            [[ -z $(ps aux | grep "cpulimit -m -q -p" | grep -v grep) ]] || killall -w cpulimit  # if cpulimit is active and there is not an high %CPU use, kill it; so far, I've never ever had an issue with this
      fi
   done

