Template
========

Rocinante supports a templating system allowing you to apply files, pkgs and
execute commands inside the containers automatically.

Rocinante
---------

Rocinante introduces a template syntax that is flexible and allows
any-order scripting. Previous versions had a hard template execution order and
instructions were spread across multiple files. The new syntax is done in a
``Bastillefile`` and the template hook (see below) files are replaced with
template hook commands.

Note: Old stlyle templates are no longer supported. Please convert any templates
you may have with ``rocinante convert TEMPLATE``.

Template Automation Hooks
-------------------------

+---------------+---------------------+-----------------------------------------+
| HOOK          | format              | example                                 |
+===============+=====================+=========================================+
| ARG           | ARG=VALUE           | MINECRAFT_MEMX="1024M"                  |
+---------------+---------------------+-----------------------------------------+
| CMD           | /bin/sh command     | /usr/bin/chsh -s /usr/local/bin/zsh     |
+---------------+---------------------+-----------------------------------------+
| CP            | path(s)             | etc root usr (one per line)             |
+---------------+---------------------+-----------------------------------------+
| INCLUDE       | template / URL      | http?://TEMPLATE_URL or project/path    |
+---------------+---------------------+-----------------------------------------+
| LIMITS        | resource value      | memoryuse 1G                            |
+---------------+---------------------+-----------------------------------------+
| LINE_IN_FILE  | line file_path      | word /usr/local/word/word.conf          |
+---------------+---------------------+-----------------------------------------+
| PKG           | port/pkg name(s)    | vim-console zsh git-lite tree htop      |
+---------------+---------------------+-----------------------------------------+
| RENDER        | /path/file.txt      | /usr/local/etc/gitea/conf/app.ini       |
+---------------+---------------------+-----------------------------------------+
| SERVICE       | service command     | 'nginx start' OR 'postfix reload'       |
+---------------+---------------------+-----------------------------------------+
| SYSCTL        | sysctl command(s)   |                                         |
+---------------+---------------------+-----------------------------------------+
| SYSRC         | sysrc command(s)    |                                         |
+---------------+---------------------+-----------------------------------------+
| UPDATE        | update arg(s)       |                                         |
+---------------+---------------------+-----------------------------------------+
| UPGRADE       | RELEASE_NAME        | 14.3-RELEASE                            |
+---------------+---------------------+-----------------------------------------+
| ZFS           | zfs command(s)      | zfs create zroot/tank                   |
+---------------+---------------------+-----------------------------------------+
| ZPOOL         | zpool command(s)    |                                         |
+---------------+---------------------+-----------------------------------------+

Template Hook Descriptions
--------------------------

``ARG``       - set an ARG value to be used in the template

ARGS will default to the value set inside the template, but can be changed by
including ``--arg ARG=VALUE`` when running the template.

Multiple ARGS can also be specified as seen below. If no ARG value is given, Rocinante
will show a warning, but continue on with the rest of the template.

.. code-block:: shell

  ishmael ~ # rocinante template sample/template --arg ARG=VALUE --arg ARG1=VALUE

The ``ARG`` hook has a wide range of functionality, including passing KEY=VALUE pairs
to any templates called with the ``INCLUDE`` hook. See the following example...

.. code-block:: shell

  ARG VALUE1
  ARG VALUE2

  INCLUDE other/template --arg VALUE1=${VALUE1} --arg VALUE2=${VALUE2}

If the above template is called with ``--arg VALUE1=VALUE1 --arg VALUE2=VALUE2``, these values will
be passed along to ``other/template`` as well, with the matching variable. So ``${VALUE1}`` will be
``VALUE1`` and ``${VALUE2}`` will be ``VALUE2``.

``CMD``           - run the specified command

``CP``            - copy/overlay specified files from template directory to specified path

``INCLUDE``       - specify a template to include. Make sure the template is
bootstrapped, or you are using the template url

``LIMITS``        - set the specified resource value

``LINE_IN_FILE``  - add specified word to specified file if not present

``PKG``           - install specified packages

``RENDER``        - replace ARG values inside specified files. If a
directory is specified, ARGS will be replaced in all files underneath

``SERVICE``       - run ``service`` with the specified arguments

