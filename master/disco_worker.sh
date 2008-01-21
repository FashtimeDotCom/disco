#!/bin/bash

# INPUT: [Mode, JobName, Node, PartID, Input]

# When Erlang closes the port connected to this script,
# only EOF is sent to stdin. Since disco_worker.py is unlikely to notice
# this and close appriopriately, we need a separate mechanism for
# detecting the shutdown and killing the worker process.
#
# We split the input stream into two parts using tee. One stream is directed
# to the worker process via ssh and the other to a second instance of this 
# script, started with the KILLER_MODE flag on. This second instance will
# wait until EOF is received from stdin and then proceed to kill
# the worker. Since the worker process(es) are recognized based on the job 
# name, any child processes spawned by the worker must include the name in
# their command line, or otherwise they will be missed by pkill.

if [ $KILLER_MODE ]
then
        cat >/dev/null
        # give some time for the process to exit by itself
        sleep 5
        ssh $3 "pkill -9 -f 'disco_worker.py $1 $2 $3 $4'" 2>&1 >/dev/null
        kill -9 $DOG_PID
        exit 0
fi

if [ $WATCHDOG_MODE ]
then
        # give some time for the process to start up
        sleep 40
        while ((1)) 
        do
                R=`ssh $3 "pgrep -l -f 'disco_worker.py $1 $2 $3 $4' | grep -v ' ssh '"`
                if (( $? )) || [[ -z $R ]]
                then
                        echo "**<DAT> Watchdog lost $1:$4."
                        exit 0
                fi
                sleep 5
        done
fi

WATCHDOG_MODE=1 $0 "$1" "$2" "$3" "$4" &
DOG=$!

tee >(DOG_PID=$DOG KILLER_MODE=1 $0 "$1" "$2" "$3" "$4") |\
                ssh $3 "python disco_worker.py '$1' '$2' '$3' '$4' $5"



