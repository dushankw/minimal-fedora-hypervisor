### Screen Resolution

The virtual display may present only lower resolutions, to fix this requires a few steps

NOTE: It is assumed you are using Xorg and not Wayland as your display server within the VM

##### Increase the amount of video memory

On the host issue `sudo virsh edit --domain $DOMAIN`

Locate the `<video>` stanza and set the `vgamem` to something reasonable (units are in kilobyes)

```
<video>
  <model type='qxl' ram='65536' vram='65536' vgamem='65536' heads='1' primary='yes'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
</video>
```

##### Generate modeline for Xorg to use

```
$ cvt 2560 1440 
# 2560x1440 59.96 Hz (CVT 3.69M9) hsync: 89.52 kHz; pclk: 312.25 MHz
Modeline "2560x1440_60.00"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
```

Create modeline

```
$ xrandr --newmode "2560x1440_60.00"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
```

Add and use it

```
$ xrandr --addmode Virtual-0 2560x1440_60.00
$ xrandr --output Virtual-0 --mode 2560x1440_60.00
```

Persist between reboots

Create `/usr/share/X11/xorg.conf.d/10-monitor.conf` (owned by root with mode 0644)

```
section "Monitor"
    Identifier "Virtual-0 "
    Modeline "2560x1440_60.00"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
    Modeline "3840x2160_60.00"  712.75  3840 4160 4576 5312  2160 2163 2168 2237 -hsync +vsync
    Option "PreferredMode" "2560x1440_60.00"
EndSection
```
