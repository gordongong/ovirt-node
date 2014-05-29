#! /bin/bash
######### check

if ! options=$(getopt -u -o c:l: --long controllerip:,localip: -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    echo "Usage: sh config_compute_node.sh --controllerip ip --localip ip"
    exit 1
fi

set -- $options

while [ $# -gt 0 ]
do
    case $1 in
    -c|--controllerip) controllerip=$2; shift;;
    -l|--localip) localip=$2; shift;;
    (--) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
    esac
    shift
done

if [ "$controllerip" == "" -o "$localip" == "" ];then 
  echo "Usage: sh config_compute_node.sh --controllerip ip --localip ip"
  exit 1
fi


######### common config
echo "begin: config common module"

if [ ! -d  "/data/var/lib" ]; then mkdir -p /data/var/lib; fi

persist /etc/rc.d

echo "/etc/libvirt/qemu /config/etc/libvirt/qemu bind bind 0 0" >> /etc/fstab

rm -rf /etc/localtime
cp -rf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
persist /etc/localtime

service ntpd stop & ntpdate $controllerip
persist /etc/crontab
echo "* */1 * * *  root service ntpd stop & ntpdate $controllerip" >> /etc/crontab

echo "end: config common module"


######### config nova
echo "begin: config nova"

if [ ! -d  "/data/var/lib/nova/instances" ]; then mkdir -p /data/var/lib/nova/instances; fi
chown -R nova:nova /data/var/lib/nova/

persist /etc/nova

cp -rf template/nova.conf /etc/nova/
chown root:nova /etc/nova/nova.conf

sed -i "s/\/var\/lib/\/data\/var\/lib/g" /etc/nova/nova.conf 
sed -i "s/128.0.0.1/$controllerip/g" /etc/nova/nova.conf 
sed -i "s/127.0.0.1/$localip/g" /etc/nova/nova.conf 

/sbin/chkconfig openstack-nova-compute on
service openstack-nova-compute restart

echo "end: config nova"

######### config cinder
echo "begin: config cinder"

if [ ! -d  "/data/var/lib/cinder" ]; then mkdir -p /data/var/lib/cinder; fi
chown -R cinder:cinder /data/var/lib/cinder/

persist /etc/cinder

cp -rf template/cinder.conf /etc/cinder/
chown root:cinder /etc/cinder/cinder.conf
cp -rf template/api-paste.ini /etc/cinder/
chown root:cinder /etc/cinder/api-paste.ini

sed -i "s/state_path = \/var\/lib\/cinder/state_path = \/data\/var\/lib\/cinder/g" /etc/cinder/cinder.conf
sed -i "s/lock_path=\/var\/lib\/cinder\/tmp/lock_path=\/data\/var\/lib\/cinder\/tmp/g" /etc/cinder/cinder.conf
sed -i "s/128.0.0.1/$controllerip/g" /etc/cinder/cinder.conf
sed -i "s/127.0.0.1/$localip/g" /etc/cinder/cinder.conf
sed -i "s/128.0.0.1/$controllerip/g" /etc/cinder/api-paste.ini


# create default vg, currently only retain 5G for /data, the left will be used by vg
vgdisplay cinder-volumes
if [ $? -ne 0 ];then
  datadirsize=`lvs /dev/HostVG/Data -o LV_SIZE --noheadings --units g --nosuffix`
  datadirsize=${datadirsize%%.*}
  leftsize=`expr $datadirsize - 5`
  if [ $leftsize -lt 0 ];then
    echo "space is not enough for creating default vg"
    exit
  fi
  leftsize=`expr $leftsize \* 1024`

  dd if=/dev/zero of=/data/var/lib/cinder/cinder-volumes bs=1 count=0 seek=$leftsize"M"
  lofi=`losetup --show -f /data/var/lib/cinder/cinder-volumes`
  pvcreate $lofi
  vgcreate cinder-volumes $lofi
  # Add the loop device on boot
  echo "losetup -f /data/var/lib/cinder/cinder-volumes && vgchange -a y cinder-volumes && service openstack-cinder-volume restart" >> /etc/rc.d/rc.local 

fi

echo "include /etc/cinder/volumes/*" >> /etc/tgt/targets.conf
/sbin/chkconfig tgtd on
service tgtd restart
persist /etc/tgt

service openstack-cinder-volume restart

echo "end: config cinder"


######### config neutron
echo "begin: config neutron"

if [ ! -d  "/data/var/lib/neutron" ]; then mkdir -p /data/var/lib/neutron; fi
chown -R neutron:neutron /data/var/lib/neutron/

persist /etc/neutron

cp -rf template/ifcfg-* /etc/sysconfig/network-scripts/
service network restart

cp -rf template/neutron.conf /etc/neutron/
chown root:neutron /etc/neutron/neutron.conf
cp -rf template/ovs_neutron_plugin.ini /etc/neutron/plugins/openvswitch/
chown root:neutron /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
ln -s /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugin.ini

sed -i "s/state_path = \/var\/lib\/neutron/state_path = \/data\/var\/lib\/neutron/g" /etc/neutron/neutron.conf
sed -i "s/128.0.0.1/$controllerip/g" /etc/neutron/neutron.conf
sed -i "s/127.0.0.1/$localip/g" /etc/neutron/neutron.conf

/sbin/chkconfig neutron-openvswitch-agent on
service neutron-openvswitch-agent restart

sed -i '/net\.ipv4\.conf\.all\.rp_filter/d' /etc/sysctl.conf
sed -i '/net\.ipv4\.conf\.default\.rp_filter/d' /etc/sysctl.conf
sed -i '/net\.ipv4\.ip_forward/d' /etc/sysctl.conf
echo "" >>/etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter = 0" >>/etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 0" >>/etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >>/etc/sysctl.conf
sysctl -p

echo "end: config neutron"


######## config ceilometer
echo "begin: config ceilometer"

persist /etc/ceilometer
cp -rf template/ceilometer.conf /etc/ceilometer/
chown root:ceilometer /etc/ceilometer/ceilometer.conf
/sbin/chkconfig openstack-ceilometer-compute on
service openstack-ceilometer-compute restart

echo "end: config ceilometer"
