#!/usr/bin/env python3
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

import yaml


def get_interface_names(netplan_file):
    """Parses the netplan file to extract interface names.

    Args:
        netplan_file (str): Path to the netplan configuration file.

    Returns:
        list: A list of interface names found in the file.
    """

    with open(netplan_file, "r") as f:
        netplan_data = yaml.safe_load(f)

    interfaces = []
    for interface_name, interface_config in netplan_data["network"][
        "ethernets"
    ].items():
        route_metric = interface_config.get("dhcp4-overrides", {}).get(
            "route-metric", float("inf")
        )
        interfaces.append((interface_name, route_metric))

    # Sort interfaces based on route-metric (ascending) to detect primary interface
    interfaces.sort(key=lambda item: item[1])

    return [interface[0] for interface in interfaces]  # Return just the interface names


def update_netplan_config(netplan_file, primary_interface, renderer="NetworkManager"):
    """Updates the Netplan config file with the specified renderer.

    Args:
        netplan_file (str): Path to the Netplan configuration file.
        primary_interface (str): The primary network interface to update.
        renderer (str, optional): The renderer to use. Defaults to 'NetworkManager'.
    """
    with open(netplan_file, "r") as f:
        netplan_data = yaml.safe_load(f)

    netplan_data.setdefault("network", {})
    netplan_data["network"]["renderer"] = renderer

    ethernets = netplan_data["network"].get("ethernets", {})
    if primary_interface in ethernets:
        ethernets[primary_interface]["renderer"] = renderer

    with open(netplan_file, "w") as f:
        yaml.safe_dump(netplan_data, f)


def update_virl2_config(virl2_config_file, primary_interface, cluster_interface=None):
    """Updates the VIRL2 base config file with interface names.

    Args:
        virl2_config_file (str): Path to the VIRL2 base config file.
        primary_interface (str): Name of the primary interface.
        cluster_interface (str, optional): Name of the cluster interface (if any).
    """

    with open(virl2_config_file, "r") as f:
        virl2_data = yaml.safe_load(f)

    virl2_data["primary_interface"] = primary_interface
    if cluster_interface:
        virl2_data["cluster_interface"] = cluster_interface

    with open(virl2_config_file, "w") as f:
        yaml.safe_dump(virl2_data, f)


def main():
    # Configuration paths
    netplan_file = "/etc/netplan/50-cloud-init.yaml"
    virl2_config_file = "/etc/virl2-base-config.yml"

    # Get interface names
    interface_names = get_interface_names(netplan_file)
    primary_interface = interface_names[0]
    cluster_interface = interface_names[1] if len(interface_names) > 1 else None

    # Update Netplan config
    update_netplan_config(netplan_file, primary_interface)

    # Update VIRL2 config
    update_virl2_config(virl2_config_file, primary_interface, cluster_interface)


if __name__ == "__main__":
    main()
