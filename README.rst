OSSO сборка пакетов Asterisk для Debian
==========================================

Содержит каталог ``debian/`` необходимый для создания пакета Debian (или Ubuntu)
конкретных версий `Asterisk PBX <http://www.asterisk.org/>`_.

Поместите в каталог debian распакованный архив Asterisk и создайте необходимые файлы ``*.deb``. Смотрите подробные инструкции ниже.

Большое спасибо команде Debian за создание исходных файлов и обмен ими! Отправная точка для этого каталога ``debian/`` взята из `репозитория Debian AnonSCM <http://anonscm.debian.org/cgit/pkg-voip/asterisk.git>`_.

Если вы довольны этими файлами без каких-либо дополнительных изменений, то можете получить предварительно скомпилированные бинарные пакеты непосредственно из *OSSO ppa*. См.раздел `Использование OSSO ppa <#user-content-using-the-osso-ppa>`_.

Building with Docker
--------------------

.. code-block:: console

    $ ./build.sh
    ...

    $ find ./dist
    ...
    ./dist/jessie/asterisk_11.25.3-0osso1+deb8/asterisk_11.25.3-0osso1+deb8_amd64.changes
    ./dist/jessie/asterisk_11.25.3-0osso1+deb8/asterisk_11.25.3-0osso1+deb8_amd64.deb
    ...

That should be enough to get the debian packages. For verbose building,
see below:



Setting up a build environment
------------------------------

Installing build prerequisites:

.. code-block:: console

    # apt-get install debhelper dpkg-dev quilt build-essential

Installing build dependencies (11-jessie):

.. code-block:: console

    # apt-get install libncurses5-dev libjansson-dev libxml2-dev \
        libsqlite3-dev libreadline-dev unixodbc-dev libmysqlclient-dev
    # apt-get install corosync-dev dahdi-source libcurl4-openssl-dev \
        libgsm1-dev libtonezone-dev libasound2-dev libpq-dev \
        libbluetooth-dev autoconf libnewt-dev libsqlite0-dev \
        libspeex-dev libspeexdsp-dev libpopt-dev libiksemel-dev \
        freetds-dev libvorbis-dev libsnmp-dev libc-client2007e-dev \
        libgmime-2.6-dev libjack-dev libcap-dev libopenr2-dev \
        libresample1-dev libneon27-dev libical-dev libsrtp0-dev \
        libedit-dev
    # apt-get install libpjproject-dev

Ensure that you have a sane ``.quiltrc`` so you can test the quilt patches.

.. code-block:: console

    $ cat >~/.quiltrc <<EOF
    QUILT_PATCHES=debian/patches
    QUILT_NO_DIFF_INDEX=1
    QUILT_NO_DIFF_TIMESTAMPS=1
    QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
    QUILT_DIFF_OPTS="--show-c-function"
    EOF



Preparing an Asterisk build
---------------------------

Fetching the latest Asterisk, creating a local scratchpad repository and
moving the ``debian/`` dir to the untarred Asterisk source.

.. code-block:: console

    $ VERSION=11.20.0
    $ wget "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${VERSION}.tar.gz" \
        -O "asterisk_${VERSION}.orig.tar.gz"
    $ tar zxf "asterisk_${VERSION}.orig.tar.gz"

    $ cd asterisk-${VERSION}
    $ git init
    $ git add -fA   # adds all files, even the .gitignored ones
    $ git commit -m "clean ${VERSION}"

    $ cp -a ~/asterisk-deb/debian debian  # or use a bind-mount

Test that all patches apply:

.. code-block:: console

    $ quilt push -a

Refreshing the quilt patches (optional). By altering the ``'Now at patch'``
needle you can refresh from a certain patch (your own?) and onwards.

.. code-block:: console

     $ quilt pop -a; \
         until quilt push | grep 'Now at patch'; do true; done; \
         quilt pop; while quilt push; do quilt refresh; done



Compiling the Asterisk packages
-------------------------------

After preparing the build, there is nothing more to do except run
``dpkg-buildpackage`` and wait.

Before this step, you can add/edit your own patches. See
`Quilting and patching_` below.
Don't forget to update the ``changelog`` if you change anything.

.. code-block:: console

    $ #vim debian/changelog
    $ DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc

