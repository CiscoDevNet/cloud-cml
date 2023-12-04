#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

# This is an unsupported workaround for the lack of the VMX CPU flag support on
# AWS.
#
# It will disable the check for the VMX CPU flag -- when this patch is in place,
# the system will always report the VMX flag to be present.
#
# Some platforms like Linux, IOSv and IOSv-L2 will still work but others will
# not and crash!

echo -n "no-VMX patch..."
(
cd /var/local/virl2/.local/lib/python3.8/site-packages
patch -p1 --forward <<EOF
diff -ru a/simple_core/libvirt/templates/qemu_node.xml b/simple_core/libvirt/templates/qemu_node.xml
--- a/simple_core/libvirt/templates/qemu_node.xml 2023-02-25 22:05:12.000000000 +0000
+++ b/simple_core/libvirt/templates/qemu_node.xml 2023-03-07 08:26:44.695350828 +0000
@@ -1,10 +1,10 @@
-<domain type="kvm">
+<domain type="qemu">
     <name>nodename</name>
     <uuid></uuid>
     <description></description>
     <memory unit="MiB">384</memory>
     <vcpu placement="auto">1</vcpu>
-    <cpu mode='host-passthrough'/>
+    <cpu/>
     <os>
         <type arch="x86_64" machine="pc">hvm</type>
         <boot dev="hd"/>
diff -ru a/simple_drivers/low_level_driver/host_statistics.py b/simple_drivers/low_level_driver/host_statistics.py
--- a/simple_drivers/low_level_driver/host_statistics.py  2023-02-25 22:05:12.000000000 +0000
+++ b/simple_drivers/low_level_driver/host_statistics.py  2023-03-07 08:25:58.774945279 +0000
@@ -267,7 +267,9 @@
 
 
         virtualization = self._get_cpu_info_field("Virtualization")
-        return virtualization in ("VT-x", "AMD-V")
+        # return virtualization in ("VT-x", "AMD-V")
+        return True
+
 
     def stats(self):
 
EOF
)
echo "done"
