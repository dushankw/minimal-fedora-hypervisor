# minimal-fedora-hypervisor

Ansible tooling to configure libvirtd in a secure and minimal way under Fedora

**This tooling is written to work with NetworkManager, it will not work if you are not using it**

### credit

Portions of this guide (some networking stuff) refer to documentation found on https://jamielinux.com

### useful references

* https://libvirt.org/firewall.html
* https://libvirt.org/formatnwfilter.html

### configuration

See `host_vars/127.0.0.1`

You will need to modify to match your environment

### warnings

During the deployment there may be a period of time (between `firewalld` being disabled [only if it exists] and `iptables` being enabled) where there will be no `netfilter` configuration.

This poses a security issue for a host directly accessible via the internet (any network services running [other than those binding localhost] will be exposed), at some point I will re-order things (and eliminate a possible race condition) to address this, though currently this project is specifically designed for local use where this is not a concern.

### dns for virtual machines

Your guests will need to be told that the Hypervisor provided DNS server is on `192.168.100.1:53535/UDP`

The reason for this is Fedora 33 (and beyond) have moved to `systemd-resolvd` which claims the usual `53/UDP`

In the future I may remove `dnsmasq` totally and leverage `systemd-resolvd` for the guests and host, but currently, this is the solution, PRs welcome

### usage

0. `sudo dnf -y update`
1. `sudo dnf -y install ansible make python3-dnf python3-libselinux python3-libvirt python3-lxml`
2. `make`
3. `sudo reboot`

VMs can be created with the `mkvm.sh` script.

### useful settings

##### virt-manager

Enable the setting "Resize guest with window" in virt-manager via the "Edit > Preferences > Console" menu and supported guests should set their resolution automatically based on the virt-manager window size.

##### ntp issues in guests

If you hibernate your VMs a lot, you may find the clock gets out of sync and takes a while to drift back.

Adding `makestep 1 -1` to `/etc/chrony.conf` will greatly reduce how many steps it takes to get back into sync.

##### shrinking qcow2 volumes

qcow2 volumes do not shrink once space is allocated, if you have deleted a bunch of stuff from within one, you need to resize it to free the actual space on disk

**Make sure any VMs using the volume are off before you begin!**

```
qemu-img convert -O qcow2 original.qcow2 shrunk.qcow2
mv -f shrunk.qcow2 original.qcow2
```
