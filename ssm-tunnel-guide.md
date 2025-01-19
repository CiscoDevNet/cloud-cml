# SSM Tunneling with sshuttle on macOS

## Overview
This guide explains how to set up secure tunneling to AWS private subnets using AWS Systems Manager (SSM) and sshuttle on macOS. The solution uses packet filter (PF) rules to enable proper traffic forwarding.

## Understanding Packet Filter (PF)
PF is macOS's network packet filter, inherited from OpenBSD. The configuration consists of:

1. **Anchors**: Named rulesets that can be loaded/unloaded dynamically
2. **Rules**: Define how traffic should be handled
3. **Quick**: Keyword that stops rule processing when a match is found

The rule syntax we use:
```text
pass [in|out] quick [proto protocol] from source to destination [keep state]

- pass: Allow the traffic
- in/out: Traffic direction
- quick: Stop processing rules when matched
- proto: Specify protocol (tcp, udp, etc)
- keep state: Track connection state
```

## Setup Instructions

### 1. Configure Packet Filter
Create a new anchor file for sshuttle:

```bash
sudo tee /etc/pf.anchors/sshuttle << EOF
# Allow SSM tunnel traffic
pass in quick proto tcp from any to any port 2222 keep state
pass out quick proto tcp from any to any port 2222 keep state

# Allow forwarded subnet traffic
pass in quick from 10.0.0.0/16 to any keep state
pass out quick from any to 10.0.0.0/16 keep state
EOF
```

These rules:
- Allow TCP traffic to/from port 2222 (SSM tunnel)
- Allow all traffic to/from the 10.0.0.0/16 subnet
- Use `quick` to ensure rule matching stops when found
- Use `keep state` to track connection states

### 2. Update PF Configuration
Add the sshuttle anchor to `/etc/pf.conf`:

```bash
# Add before the final load anchor line
anchor "sshuttle/*"
load anchor "sshuttle" from "/etc/pf.anchors/sshuttle"
```

### 3. Apply PF Rules
Reload the PF configuration:

```bash
sudo pfctl -f /etc/pf.conf
```

### 4. Start SSM Port Forwarding
In terminal 1:
```bash
aws ssm start-session \
  --target i-XXXXXXXXXXXXX \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["22"],"localPortNumber":["2222"]}'
```

### 5. Start Sshuttle
In terminal 2:
```bash
sshuttle -r localhost:2222 10.0.0.0/16 -v
```

## Notes

### Troubleshooting PF
Check PF status:
```bash
sudo pfctl -si
```

View loaded rules:
```bash
sudo pfctl -sr
```

View anchors:
```bash
sudo pfctl -sa
```

### Important Considerations
- Keep both SSM session and sshuttle running for the tunnel to work
- Adjust the subnet (10.0.0.0/16) to match your target VPC
- Port 2222 can be changed if needed
- SSM requires appropriate IAM permissions
- PF rules persist across reboots but need to be enabled

### Security Notes
- SSM provides secure access without direct SSH exposure
- All traffic is encrypted through the SSM session
- PF rules are scoped to specific ports and subnets
- Connection states are tracked for better security
