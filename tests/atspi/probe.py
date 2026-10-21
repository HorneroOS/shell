#!/usr/bin/env python3
"""Walk the AT-SPI tree over raw D-Bus and print named accessibles."""
import dbus

session = dbus.SessionBus()
a11y_addr = session.call_blocking(
    "org.a11y.Bus", "/org/a11y/bus", "org.a11y.Bus", "GetAddress", "", ())
bus = dbus.bus.BusConnection(a11y_addr)

ACC = "org.a11y.atspi.Accessible"
PROPS = "org.freedesktop.DBus.Properties"

found = []


def walk(bus_name, path, depth=0):
    if depth > 30:
        return
    try:
        obj = bus.get_object(bus_name, path)
        name = str(dbus.Interface(obj, PROPS).Get(ACC, "Name"))
        role = str(dbus.Interface(obj, ACC).GetRoleName())
    except Exception:
        name, role = "", "?"
    if name:
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