If you want to build locally to test, instead of building a package, you'll do
this:

.. code-block:: console

    quilt push -a
    ./bootstrap.sh
    ./configure --prefix=/usr/ --mandir=\${prefix}/share/man \
        --infodir=\${prefix}/share/info --disable-asteriskssl --with-gsm \
        --with-imap=system --without-pwlib --enable-dev-mode
    make menuconfig
    make
    sudo make install



Quilting and patching
---------------------

If you want to add/change source, you can append to the Debian quilt patches.

You'll want to test this on a locally compiled build, without packaging it
for every change. Set up your build like this:

.. code-block:: console

    $ git clone https://github.com/asterisk/asterisk
    $ # or: http://gerrit.asterisk.org/asterisk
    $ cd asterisk
    $ git fetch --all   # make sure we also fetch all tags
    $ cp -a ~/asterisk-deb/debian debian  # or use a bind-mount

Select the version. Depending on what you previously did, you'll need only some
of these. Consult your local source of git knowledge for more information.

.. code-block:: console

    $ git reset         # unstages staged changes
    $ git checkout .    # drops all changes
    $ git clean -fdxe debian   # drop all untracked files except 'debian/'

    $ VERSION=11.20.0
    $ git checkout -b local-${VERSION} ${VERSION}   # branch tag 11.20.0 onto local-11.20.0

First, you have to patch all of the Debian/OSSO changes. Commit the quilted
stuff so it's not in the way when you start editing.

.. code-block:: console

    $ quilt push -a
    $ git commit -m "WIP: asterisk-deb quilted"

Now you can start changing stuff, compiling, installing. Et cetera.

.. code-block:: console

    $ ./bootstrap.sh
    $ ./configure --enable-dev-mode
    $ make menuconfig

    ... change stuff ...

    $ make && sudo make install

When you're happy with the result, you write the changes to a Debian patch file:

.. code-block:: console

    $ git diff > debian/patches/my-awesome-changes.patch
    $ echo my-awesome-changes.patch >> debian/patches/series
    $ git checkout .    # drop the local changes
    $ quilt push        # reapply the changes, using quilt

For bonus points, you'll edit your newly generated ``debian/patches/my-awesome-changes.patch``
and add appropriate header values as described in
`DEP3, Patch Tagging Guidelines <http://dep.debian.net/deps/dep3/>`_.

Store your updated patches in your own repository, and rebase your changes
against changes in ``asterisk-deb``.



Known problems
--------------

After quilting or a failed build, you may run into this::

    make[1]: Entering directory '/home/osso/asterisk/asterisk-11.25.1'
    if [ ! -r configure.debian_sav ]; then cp -a configure configure.debian_sav; fi
    cp: cannot stat 'configure': No such file or directory
    debian/rules:76: recipe for target 'override_dh_autoreconf' failed
    make[1]: *** [override_dh_autoreconf] Error 1

That is fixed either by forcing configure to be back in place, or simply by
using a pristine Asterisk source directory.



Installing and configuring
--------------------------

See ``INSTALL.rst`` in this directory for tips on how to install it.



Using the OSSO ppa
------------------

If you're happy with these files without any additional changes,
you can fetch precompiled binary packages from the OSSO ppa if you like.

USE IT AT YOUR OWN RISK. OSSO DOES NOT GUARANTEE AVAILABILITY OF THE SERVER.
OSSO DOES NOT GUARANTEE THAT THE FILES ARE SANE.

.. code-block:: console

    $ sudo sh -c 'cat >/etc/apt/sources.list.d/osso-ppa-osso.list' <<EOF
    deb http://ppa.osso.nl/debian jessie osso
    deb-src http://ppa.osso.nl/debian jessie osso
    EOF
    $ wget -qO- https://ppa.osso.nl/support+ppa@osso.nl.gpg | sudo apt-key add -
    $ sudo tee /etc/apt/preferences.d/asterisk >/dev/null << EOF
    Package: asterisk asterisk-*
    Pin: release o=OSSO ppa
    Pin-Priority: 600
    EOF
    $ sudo apt-get update
    $ sudo apt-get install asterisk


/Walter Doekes <wjdoekes+asterisk-deb@osso.nl>  Tue, 11 Oct 2016 14:07:55 +0200
