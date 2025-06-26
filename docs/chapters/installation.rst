Installation
============
Rocinante is available in the official FreeBSD ports tree at
``sysutils/rocinante``. Binary packages are available in quarterly and latest
repositories.

Current version is ``1.0.20250714``.

To install from the FreeBSD package repository:

* quarterly repository may be older version
* latest repository will match recent ports


pkg
---

.. code-block:: shell

  pkg install rocinante

To install from source (don't worry, no compiling):

ports
-----

.. code-block:: shell

  make -C /usr/ports/sysutils/rocinante install clean

git
---

.. code-block:: shell

  git clone https://github.com/BastilleBSD/rocinante.git
  cd rocinante
  make install

This method will install the latest files from GitHub directly onto your
system. It is verbose about the files it installs (for later removal), and also
has a ``make uninstall`` target

Note: installing using this method overwrites the version variable to match
that of the source revision commit hash.
