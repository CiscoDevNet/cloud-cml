#!/usr/bin/env python3
import subprocess
import os
import yaml

WORKING_DIR = "/provision"


def create_bridges_and_connections():
    # Get "Wired connection" interfaces
    wired_connections = get_wired_connections()
    index = 101
    # Create bridges and associate interfaces
    for connection in wired_connections:
        bridge_name = f"bridge{index}"
        index += 1
        interface_name = get_interface_from_connection(connection)
        # Create bridge
        subprocess.run(
            [
                "nmcli",
                "connection",
                "add",
                "type",
                "bridge",
                "con-name",
                bridge_name,
                "ifname",
                bridge_name,
            ]
        )

        # Bridge config
        subprocess.run(
            ["nmcli", "connection", "modify", bridge_name, "ipv4.method", "disabled"]
        )
        subprocess.run(
            ["nmcli", "connection", "modify", bridge_name, "ipv6.method", "ignore"]
        )
        subprocess.run(
            ["nmcli", "connection", "modify", bridge_name, "bridge.stp", "no"]
        )
        # Add interface to bridge
        subprocess.run(
            [
                "nmcli",
                "connection",
                "add",
                "type",
                "ethernet",
                "slave-type",
                "bridge",
                "con-name",
                f"{bridge_name}-p1",
                "ifname",
                interface_name,
                "master",
                bridge_name,
            ]
        )

        # Delete the original connection
        subprocess.run(["nmcli", "connection", "delete", connection])

        # Disable IPv6 for bridge interface in the sysctl
        line = f"net.ipv6.conf.{bridge_name}.disable_ipv6 = 1\n"

        with open("/etc/sysctl.conf", "a") as f:
            f.write(line)

    # Apply sysctl changes for IPv6
    subprocess.run(["sysctl", "-p", "-q"])


def get_wired_connections():
    output = subprocess.check_output(["nmcli", "connection", "show"]).decode()
    connections = []
    devices = set()  # Track seen devices

    # Get primary and cluster interface from the CML config
    with open("/etc/virl2-base-config.yml", "r") as f:
        config = yaml.safe_load(f)

    for interface_type in ["cluster_interface", "primary_interface"]:
        ens_interface = config.get(interface_type)
        if ens_interface:
            devices.add(ens_interface)

    for line in output.splitlines():
        fields = line.split()
        # Exclude already configured interfaces
        if fields:
            device = fields[-1] if fields[-1] != "--" else ""
            devices.add(device)

        # Select 'Wired connection' or 'netplan-' interfaces
        if (
            fields
            and (fields[0] == "Wired" and fields[1] == "connection")
            or ("netplan-" in fields[0])
        ):
            name_end_index = 3 if fields[0:2] == ["Wired", "connection"] else 1
            name = " ".join(fields[0:name_end_index])

            # Check for device part after "netplan-" (remains the same)
            if "netplan-" in name:
                device_part = name.split("-")[-1]
                if device_part in devices:
                    continue  # Skip if already in devices

            connections.append(
                {
                    "name": name,
                    "device": device,  # Overwrite if necessary
                }
            )

    # Sort interface output
    def sort_key(item):
        name = item["name"]
        if "netplan-" in name:
            parts = name.split("-")
            if len(parts) > 1 and parts[1].startswith("ens"):  # Check for 'ens'
                return int(parts[1][3:])  # Extract number after 'ens'
            else:
                return 0  # Prioritize to the beginning if no 'ens' part
        else:
            return int(name[3:]) if name else 0

    connections.sort(key=sort_key)
    return [conn["name"] for conn in connections]  # Return just the connection names


def get_interface_from_connection(connection_name):
    output = subprocess.check_output(
        ["nmcli", "connection", "show", connection_name]
    ).decode()
    for line in output.splitlines():
        if "connection.interface-name" in line:
            return line.split(":")[-1].strip()  # Extract interface name


def create_mac_deletion_script():
    script_content = """#!/usr/bin/env python3

import subprocess
import re

def find_macs_and_delete(bridge_name):
    fdb_output = subprocess.check_output(["bridge", "fdb", "show"]).decode()
    for line in fdb_output.splitlines():
        if bridge_name in line and "vlan 1" in line:
            fields = line.split()
            mac_address = fields[0]
            device = fields[2]
            subprocess.run(["bridge", "fdb", "del", mac_address, "dev", device, "master"])

if __name__ == "__main__":

    # Get bridge names from nmcli con show
    output = subprocess.check_output(["nmcli", "con", "show"]).decode()
    bridges = []
    for line in output.splitlines():
        if "bridge" in line:
            bridges.append(line.split()[0])

    # Filter bridges with 'bridge1xx' pattern
    filtered_bridges = [bridge for bridge in bridges if re.match(r"bridge1\d\d", bridge)]

    for bridge in filtered_bridges:
        find_macs_and_delete(bridge)

    """

    script_path = os.path.join(WORKING_DIR, "delete_bridge_macs.py")

    with open(script_path, "w") as f:
        f.write(script_content)

    # Make the script executable
    os.chmod(script_path, 0o755)


def install_cron_job():
    script_path = os.path.join(WORKING_DIR, "delete_bridge_macs.py")
    cron_line = f"PATH=/sbin:/bin:/usr/sbin:/usr/bin\n* * * * * {script_path}\n"

    # Modify crontab (might need 'sudo' within the script)
    subprocess.run(
        ["crontab", "-l"], stdout=subprocess.PIPE
    )  # Capture existing crontab
    subprocess.run(["crontab", "-"], input=cron_line.encode(), check=True)


if __name__ == "__main__":
    create_bridges_and_connections()
    # Restart NetworkManager (you might need 'sudo' permissions)
    subprocess.run(["systemctl", "restart", "NetworkManager"])

    # Create the MAC deletion script
    create_mac_deletion_script()

    # Install cron job
    install_cron_job()
