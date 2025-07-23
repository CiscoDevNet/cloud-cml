#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
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

echo "no-VMX patch..."
(
    cd /var/local/virl2/.local/lib/python3.12/site-packages || exit
    patch -p1 --forward <<EOF
--- a/simple_core/handlers/templates/qemu_node.xml
+++ b/simple_core/handlers/templates/qemu_node.xml
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
         <type arch="x86_64" machine="pc-i440fx-8.0">hvm</type>
         <boot dev="hd"/>
--- a/simple_drivers/low_level_driver/host_statistics.py
+++ b/simple_drivers/low_level_driver/host_statistics.py
@@ -420,7 +420,8 @@


         virtualization = self._get_cpu_info_field("Virtualization") in ("VT-x", "AMD-V")
-        return virtualization and self._get_dev_kvm() and self._get_kvm_live()
+        # return virtualization and self._get_dev_kvm() and self._get_kvm_live()
+        return True

     def stats(self) -> dict[str, dict[str, Any]]:

EOF
    systemctl restart virl2.target
)
echo "done"
