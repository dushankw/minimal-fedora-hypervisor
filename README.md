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

### usage

0. `sudo dnf -y update`
1. `sudo dnf -y install ansible make python3-dnf python3-libselinux python3-libvirt python3-lxml`
2. `make`
3. `sudo reboot`
