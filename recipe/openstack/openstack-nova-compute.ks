%packages --excludedocs --nobase
mysql
MySQL-python
libvirt
libiscsi
qemu-kvm
openstack-utils
openstack-nova-common
openstack-nova-compute
%end


%post
# make sure we don't autostart virbr0 on libvirtd startup
rm -f /etc/libvirt/qemu/networks/autostart/default.xml
%end

