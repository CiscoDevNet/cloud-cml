# AWS Provider v6 ENI Migration

## Status

The AWS provider v6 deprecates the `network_interface` block on
`aws_instance`.

Cloud-CML uses this migration path:

- Use `primary_network_interface` for the device-index-0 ENI.
- Keep a cluster ENI at device index 1 as an inline `network_interface` block.

This removes the warning for AWS mini and non-cluster AWS deployments. A
cluster deployment still has one deprecation warning. Do not move the cluster
ENI to `aws_network_interface_attachment` until the work described below is
complete.

## Why the cluster ENI remains inline

CML identifies its primary and cluster interfaces during first boot.
`/provision/interface_fix.py` currently reads the cloud-init Netplan file and
uses:

```text
first data interface  -> primary_interface
second data interface -> cluster_interface
```

An inline ENI is part of the EC2 instance launch request. AWS attaches both
ENIs before the guest starts. The cluster ENI is therefore available when
cloud-init runs.

```text
Terraform             EC2                    guest first boot
---------             ---                    ----------------
create instance  -->  launch with ENI 0/1 ->  cloud-init sees both ENIs
                                             interface_fix.py sets both names
```

`aws_network_interface_attachment` is a separate Terraform resource. It needs
the instance ID, so Terraform creates the instance first and attaches the ENI
only afterward. From the guest point of view, the second ENI can appear after
cloud-init begins.

```text
Terraform             EC2                    guest first boot
---------             ---                    ----------------
create instance  -->  launch with ENI 0   ->  cloud-init starts
attach ENI 1      -->  attach ENI 1 later ->  interface_fix.py can see only ENI 0
```

If this race occurs, CML does not record the cluster interface and clustering
fails. Terraform has no direct signal from guest cloud-init that interface
selection has completed.

## Future migration design

To replace the remaining inline cluster ENI with
`aws_network_interface_attachment`, make CML first boot wait for the expected
number of data interfaces before it runs `interface_fix.py`.

Terraform already knows the topology. It must pass an expected data-interface
count through cloud-init:

| Node | Cluster enabled | Expected data interfaces |
| --- | --- | --- |
| Controller | no | 1 |
| Controller | yes | 2 |
| Compute | yes | 2 |
| AWS mini | not supported | 1 |

Do not count the loopback interface.

Required sequence:

```text
1. Terraform creates the VM with the primary ENI.
2. Terraform attaches the cluster ENI as a separate resource.
3. cloud-init receives the expected data-interface count.
4. CML provisioning waits, with a timeout, until all expected NICs exist.
5. NetworkManager/Netplan recognizes the new NIC.
6. Interface discovery uses live system state, not only the original
   /etc/netplan/50-cloud-init.yaml file.
7. interface_fix.py writes primary_interface and cluster_interface.
8. CML initial setup continues.
```

Use the live system to determine that an ENI has appeared. Suitable checks are
`ip link`, `/sys/class/net`, or NetworkManager. AWS IMDS can identify the ENI
for device number `1` and its MAC address. Match that MAC address to a Linux
network interface when interface order is not reliable.

A bounded wait must fail clearly if the expected ENI does not appear. Do not
continue CML cluster setup with only one data interface.

## Existing deployment migration

Changing a secondary ENI from an inline `network_interface` block to a separate
`aws_network_interface_attachment` resource also changes Terraform state
ownership. Before applying that future migration to an existing cluster:

1. Run `terraform plan` and confirm no CML instance replacement is planned.
2. Import each existing secondary-ENI attachment into its new resource address.
3. Verify that the plan does not detach and reattach a live cluster ENI.
4. Test a new cluster deployment and an in-place cluster upgrade.

Do not apply a migration that detaches the cluster ENI from a running CML
cluster.
