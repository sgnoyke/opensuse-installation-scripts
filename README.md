# opensuse-installation-scripts

## Boot from live medium

Boot from a live iso, for example:
`openSUSE-Tumbleweed-XFCE-Live-aarch64-Snapshot20231204-Media.iso`. Open console and
change root password:

```
$ sudo su
$ passwd
$ useradd osi
$ passwd osi 
```

Press CTRL+ALT+F1 and switch to cli mode. Login with osi:

```
$ sudo loadkeys de
$ sudo systemctl start sshd.service 
$ sudo ip address
```

Login with ssh to the live environment from another mashine:

```
$ ssh osi@192.168.64.10
```

## Start opensuse install script

bash <(curl -H 'Cache-Control: no-cache' -s https://raw.githubusercontent.com/sgnoyke/opensuse-installation-scripts/main/main.sh)
