# libvirt-sandbox

* https://fedoraproject.org/wiki/Features/VirtSandbox
* https://selinuxproject.org/page/NB_SandBox
* http://people.redhat.com/berrange/fosdem-2012/libvirt-sandbox-fosdem-2012.pdf
* https://www.berrange.com/posts/2012/01/17/building-application-sandboxes-with-libvirt-lxc-kvm/ (the developer acknowledges the total lack of SELinux support)

### Installing and basic use

```
sudo dnf install libvirt-sandbox
virt-sandbox -c qemu:///session /usr/bin/bash
```

### SELinux

Invocation resulted in an issue reading the file `/etc/libvirt-sandbox/scratch/mounts.cfg` and my suspicion was that SELinux was to blame...

Doing a `setenforce 0` proved this hypothesis, so let's fix it!

With SELinux in permissive mode (I hope you are doing this on a devbox!) take note of the current time:

```
$ date
Wed Jun  3 16:58:27 AEST 2020
```

Invoke the sandbox again (successfully), then exit from it and generate a policy from all the captured violations:

```
ausearch -m AVC,USER_AVC -ts 'HH:MM:SS' | audit2why
ausearch -m AVC,USER_AVC -ts 'HH:MM:SS' | audit2allow -M virt_sandbox_dkw
```

Review `virt_sandbox_dkw.te` to make sure it is sane, then install it with `semodule -i virt_sandbox_dkw.pp`

Set SELinux back to enforcing `setenforce 1`

Take note of the time again, re-invoke the sandbox and exit, then review the SELinux log `ausearch -m AVC,USER_AVC -ts 'HH:MM:SS'`

Hopefully there are no more violations, should you find more (such as when you sandbox a different application), the same method can be applied to address them

**NOTE: This is a WIP and I have not properly reviewed the resulting policy, I feel it may be too permissive and I am not personally using this tool yet!**

### To Do

Get graphical applications to work

### Warnings

This tool does not seem to be under very active development

```
$ dnf changelog libvirt-sandbox
<SNIP>
Listing all changelogs
Changelogs for libvirt-sandbox-0.8.0-4.fc31.x86_64
* Thu Jul 25 00:00:00 2019 Fedora Release Engineering <releng@fedoraproject.org> - 0.8.0-4
- Rebuilt for https://fedoraproject.org/wiki/Fedora_31_Mass_Rebuild

* Fri Feb 01 00:00:00 2019 Fedora Release Engineering <releng@fedoraproject.org> - 0.8.0-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_30_Mass_Rebuild

* Fri Jul 13 00:00:00 2018 Fedora Release Engineering <releng@fedoraproject.org> - 0.8.0-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_29_Mass_Rebuild

* Fri Jun 08 00:00:00 2018 Daniel P. Berrangé <berrange@redhat.com> - 0.8.0-1
- Update to 0.8.0 release

* Mon Mar 26 00:00:00 2018 Iryna Shcherbina <ishcherb@redhat.com> - 0.6.0-7
- Update Python 2 dependency declarations to new packaging standards
  (See https://fedoraproject.org/wiki/FinalizingFedoraSwitchtoPython3)

* Wed Feb 07 00:00:00 2018 Fedora Release Engineering <releng@fedoraproject.org> - 0.6.0-6
- Rebuilt for https://fedoraproject.org/wiki/Fedora_28_Mass_Rebuild

* Thu Aug 03 00:00:00 2017 Fedora Release Engineering <releng@fedoraproject.org> - 0.6.0-5
- Rebuilt for https://fedoraproject.org/wiki/Fedora_27_Binutils_Mass_Rebuild
```
