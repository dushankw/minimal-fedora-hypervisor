### Ensure SPICE is using a socket

With our secure defaults, all that is required is to set the SPICE Listen directive to `None`

![spice config in guest vm](pic/spice.png)

##### Hypervisor level network filtering for VM

This will prevent various spoofing from the guest (eg: MAC, ARP), see  https://libvirt.org/firewall.html for more

On the host issue `sudo virsh edit --domain $DOMAIN`

Find the `<interface>` stanza and add:

```
<interface type='bridge'>
  ...
  <filterref filter='clean-traffic'/>
</interface>
```

##### NTP Issues

If you hibernate your VMs a lot, you may find the clock gets out of sync and takes a while to drift back

Adding `makestep 1 -1` to `/etc/chrony.conf` (chrony being the NTP client used in Fedora) will greatly reduce how many steps it takes to get back into sync
