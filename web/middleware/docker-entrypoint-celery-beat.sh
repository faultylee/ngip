#!/usr/bin/env bash
function trap_func {
    # post-clean up
    rm -f ./restart-celery-beat
    # send TERM to all running beat. The while loop is to avoid kill error when no pid is returned
    ps auxww | grep celery | grep -v "grep" | grep -v "bash" | grep beat | awk '{print $2}' |\
     (while read pid; do if [ $(echo "$pid" | wc -c) -gt 1 ]; then echo "killing $pid"; kill -TERM "$pid"; fi; done;)
    wait
}

trap trap_func EXIT SIGHUP SIGINT SIGTERM

celery_beat_cmd="celery -A middleware beat --loglevel=info -S django"

cd dashboard
pwd
# pre-clean up
rm -f ./restart-celery-beat
rm -f celerybeat.pid
# start celery-beat
$celery_beat_cmd &
# wait for ./restart-celery-beat, print it's content then restart beat
# this is to workaround beat not being able to pickup new or updated tasks in 4.0.2
inotifywait -m "./" -q -e create --format %f | while read -r file; do
    if [[ $file = "restart-celery-beat" ]]; then
        # print then clean up
        echo "restart-celery-beat: `cat ./restart-celery-beat`"
        rm -f ./restart-celery-beat
        # send TERM to beat and wait for all child to exit
        ps auxww | grep celery | grep -v "grep" | grep -v "bash" | grep beat | awk '{print $2}' | xargs kill -TERM
        wait
        # restart celery-beat
        $celery_beat_cmd &
        sleep 5
    fi
done
cd ..