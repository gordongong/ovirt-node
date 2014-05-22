%packages --excludedocs --nobase
ethtool
openstack-neutron
openstack-neutron-openvswitch
%end

%post
echo "Enable ip forward"
sed -i '/net\.ipv4\.conf\.all\.rp_filter/d' /etc/sysctl.conf
sed -i '/net\.ipv4\.conf\.default\.rp_filter/d' /etc/sysctl.conf
echo "" >>/etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter = 0" >>/etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 0" >>/etc/sysctl.conf

echo "Enable openvswitch service."
/sbin/chkconfig openvswitch on

echo "Initializing eth1."
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<EOF
DEVICE=eth1
ONBOOT=yes
BOOTPROTO=none
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=br-eth1
EOF

echo "Initializing br-int."
cat > /etc/sysconfig/network-scripts/ifcfg-br-int <<EOF
DEVICE=br-int
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=none
EOF

echo "Initializing br-eth1."
cat > /etc/sysconfig/network-scripts/ifcfg-br-eth1 <<EOF
DEVICE=br-eth1
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=none
EOF

%end
