libvirtd:
	ansible-playbook plays/libvirtd.yml -i inventory -l laptop -c local --ask-become-pass

clean:
	rm -f *.retry plays/*.retry

all: libvirtd clean