``SYSCTL``        - run ``sysrc`` with the specified args

``SYSRC``         - run ``sysrc`` with the specified args

``UPDATE``        - run ``freebsd-update`` with the specified args

``UPGRADE``       - upgrade the system to the specified release

``ZFS``           - run ``zfs`` with the specified args

``ZPOOL``         - run ``zpool`` with the specified args

Special Hook Cases
------------------

ARG will always treat an ampersand "\``&``" literally, without the need to
escape it. Escaping it will cause errors.

Bootstrapping Templates
-----------------------

The official templates for Rocinante are all on Github, and mirror the directory 
structure of the ports tree.  So, ``nginx`` is in the ``www`` directory in the
templates, just like it is in the FreeBSD ports tree.  To bootstrap the
entire set of official predefined templates run the following command:

.. code-block:: shell

   rocinante bootstrap https://github.com/bastillebsd/templates

This will install all official templates into the templates directory at
``/usr/local/rocinante/templates``. You can then use the ``rocinante template``
command to apply any of the templates.

.. code-block:: shell

   rocinante template www/nginx

Creating Templates
------------------

Templates can be created and placed inside the templates directory in the
``project/template`` format. Alternatively you can run the ``rocinante template``
command from a relative path, making sure it is still in the above format.

Place these uppercase template hook commands into a ``Bastillefile`` in any
order and to automate setup.

In addition to supporting template hooks, Rocinante supports overlaying files
from the template to the host. This is done by placing the files in their full path, using
the template directory as "/".

An example here may help. Think of ``rocinante/templates/username/template``, our
example template, as the root of our filesystem overlay. If you create an
``/etc/hosts`` or ``/etc/resolv.conf`` *inside* the template directory, these
can be overlayed/copied to the host system.

Note: due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in ``/usr/local``. The few general exceptions
are the ``/etc/hosts``, ``/etc/resolv.conf``, and ``/etc/rc.conf.local``.

After populating ``/usr/local`` with custom config files that your host
will use, be sure to include ``/usr`` in the template ``CP`` definition. eg;

.. code-block:: shell

  echo "CP /usr /" >> /usr/local/rocinante/templates/username/template/Bastillefile

The above example ``/usr`` will include anything under ``/usr`` inside the
template.
You do not need to list individual files. Just include the top-level directory
name. List these top-level directories one per line.

Applying Templates
------------------

Rocinante includes a ``template`` command. This command requires a
template name. As covered in the previous section, template names correspond to
directory names in the ``rocinante/templates`` directory.

.. code-block:: shell

  ishmael ~ # rocinante template username/template
  Copying files...
  Copy complete.
  Installing packages.
  pkg already bootstrapped at /usr/local/sbin/pkg
  vulnxml file up-to-date
  0 problem(s) in the installed packages found.
  [cdn] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [cdn] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  All repositories are up to date.
  Checking integrity... done (0 conflicting)
  The most recent version of packages are already installed
  Updating services.
  cron_flags: -J 60 -> -J 60
  sendmail_enable: NONE -> NONE
  syslogd_flags: -ss -> -ss
  Executing final command(s).
  chsh: user information updated
  Template Complete.

Using Ports in Templates
------------------------

Sometimes when you make a template you need special options for a package, or
you need a newer version than what is in the pkgs.  The solution for these
cases, or a case like minecraft server that has NO compiled option, is to use
the ports.  A working example of this is the minecraft server template in the
template repo. Below is an example of the minecraft template where this was used.

.. code-block:: shell

  ARG MINECRAFT_MEMX="1024M"
  ARG MINECRAFT_MEMS="1024M"
  ARG MINECRAFT_ARGS=""
  PKG dialog4ports tmux openjdk17
  CP etc /
  CP var /
  CMD make -C /usr/ports/games/minecraft-server install clean
  CP usr /
  SYSRC minecraft_enable=YES
  SYSRC minecraft_memx=${MINECRAFT_MEMX}
  SYSRC minecraft_mems=${MINECRAFT_MEMS}
  SYSRC minecraft_args=${MINECRAFT_ARGS}
  SERVICE minecraft restart

The CMD make line makes the
port. This can be modified to use any port in the port tree.
