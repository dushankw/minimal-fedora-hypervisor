# Configuring libvirtd with kvm/qemu under Fedora 

### Ensure firewalld is disabled (since we are going to use iptables)

```
sudo systemctl stop firewalld
sudo systemctl mask firewalld
sudo dnf remove firewalld
```

### Install iptables

```
sudo dnf install iptables-services
sudo systemctl start iptables ip6tables
sudo systemctl enable iptables ip6tables
```

### Install virtualization meta-package and some required utilities

NOTE: In future I will investigate cutting this down and installing specific packages

```
sudo dnf update --refresh
sudo dnf install @virtualization
sudo dnf install libguestfs libguestfs-tools bridge-utils virt-top ebtables libvirt-daemon-config-nwfilter
```

### Add user to required groups

Enables you to communicate with libvirtd over its socket without being root

```
sudo usermod -a -G libvirt $USER
```

### Configure the network manually

It is assumed we are using NetworkManager

Libvirtd will configure a default NAT network, however my preference is to explicitly define and control networks on my system (and the default network will manipulate iptables without your permission)

##### Disable the default network, create a bridge and enable packet forwarding

```
sudo virsh net-destroy default
sudo virsh net-autostart --disable default
```

Create a dummy network interface that we will use as a member of a bridge that will be supplied to VMs. The reason we are doing this is because a bridge inherits the MAC address of the first interface that is attached, so it will keep changing unless the same VM is always powered on first or we supply a dummy. 

NOTE: Libvirtd expects MAC addresses for KVM to be of the form `52:54:00:xx:xx:xx`

Create `/etc/NetworkManager/dispatcher.d/99-virbr10` (owned to root with mode 0755), the dnsmasq stuff will make sense in a moment

```
#!/bin/sh
[ "$1" != "virbr10" ] && exit 0
case "$2" in
    "up")
        /sbin/ip link add virbr10-dummy address 52:54:00:00:00:a1 type dummy
        /usr/sbin/brctl addif virbr10 virbr10-dummy
	/bin/systemctl start dnsmasq@virbr10.service || :
        ;;
    "down")
        /bin/systemctl stop dnsmasq@virbr10.service || :
        ;;
esac
```

Create `/etc/sysconfig/network-scripts/ifcfg-virbr10` (owned to root with mode 0644)

```
DEVICE=virbr10
NAME=virbr10
NM_CONTROLLED=yes
ONBOOT=yes
TYPE=Bridge
DELAY=2
STP=on
IPADDR=192.168.100.1
NETMASK=255.255.255.0
IPV6INIT=no
```

Enable packet forwarding by creating `/etc/sysctl.d/98-ipforward.conf` (owned to root with mode 0644)

```
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding=1
```

For performance and security reasons, disable netfilter for bridges (see https://bugzilla.redhat.com/show_bug.cgi?id=512206)

Create `/etc/sysctl.d/97-bridge.conf` (owned to root with mode 0644)

```
net.bridge.bridge-nf-call-ip6tables=0
net.bridge.bridge-nf-call-iptables=0
net.bridge.bridge-nf-call-arptables=0
```

Create `/etc/udev/rules.d/99-bridge.rules` (owned to root with mode 0644) to load the rules when the bridge module is loaded

```
ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/sbin/sysctl -p /etc/sysctl.d/97-bridge.conf"
```

##### Configure iptables

The following is a basic IPv4 configuration that you can use (I do not require IPv6 for my VMs or host and configure blanket DROP rules on the INPUT/FORWARD/OUTPUT ip6tables chains)

Place the configuration in `/etc/sysconfig/iptables` (owned to root with mode 0600)

```
*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
# DHCP packets sent to VMs have no checksum (due to a longstanding bug)
-A POSTROUTING -o virbr10 -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
# Do not masquerade to these reserved address blocks
-A POSTROUTING -s 192.168.100.0/24 -d 224.0.0.0/24 -j RETURN
-A POSTROUTING -s 192.168.100.0/24 -d 255.255.255.255/32 -j RETURN
# Masquerade all packets going from VMs to the LAN/Internet
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -j MASQUERADE
COMMIT

*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
# Allow basic INPUT traffic
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
# Accept DNS (port 53) and DHCP (port 67) packets from VMs via bridge interface
-A INPUT -i virbr10 -p udp -m udp -m multiport --dports 53,67 -j ACCEPT
-A INPUT -i virbr10 -p tcp -m tcp -m multiport --dports 53,67 -j ACCEPT

# Allow established traffic to the private subnet
-A FORWARD -d 192.168.100.0/24 -o virbr10 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Allow outbound traffic from the private subnet
-A FORWARD -s 192.168.100.0/24 -i virbr10 -j ACCEPT
# Allow traffic between virtual machines
-A FORWARD -i virbr10 -o virbr10 -j ACCEPT
COMMIT
```

##### Configure dnsmasq which is used for DHCP and DNS forwarding for VMs

```
mkdir -p /var/lib/dnsmasq/virbr10
touch /var/lib/dnsmasq/virbr10/hostsfile
touch /var/lib/dnsmasq/virbr10/leases
```

Create a config for dnsmasq in `/var/lib/dnsmasq/virbr10/dnsmasq.conf` (owned to root with mode 0644)

```
# Only bind to the virtual bridge (avoids exposure on public interface and conflicts with other instances) 
# except-interface=lo
# interface=virbr10
# bind-dynamic

# Listen explicitly on IPv4 only, on the address bound to virbr10
listen-address=192.168.100.1

# IPv4 addresses to offer to VMs (should match subnet of bridge)
dhcp-range=192.168.100.2,192.168.100.254

# Set this to at least the total number of addresses in DHCP-enabled subnets
dhcp-lease-max=1000

# File to write DHCP lease information to
dhcp-leasefile=/var/lib/dnsmasq/virbr10/leases

# File to read DHCP host information from
dhcp-hostsfile=/var/lib/dnsmasq/virbr10/hostsfile

# Avoid problems with old or broken clients
dhcp-no-override

# https://www.redhat.com/archives/libvir-list/2010-March/msg00038.html
strict-order

# Write the PID file to a sensible location
pid-file=/var/run/dnsmasq-virbr10.pid

# Drop privileges (this should be the default already)
# user=nobody
```

And a systemd service to run dnsmasq in `/etc/systemd/system/dnsmasq@.service` (owned to root with mode 0644)

```
# '%i' becomes 'virbr10' when running `systemctl start dnsmasq@virbr10.service`

[Unit]
Description=DHCP and DNS caching server for %i
After=network.target

[Service]
ExecStart=/usr/sbin/dnsmasq -k --conf-file=/var/lib/dnsmasq/%i/dnsmasq.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### Hardening

##### Limit access to the libvirtd control sockets

Add the following to `/etc/libvirt/libvirtd.conf`

```
unix_sock_group = "libvirt"
unix_sock_ro_perms = "0770"
unix_sock_rw_perms = "0770"
unix_sock_admin_perms = "0700"
```

##### Hardening for qemu

Add/un-comment the following lines in `/etc/libvirt/qemu.conf`

```
vnc_auto_unix_socket = 1
spice_auto_unix_socket = 1
security_driver = "selinux"
security_default_confined = 1
security_require_confined = 1
set_process_name = 1
seccomp_sandbox = 1
```

NOTE: Look into configuring Server CA + TLS encrypted network transports

### Reboot

Many things have changed at this point, reboot the system and your hypervisor should be functional
