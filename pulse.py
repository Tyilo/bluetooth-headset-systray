#!/usr/bin/env python
import subprocess
import sys
from time import sleep

import pulsectl


PULSE = pulsectl.Pulse("toggle_bt_mode")


def get_bluetooth_sink():
    for sink in PULSE.sink_list():
        if sink.proplist.get("device.bus") == "bluetooth":
            return sink


def get_bluetooth_source():
    for source in PULSE.source_list():
        if (
            source.proplist.get("device.bus") == "bluetooth"
            and source.proplist.get("device.class") == "sound"
        ):
            return source


def restart_bluetooth():
    subprocess.run(["sudo", "systemctl", "restart", "bluetooth"])
    while True:
        sink = get_bluetooth_sink()
        if sink:
            return sink

        sleep(5)


def get_bluetooth_profile():
    sink = get_bluetooth_sink()
    if not sink:
        return None

    return sink.proplist["bluetooth.protocol"]


def set_bluetooth_profile(new_profile):
    sink = get_bluetooth_sink()
    if not sink:
        print("Bluetooth sink not found, restarting bluetooth service:")
        sink = restart_bluetooth()

    original_profile = sink.proplist["bluetooth.protocol"]

    if original_profile == new_profile:
        print(f"Profile is already {new_profile}")
    else:
        print(f"Swithcing from {original_profile} to {new_profile}")

        for i in range(2):
            try:
                print("Trying to change")
                PULSE.card_profile_set_by_index(sink.card, new_profile)
                print("Changed")
                break
            except pulsectl.PulseOperationFailed:
                if i == 1:
                    print("Couldn't change profile")
                    return False

                print("Failed to change profile, restarting bluetooth service:")
                restart_bluetooth()
                sleep(5)
                sink = get_bluetooth_sink()
                if sink.proplist["bluetooth.protocol"] == new_profile:
                    print("Already changed!!")
                    break

        print("Changed profile to", new_profile)

        sink = get_bluetooth_sink()
        if not sink:
            print("Bluetooth sink not found after switching protocol")
            return False

    PULSE.sink_default_set(sink)
    for sink_input in PULSE.sink_input_list():
        PULSE.sink_input_move(sink_input.index, sink.index)

    source = get_bluetooth_source()
    if source:
        PULSE.source_default_set(source)
        for source_output in PULSE.source_output_list():
            if (
                source_output.proplist.get("application.id")
                != "org.PulseAudio.pavucontrol"
            ):
                PULSE.source_output_move(source_output.index, source.index)

    return True
