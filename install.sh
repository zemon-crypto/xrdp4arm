#/bin/bash
# Ubuntu20 desktop configuration (arm supported)

# quit immediately if there is an error
set -e
# ...
set -x

# Xrdp
function install_xrdp() {
	apt-get install -y xrdp
} 

# install desktop environment gnome. 
function install_desktop_env() {
	DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-shell ubuntu-gnome-desktop
}

# Xrdp PulseAudio
function install_xrdp_pa() {
	apt-get install -y git libpulse-dev autoconf m4 intltool build-essential dpkg-dev libtool libsndfile1-dev libspeexdsp-dev libudev-dev pulseaudio
	cp /etc/apt/sources.list /etc/apt/sources.list.u2ad
	sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
	apt-get update -y
	apt build-dep pulseaudio -y
	cd /tmp
	apt source pulseaudio
	pulsever=$(pulseaudio --version | awk '{print $2}')
	cd /tmp/pulseaudio-$pulsever
	# ./configure --without-caps
	./configure
	git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
	cd pulseaudio-module-xrdp
	./bootstrap
	./configure PULSE_DIR="/tmp/pulseaudio-$pulsever"
	make
	cd /tmp/pulseaudio-$pulsever/pulseaudio-module-xrdp/src/.libs
	install -t "/var/lib/xrdp-pulseaudio-installer" -D -m 644 *.so
	# systemctl restart dbus
	# systemctl restart pulseaudio
	systemctl restart xrdp
	# Issue: https://github.com/neutrinolabs/pulseaudio-module-xrdp/issues/44
	fix_pa_systemd_issue
}

# resolve PA no sound issue
# Issue: https://github.com/neutrinolabs/pulseaudio-module-xrdp/issues/44
function fix_pa_systemd_issue() {
mkdir -p /home/rdpuser/.config/systemd/user/
ln -s /dev/null /home/rdpuser/.config/systemd/user/pulseaudio.service
mkdir -p /home/rdpuser/.config/autostart/
cat <<EOF | \
  sudo tee /home/rdpuser/.config/autostart/pulseaudio.desktop
[Desktop Entry]
Type=Application
Exec=pulseaudio
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=pulseaudio
Name=pulseaudio
Comment[en_US]=pulseaudio
Comment=pulseaudio
EOF
chown -R rdpuser /home/rdpuser/.config/
chmod -R 755 /home/rdpuser/.config/
}

# create desktop user
function create_desktop_user() {
useradd -s /bin/bash -m rdpuser
usermod -a -G sudo rdpuser
echo "rdpuser ALL=(ALL) ALL" >> /etc/sudoers
echo "rdpuser_password
rdpuser_password
" | passwd rdpuser
}

# Xrdp environment configuration
function xrdp_conf() {
touch /home/rdpuser/.Xclients
echo "lxsession" > /home/rdpuser/.Xclients
chmod a+x /home/rdpuser/.Xclients
# sudo sed -e 's/^new_cursors=true/new_cursors=false/g' -i /etc/xrdp/xrdp.ini
cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.backup.u2ad
echo "$xrdp_config_base64" | base64 -d > /etc/xrdp/xrdp.ini
cat <<EOF | \
  sudo tee /etc/polkit-1/localauthority/50-local.d/xrdp-color-manager.pkla
[Netowrkmanager]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
systemctl restart xrdp
systemctl restart polkit
}

# desktop environment configuration
function desktop_env_conf() {
	# remove network icon
	apt-get remove -y network-manager-gnome
	# chrome has no arm64 version, install chromium
	apt-get install -y chromium-browser
}



apt-get update -y
apt-get install -y sudo screen

# create a desktop user 
create_desktop_user

# Install desktop environment
install_desktop_env

# install XRDP
install_xrdp

# install XRDP PA
install_xrdp_pa

