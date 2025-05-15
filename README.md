# Rocinante

Work Horse.

Something to do the heavy lifting.

Configuration management from the team that brought you BastilleBSD.

## Configuration Management

Rocinante makes Bastille templates compatible with a host system. This means
you can automate host configuration the same way you configure containers.

Same files. Same format.

## Installation

Rocinante can be found in FreeBSD ports at `sysutils/rocinante`.
```
pkg install rocinante
```
or
```
git clone https://github.com/BastilleBSD/rocinante.git
then cd rocinante
make install
```

### Examples

This example demonstrates applying a `Bastillefile` template to a host system.

```
holden ~ # rocinante verify cedwards/base
Detected Bastillefile hook.
[Bastillefile]:
PKG htop vim git-lite
CP etc /
SYSRC cloned_interfaces+=lo1
SERVICE ntpd restart
SYSCTL kern.randompid=1

Template ready to use.
```

```
holden ~ # rocinante template cedwards/base
[TEMPLATE]:
Applying template: cedwards/base...

[PKG]:
Updating poudriere-local repository catalogue...
poudriere-local repository is up to date.
All repositories are up to date.
Checking integrity... done (0 conflicting)
The most recent versions of packages are already installed

[CP]:
/usr/local/rocinante/templates/cedwards/base/etc -> /etc
/usr/local/rocinante/templates/cedwards/base/etc/ntp.conf -> /etc/ntp.conf

[SYSRC]:
cloned_interfaces: lo1 -> lo1

[SERVICE]:
Stopping ntpd.
Waiting for PIDS: 16118.
Starting ntpd.

[SYSCTL]:
kern.randompid: 658 -> 713

Template applied: cedwards/base

```
