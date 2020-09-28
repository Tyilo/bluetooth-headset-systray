#!/usr/bin/env python3
import os
from threading import Thread

import gi

from pulse import get_bluetooth_profile, set_bluetooth_profile

gi.require_version("Gtk", "3.0")
gi.require_version("Notify", "0.7")
from gi.repository import Gtk, Notify


class TrayIcon:
    def __init__(self, appid, icon, menu):
        self.menu = menu

        try:
            gi.require_version("AppIndicator3", "0.1")
            from gi.repository import AppIndicator3
        except (ImportError, ValueError) as e:
            print("Using systray backend")
            self.ind = Gtk.StatusIcon()
            self.ind.connect("popup-menu", self.on_popup_menu)
        else:
            print("Using appindicator3 backend")
            self.ind = AppIndicator3.Indicator.new(
                appid, icon, AppIndicator3.IndicatorCategory.APPLICATION_STATUS
            )
            self.ind.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
            self.ind.set_menu(self.menu)

        self.set_icon(icon)

    def on_popup_menu(self, icon, button, time):
        self.menu.popup(None, None, Gtk.StatusIcon.position_menu, icon, button, time)

    def set_icon(self, icon):
        if isinstance(self.ind, Gtk.StatusIcon):
            self.ind.set_from_icon_name(icon)
        else:
            self.ind.set_icon_full(icon, icon)


BLUETOOTH_PROFILES = {
    "a2dp_sink": "High Fidelity Playback",
    "headset_head_unit": "Headset Head Unit",
}


class App:
    APPID = "Bluetooth headset systray"

    def __init__(self):
        self.menu = Gtk.Menu()

        self.status_item = Gtk.MenuItem(label="Status:")
        self.status_item.set_sensitive(False)

        self.profile_items = {}
        self.profile_items_reverse = {}
        self.profile_items_handler_ids = {}
        self.no_profile_item = Gtk.RadioMenuItem()
        for k, v in BLUETOOTH_PROFILES.items():
            item = Gtk.RadioMenuItem(group=self.no_profile_item, label=v)
            self.profile_items[k] = item
            self.profile_items_reverse[item] = k
            self.profile_items_handler_ids[item] = item.connect(
                "activate", self.change_mode
            )

        self.exit_item = Gtk.MenuItem(label="Exit")
        self.exit_item.connect("activate", self.quit)

        self.menu.append(self.status_item)
        self.menu.append(Gtk.SeparatorMenuItem())
        for item in self.profile_items.values():
            self.menu.append(item)
        self.menu.append(Gtk.SeparatorMenuItem())
        self.menu.append(self.exit_item)

        self.menu.show_all()

        self.icon = TrayIcon(self.APPID, "audio-speakers", self.menu)

        self.update_status()

    def run(self):
        Notify.init(self.APPID)
        Gtk.main()

    def quit(self, _):
        Notify.uninit()
        Gtk.main_quit()

    def update_status(self):
        profile_name = get_bluetooth_profile()
        if profile_name:
            status = f"Connected ({profile_name})"
            if profile_name == "a2dp_sink":
                icon_name = "audio-headphones"
            else:
                icon_name = "audio-headset"
        else:
            status = "No profile"
            icon_name = "audi-speakers"

        self.status_item.set_label(f"Status: {status}")
        menu_item = self.profile_items.get(profile_name, self.no_profile_item)
        self._set_active(menu_item, True)

        self.icon.set_icon(icon_name)

    def _set_active(self, menu_item, state):
        handler_id = self.profile_items_handler_ids.get(menu_item)
        if handler_id:
            menu_item.handler_block(handler_id)

        menu_item.set_active(True)

        if handler_id:
            menu_item.handler_unblock(handler_id)

    def change_mode(self, menu_item):
        if menu_item.get_active() == False:
            return

        self.menu.set_sensitive(False)
        self.icon.set_icon("image-loading")

        profile_name = self.profile_items_reverse[menu_item]

        t = Thread(target=self._change_mode, args=[profile_name])
        t.start()

    def _change_mode(self, profile_name):
        success = set_bluetooth_profile(profile_name)
        self.update_status()
        self.menu.set_sensitive(True)

        if success:
            self.notify(f"Successfully changed profile to {profile_name}.")
        else:
            self.notify(f"Failed to change profile to {profile_name}!")

    def notify(self, message):
        Notify.Notification.new("Bluetooth audio profile", message).show()


if __name__ == "__main__":
    app = App()
    app.run()