# XRDP Environment Configuration
xrdp_config_base64="W0dsb2JhbHNdDQo7IHhyZHAuaW5pIGZpbGUgdmVyc2lvbiBudW1iZXINCmluaV92ZXJzaW9uPTENCg0KOyBmb3JrIGEgbmV3IHByb2Nlc3MgZm9yIGVhY2ggaW5jb21pbmcgY29ubmVjdGlvbg0KZm9yaz10cnVlDQoNCjsgcG9ydHMgdG8gbGlzdGVuIG9uLCBudW1iZXIgYWxvbmUgbWVhbnMgbGlzdGVuIG9uIGFsbCBpbnRlcmZhY2VzDQo7IDAuMC4wLjAgb3IgOjogaWYgaXB2NiBpcyBjb25maWd1cmVkDQo7IHNwYWNlIGJldHdlZW4gbXVsdGlwbGUgb2NjdXJyZW5jZXMNCjsNCjsgRXhhbXBsZXM6DQo7ICAgcG9ydD0zMzg5DQo7ICAgcG9ydD11bml4Oi8vLi90bXAveHJkcC5zb2NrZXQNCjsgICBwb3J0PXRjcDovLy46MzM4OSAgICAgICAgICAgICAgICAgICAgICAgICAgIDEyNy4wLjAuMTozMzg5DQo7ICAgcG9ydD10Y3A6Ly86MzM4OSAgICAgICAgICAgICAgICAgICAgICAgICAgICAqOjMzODkNCjsgICBwb3J0PXRjcDovLzxhbnkgaXB2NCBmb3JtYXQgYWRkcj46MzM4OSAgICAgIDE5Mi4xNjguMS4xOjMzODkNCjsgICBwb3J0PXRjcDY6Ly8uOjMzODkgICAgICAgICAgICAgICAgICAgICAgICAgIDo6MTozMzg5DQo7ICAgcG9ydD10Y3A2Oi8vOjMzODkgICAgICAgICAgICAgICAgICAgICAgICAgICAqOjMzODkNCjsgICBwb3J0PXRjcDY6Ly97PGFueSBpcHY2IGZvcm1hdCBhZGRyPn06MzM4OSAgIHtGQzAwOjA6MDowOjA6MDowOjF9OjMzODkNCjsgICBwb3J0PXZzb2NrOi8vPGNpZD46PHBvcnQ+DQpwb3J0PTMzODkNCg0KOyAncG9ydCcgYWJvdmUgc2hvdWxkIGJlIGNvbm5lY3RlZCB0byB3aXRoIHZzb2NrIGluc3RlYWQgb2YgdGNwDQo7IHVzZSB0aGlzIG9ubHkgd2l0aCBudW1iZXIgYWxvbmUgaW4gcG9ydCBhYm92ZQ0KOyBwcmVmZXIgdXNlIHZzb2NrOi8vPGNpZD46PHBvcnQ+IGFib3ZlDQp1c2VfdnNvY2s9ZmFsc2UNCg0KOyByZWd1bGF0ZSBpZiB0aGUgbGlzdGVuaW5nIHNvY2tldCB1c2Ugc29ja2V0IG9wdGlvbiB0Y3Bfbm9kZWxheQ0KOyBubyBidWZmZXJpbmcgd2lsbCBiZSBwZXJmb3JtZWQgaW4gdGhlIFRDUCBzdGFjaw0KdGNwX25vZGVsYXk9dHJ1ZQ0KDQo7IHJlZ3VsYXRlIGlmIHRoZSBsaXN0ZW5pbmcgc29ja2V0IHVzZSBzb2NrZXQgb3B0aW9uIGtlZXBhbGl2ZQ0KOyBpZiB0aGUgbmV0d29yayBjb25uZWN0aW9uIGRpc2FwcGVhciB3aXRob3V0IGNsb3NlIG1lc3NhZ2VzIHRoZSBjb25uZWN0aW9uIHdpbGwgYmUgY2xvc2VkDQp0Y3Bfa2VlcGFsaXZlPXRydWUNCg0KOyBzZXQgdGNwIHNlbmQvcmVjdiBidWZmZXIgKGZvciBleHBlcnRzKQ0KI3RjcF9zZW5kX2J1ZmZlcl9ieXRlcz0zMjc2OA0KI3RjcF9yZWN2X2J1ZmZlcl9ieXRlcz0zMjc2OA0KDQo7IHNlY3VyaXR5IGxheWVyIGNhbiBiZSAndGxzJywgJ3JkcCcgb3IgJ25lZ290aWF0ZScNCjsgZm9yIGNsaWVudCBjb21wYXRpYmxlIGxheWVyDQpzZWN1cml0eV9sYXllcj1uZWdvdGlhdGUNCg0KOyBtaW5pbXVtIHNlY3VyaXR5IGxldmVsIGFsbG93ZWQgZm9yIGNsaWVudCBmb3IgY2xhc3NpYyBSRFAgZW5jcnlwdGlvbg0KOyB1c2UgdGxzX2NpcGhlcnMgdG8gY29uZmlndXJlIFRMUyBlbmNyeXB0aW9uDQo7IGNhbiBiZSAnbm9uZScsICdsb3cnLCAnbWVkaXVtJywgJ2hpZ2gnLCAnZmlwcycNCmNyeXB0X2xldmVsPWhpZ2gNCg0KOyBYLjUwOSBjZXJ0aWZpY2F0ZSBhbmQgcHJpdmF0ZSBrZXkNCjsgb3BlbnNzbCByZXEgLXg1MDkgLW5ld2tleSByc2E6MjA0OCAtbm9kZXMgLWtleW91dCBrZXkucGVtIC1vdXQgY2VydC5wZW0gLWRheXMgMzY1DQo7IG5vdGUgdGhpcyBuZWVkcyB0aGUgdXNlciB4cmRwIHRvIGJlIGEgbWVtYmVyIG9mIHRoZSBzc2wtY2VydCBncm91cCwgZG8gd2l0aCBlLmcuDQo7JCBzdWRvIGFkZHVzZXIgeHJkcCBzc2wtY2VydA0KY2VydGlmaWNhdGU9DQprZXlfZmlsZT0NCg0KOyBzZXQgU1NMIHByb3RvY29scw0KOyBjYW4gYmUgY29tbWEgc2VwYXJhdGVkIGxpc3Qgb2YgJ1NTTHYzJywgJ1RMU3YxJywgJ1RMU3YxLjEnLCAnVExTdjEuMicsICdUTFN2MS4zJw0Kc3NsX3Byb3RvY29scz1UTFN2MS4yLCBUTFN2MS4zDQo7IHNldCBUTFMgY2lwaGVyIHN1aXRlcw0KI3Rsc19jaXBoZXJzPUhJR0gNCg0KOyBTZWN0aW9uIG5hbWUgdG8gdXNlIGZvciBhdXRvbWF0aWMgbG9naW4gaWYgdGhlIGNsaWVudCBzZW5kcyB1c2VybmFtZQ0KOyBhbmQgcGFzc3dvcmQuIElmIGVtcHR5LCB0aGUgZG9tYWluIG5hbWUgc2VudCBieSB0aGUgY2xpZW50IGlzIHVzZWQuDQo7IElmIGVtcHR5IGFuZCBubyBkb21haW4gbmFtZSBpcyBnaXZlbiwgdGhlIGZpcnN0IHN1aXRhYmxlIHNlY3Rpb24gaW4NCjsgdGhpcyBmaWxlIHdpbGwgYmUgdXNlZC4NCmF1dG9ydW49DQoNCmFsbG93X2NoYW5uZWxzPXRydWUNCmFsbG93X211bHRpbW9uPXRydWUNCmJpdG1hcF9jYWNoZT10cnVlDQpiaXRtYXBfY29tcHJlc3Npb249dHJ1ZQ0KYnVsa19jb21wcmVzc2lvbj10cnVlDQojaGlkZWxvZ3dpbmRvdz10cnVlDQptYXhfYnBwPTMyDQpuZXdfY3Vyc29ycz1mYWxzZQ0KOyBmYXN0cGF0aCAtIGNhbiBiZSAnaW5wdXQnLCAnb3V0cHV0JywgJ2JvdGgnLCAnbm9uZScNCnVzZV9mYXN0cGF0aD1ib3RoDQo7IHdoZW4gdHJ1ZSwgdXNlcmlkL3Bhc3N3b3JkICptdXN0KiBiZSBwYXNzZWQgb24gY21kIGxpbmUNCiNyZXF1aXJlX2NyZWRlbnRpYWxzPXRydWUNCjsgWW91IGNhbiBzZXQgdGhlIFBBTSBlcnJvciB0ZXh0IGluIGEgZ2F0ZXdheSBzZXR1cCAoTUFYIDI1NiBjaGFycykNCiNwYW1lcnJvcnR4dD1jaGFuZ2UgeW91ciBwYXNzd29yZCBhY2NvcmRpbmcgdG8gcG9saWN5IGF0IGh0dHA6Ly91cmwNCg0KOw0KOyBjb2xvcnMgdXNlZCBieSB3aW5kb3dzIGluIFJHQiBmb3JtYXQNCjsNCmJsdWU9MDA5Y2I1DQpncmV5PWRlZGVkZQ0KI2JsYWNrPTAwMDAwMA0KI2RhcmtfZ3JleT04MDgwODANCiNibHVlPTA4MjQ2Yg0KI2RhcmtfYmx1ZT0wODI0NmINCiN3aGl0ZT1mZmZmZmYNCiNyZWQ9ZmYwMDAwDQojZ3JlZW49MDBmZjAwDQojYmFja2dyb3VuZD02MjZjNzINCg0KOw0KOyBjb25maWd1cmUgbG9naW4gc2NyZWVuDQo7DQoNCjsgTG9naW4gU2NyZWVuIFdpbmRvdyBUaXRsZQ0KI2xzX3RpdGxlPU15IExvZ2luIFRpdGxlDQoNCjsgdG9wIGxldmVsIHdpbmRvdyBiYWNrZ3JvdW5kIGNvbG9yIGluIFJHQiBmb3JtYXQNCmxzX3RvcF93aW5kb3dfYmdfY29sb3I9MDA5Y2I1DQoNCjsgd2lkdGggYW5kIGhlaWdodCBvZiBsb2dpbiBzY3JlZW4NCmxzX3dpZHRoPTM1MA0KbHNfaGVpZ2h0PTQzMA0KDQo7IGxvZ2luIHNjcmVlbiBiYWNrZ3JvdW5kIGNvbG9yIGluIFJHQiBmb3JtYXQNCmxzX2JnX2NvbG9yPWRlZGVkZQ0KDQo7IG9wdGlvbmFsIGJhY2tncm91bmQgaW1hZ2UgZmlsZW5hbWUgKGJtcCBmb3JtYXQpLg0KI2xzX2JhY2tncm91bmRfaW1hZ2U9DQoNCjsgbG9nbw0KOyBmdWxsIHBhdGggdG8gYm1wLWZpbGUgb3IgZmlsZSBpbiBzaGFyZWQgZm9sZGVyDQpsc19sb2dvX2ZpbGVuYW1lPQ0KbHNfbG9nb194X3Bvcz01NQ0KbHNfbG9nb195X3Bvcz01MA0KDQo7IGZvciBwb3NpdGlvbmluZyBsYWJlbHMgc3VjaCBhcyB1c2VybmFtZSwgcGFzc3dvcmQgZXRjDQpsc19sYWJlbF94X3Bvcz0zMA0KbHNfbGFiZWxfd2lkdGg9NjUNCg0KOyBmb3IgcG9zaXRpb25pbmcgdGV4dCBhbmQgY29tYm8gYm94ZXMgbmV4dCB0byBhYm92ZSBsYWJlbHMNCmxzX2lucHV0X3hfcG9zPTExMA0KbHNfaW5wdXRfd2lkdGg9MjEwDQoNCjsgeSBwb3MgZm9yIGZpcnN0IGxhYmVsIGFuZCBjb21ibyBib3gNCmxzX2lucHV0X3lfcG9zPTIyMA0KDQo7IE9LIGJ1dHRvbg0KbHNfYnRuX29rX3hfcG9zPTE0Mg0KbHNfYnRuX29rX3lfcG9zPTM3MA0KbHNfYnRuX29rX3dpZHRoPTg1DQpsc19idG5fb2tfaGVpZ2h0PTMwDQoNCjsgQ2FuY2VsIGJ1dHRvbg0KbHNfYnRuX2NhbmNlbF94X3Bvcz0yMzcNCmxzX2J0bl9jYW5jZWxfeV9wb3M9MzcwDQpsc19idG5fY2FuY2VsX3dpZHRoPTg1DQpsc19idG5fY2FuY2VsX2hlaWdodD0zMA0KDQpbTG9nZ2luZ10NCkxvZ0ZpbGU9eHJkcC5sb2cNCkxvZ0xldmVsPURFQlVHDQpFbmFibGVTeXNsb2c9dHJ1ZQ0KU3lzbG9nTGV2ZWw9REVCVUcNCjsgTG9nTGV2ZWwgYW5kIFN5c0xvZ0xldmVsIGNvdWxkIGJ5IGFueSBvZjogY29yZSwgZXJyb3IsIHdhcm5pbmcsIGluZm8gb3IgZGVidWcNCg0KW0NoYW5uZWxzXQ0KOyBDaGFubmVsIG5hbWVzIG5vdCBsaXN0ZWQgaGVyZSB3aWxsIGJlIGJsb2NrZWQgYnkgWFJEUC4NCjsgWW91IGNhbiBibG9jayBhbnkgY2hhbm5lbCBieSBzZXR0aW5nIGl0cyB2YWx1ZSB0byBmYWxzZS4NCjsgSU1QT1JUQU5UISBBbGwgY2hhbm5lbHMgYXJlIG5vdCBzdXBwb3J0ZWQgaW4gYWxsIHVzZQ0KOyBjYXNlcyBldmVuIGlmIHlvdSBzZXQgYWxsIHZhbHVlcyB0byB0cnVlLg0KOyBZb3UgY2FuIG92ZXJyaWRlIHRoZXNlIHNldHRpbmdzIG9uIGVhY2ggc2Vzc2lvbiB0eXBlDQo7IFRoZXNlIHNldHRpbmdzIGFyZSBvbmx5IHVzZWQgaWYgYWxsb3dfY2hhbm5lbHM9dHJ1ZQ0KcmRwZHI9dHJ1ZQ0KcmRwc25kPXRydWUNCmRyZHludmM9dHJ1ZQ0KY2xpcHJkcj10cnVlDQpyYWlsPXRydWUNCnhyZHB2cj10cnVlDQp0Y3V0aWxzPXRydWUNCg0KOyBmb3IgZGVidWdnaW5nIHhyZHAsIGluIHNlY3Rpb24geHJkcDEsIGNoYW5nZSBwb3J0PS0xIHRvIHRoaXM6DQojcG9ydD0vdG1wLy54cmRwL3hyZHBfZGlzcGxheV8xMA0KDQo7IGZvciBkZWJ1Z2dpbmcgeHJkcCwgYWRkIGZvbGxvd2luZyBsaW5lIHRvIHNlY3Rpb24geHJkcDENCiNjaGFuc3J2cG9ydD0vdG1wLy54cmRwL3hyZHBfY2hhbnNydl9zb2NrZXRfNzIxMA0KDQoNCjsNCjsgU2Vzc2lvbiB0eXBlcw0KOw0KDQo7IFNvbWUgc2Vzc2lvbiB0eXBlcyBzdWNoIGFzIFhvcmcsIFgxMXJkcCBhbmQgWHZuYyBzdGFydCBhIGRpc3BsYXkgc2VydmVyLg0KOyBTdGFydHVwIGNvbW1hbmQtbGluZSBwYXJhbWV0ZXJzIGZvciB0aGUgZGlzcGxheSBzZXJ2ZXIgYXJlIGNvbmZpZ3VyZWQNCjsgaW4gc2VzbWFuLmluaS4gU2VlIGFuZCBjb25maWd1cmUgYWxzbyBzZXNtYW4uaW5pLg0KW1hvcmddDQpuYW1lPVhvcmcNCmxpYj1saWJ4dXAuc28NCnVzZXJuYW1lPWFzaw0KcGFzc3dvcmQ9YXNrDQppcD0xMjcuMC4wLjENCnBvcnQ9LTENCmNvZGU9MjANCg0KIyBbWHZuY10NCiMgbmFtZT1Ydm5jDQojIGxpYj1saWJ2bmMuc28NCiMgdXNlcm5hbWU9YXNrDQojIHBhc3N3b3JkPWFzaw0KIyBpcD0xMjcuMC4wLjENCiMgcG9ydD0tMQ0KI3hzZXJ2ZXJicHA9MjQNCiNkZWxheV9tcz0yMDAwDQoNCiMgW3ZuYy1hbnldDQojIG5hbWU9dm5jLWFueQ0KIyBsaWI9bGlidm5jLnNvDQojIGlwPWFzaw0KIyBwb3J0PWFzazU5MDANCiMgdXNlcm5hbWU9bmENCiMgcGFzc3dvcmQ9YXNrDQojcGFtdXNlcm5hbWU9YXNrc2FtZQ0KI3BhbXBhc3N3b3JkPWFza3NhbWUNCiNwYW1zZXNzaW9ubW5nPTEyNy4wLjAuMQ0KI2RlbGF5X21zPTIwMDANCg0KIyBbbmV1dHJpbm9yZHAtYW55XQ0KIyBuYW1lPW5ldXRyaW5vcmRwLWFueQ0KIyBsaWI9bGlieHJkcG5ldXRyaW5vcmRwLnNvDQojIGlwPWFzaw0KIyBwb3J0PWFzazMzODkNCiMgdXNlcm5hbWU9YXNrDQojIHBhc3N3b3JkPWFzaw0KDQo7IFlvdSBjYW4gb3ZlcnJpZGUgdGhlIGNvbW1vbiBjaGFubmVsIHNldHRpbmdzIGZvciBlYWNoIHNlc3Npb24gdHlwZQ0KI2NoYW5uZWwucmRwZHI9dHJ1ZQ0KI2NoYW5uZWwucmRwc25kPXRydWUNCiNjaGFubmVsLmRyZHludmM9dHJ1ZQ0KI2NoYW5uZWwuY2xpcHJkcj10cnVlDQojY2hhbm5lbC5yYWlsPXRydWUNCiNjaGFubmVsLnhyZHB2cj10cnVlDQo="
xrdp_conf

# Desktop Environment Configuration
desktop_env_conf

apt-get autoremove -y

echo "Install Done!"
echo "Now you can reboot and connect port 3389 with rdp client"
echo "Note: chromium-browser is not displayed on the desktop, please start it manually if necessary"
echo "Default Username: rdpuser"
echo "Default Password: rdpuser_password"
