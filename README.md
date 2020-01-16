# minimal-fedora-hypervisor

Ansible tooling to configure libvirtd in a secure and minimal way under Fedora

**Still a work in progress**

### credit

Portions of this guide (some networking stuff) refer to documentation found on https://jamielinux.com

### useful references

* https://libvirt.org/firewall.html
* https://libvirt.org/formatnwfilter.html

### configuration

See `host_vars/127.0.0.1`

### usage

0. `sudo dnf -y update`
1. `sudo dnf -y install ansible make python3-dnf python3-libselinux python3-libvirt python3-lxml`
2. `make`
