install:
	mkdir -p $(DESTDIR)/usr/bin $(DESTDIR)/usr/libexec $(DESTDIR)/etc/sudoers.d
	install -o root -g root -m 755 bin/containerize $(DESTDIR)/usr/bin/containerize
	install -o root -g root -m 700 libexec/containerize $(DESTDIR)/usr/libexec/containerize
	install -o root -g root -m 440 etc/containerize.sudo $(DESTDIR)/etc/sudoers.d/containerize.sudo
