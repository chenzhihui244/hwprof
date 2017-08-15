#!/bin/bash

opt_duration=0; duration=;

tracing=/sys/kernel/debug/tracing
flock=/var/tmp/.ftrace-lock; wroteflock=0
entry_point=raw_syscalls:sys_enter
exit_point=raw_syscalls:sys_exit
entry_dir=events/${entry_point/:/\/}
exit_dir=events/${exit_point/:/\/}

trap ':' INT QUIT TERM PIPE HUP

function warn {
	if ! eval "$@"; then
		echo >&2 "WARING: command failed \"$@\""
	fi
}

function end {
	echo 2>/dev/null
	echo "Ending tracing..." 2>/dev/null
	cd $tracing
	warn "echo 0 > ${entry_dir}/enable"
	warn "echo 0 > ${exit_dir}/enable"
	warn "echo > trace"
	(( $wroteflock )) && warn "rm $flock"
}

function die {
	echo >&2 "$@"
	exit 1
}

function edie {
	echo >&2 "$@"
	exec >/dev/null 2>&1
	end
	exit 1
}

while getopts d: opt
do
	case $opt in
	d)	opt_duration=1; duration=$OPTARG ;;
	esac
done

[[ -e $flock ]] && die "ERROR: ftrace may be in use by PID $(cat $flock) $flock"
echo $$ > $flock || die "ERROR: unable to write $flock"
wroteflock=1

cd $tracing

echo nop > current_tracer
if ! echo 1 >> $entry_dir/enable; then
	edie "ERROR: enabling tracepoint $entry_point. Exiting"
fi
if ! echo 1 >> $exit_dir/enable; then
	edie "ERROR: enabling tracepoint $exit_point. Exiting."
fi

if (( opt_duration )); then
	echo "Tracing $entry_point and $exit_point $duration seconds (bufferd)..."
else
	echo "Tracing $entry_point and $exit_point. Ctrl-C to end"
fi

warn "echo > trace"
if (( opt_duration )); then
	sleep $duration
	cat trace
else
	cat trace
	cat trace_pipe
fi

end
