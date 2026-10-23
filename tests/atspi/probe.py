#!/usr/bin/env python3
"""Walk the AT-SPI tree over raw D-Bus and print named accessibles."""
import argparse

import dbus

parser = argparse.ArgumentParser()
parser.add_argument("--pid", type=int, help="only print accessibles owned by this process")
options = parser.parse_args()

session = dbus.SessionBus()
a11y_addr = session.call_blocking(
    "org.a11y.Bus", "/org/a11y/bus", "org.a11y.Bus", "GetAddress", "", ())
bus = dbus.bus.BusConnection(a11y_addr)

ACC = "org.a11y.atspi.Accessible"
PROPS = "org.freedesktop.DBus.Properties"

found = []
pid_cache = {}


def owned_by_process(bus_name):
    if options.pid is None:
        return True
    if bus_name not in pid_cache:
        try:
            daemon = bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
            pid_cache[bus_name] = int(
                dbus.Interface(daemon, "org.freedesktop.DBus")
                .GetConnectionUnixProcessID(bus_name)
            )
        except Exception:
            pid_cache[bus_name] = -1
    return pid_cache[bus_name] == options.pid


def walk(bus_name, path, depth=0):
    if depth > 30:
        return
    try:
        obj = bus.get_object(bus_name, path)
        name = str(dbus.Interface(obj, PROPS).Get(ACC, "Name"))
        role = str(dbus.Interface(obj, ACC).GetRoleName())
    except Exception:
        name, role = "", "?"
    if name and owned_by_process(bus_name):
        found.append((role, name, bus_name))
    try:
        children = dbus.Interface(obj, ACC).GetChildren()
    except Exception:
        return
    for child in children:
        walk(str(child[0]), str(child[1]), depth + 1)


# Root lives on the registry connection itself.
walk("org.a11y.atspi.Registry", "/org/a11y/atspi/accessible/root")
for rl, nm, bn in found:
    print(f"{rl}: {nm}  [{bn}]")
print(f"TOTAL_NAMED={len(found)}")
