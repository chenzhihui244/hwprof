#!/bin/bash

echo $$ > /tmp/getpid.pid
echo "PID: $$"

exec $@
