#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")"
while true; do
	./bluetooth-headset-systray &> log.txt
	code=$?
	if [[ "$code" == "0" ]]; then
		break
	fi
	echo "$(date) bluetooth-headset-systray exited with code $code"
	sleep 1
done
