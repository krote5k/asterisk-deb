OSSO сборка пакетов Asterisk для Debian
==========================================

Содержит каталог ``debian/`` необходимый для создания пакета Debian (или Ubuntu) конкретных версий `Asterisk PBX <http://www.asterisk.org/>`_.

Поместите в каталог debian распакованный архив Asterisk и создайте необходимые файлы ``*.deb``. Смотрите подробные инструкции ниже.

Большое спасибо команде Debian за создание исходных файлов и обмен ими! Отправная точка для этого каталога ``debian/`` взята из `репозитория Debian AnonSCM <http://anonscm.debian.org/cgit/pkg-voip/asterisk.git>`_.

Если вы довольны этими файлами без каких-либо дополнительных изменений, то можете получить предварительно скомпилированные бинарные пакеты непосредственно из *OSSO ppa*. См.раздел `Использование OSSO ppa <#user-content-using-the-osso-ppa>`_.

Сборка в Docker
--------------------

.. code-block:: console

    $ ./build.sh
    ...

    $ find ./dist
    ...
    ./dist/jessie/asterisk_11.25.3-0osso1+deb8/asterisk_11.25.3-0osso1+deb8_amd64.changes
    ./dist/jessie/asterisk_11.25.3-0osso1+deb8/asterisk_11.25.3-0osso1+deb8_amd64.deb
    ...

Этого должно быть достаточно, чтобы получить пакеты debian. Для подробной
сборки см. ниже:

Настройка среды сборки
------------------------------

Установка предварительных условий сборки:

.. code-block:: console

    # apt-get install debhelper dpkg-dev quilt build-essential

Установка зависимостей сборки (11-Джесси ??):

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

Убедитесь, что у вас есть нормальный ```.quiltrc``, чтобы вы могли протестировать патчи для quilt.

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

Извлечение последней версии Asterisk, создание локального репозитория scratchpad
и перемещение каталога ``debian/`` в незапятнанный источник Asterisk.

.. code-block:: console

    $ VERSION=16.17.0
    $ wget "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${VERSION}.tar.gz" \
        -O "asterisk_${VERSION}.orig.tar.gz"
    $ tar zxf "asterisk_${VERSION}.orig.tar.gz"

    $ cd asterisk-${VERSION}
    $ git init
    $ git add -fA   # adds all files, even the .gitignored ones
    $ git commit -m "clean ${VERSION}"

    $ cp -a ~/asterisk-deb/debian debian  # or use a bind-mount

Проверка что применяются все патчи:

.. code-block:: console

    $ quilt push -a

Обновление патчей quilt (необязательно). Альтернативно  ``'Now at patch'``,
вы можете обновить ее с определенного патча (вашего собственного?) и далее.

.. code-block:: console

     $ quilt pop -a; \
         until quilt push | grep 'Now at patch'; do true; done; \
         quilt pop; while quilt push; do quilt refresh; done



Компиляция пакетов Asterisk
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



Quilting и патчинг
---------------------

Если вы хотите добавить/изменить источник, вы можете добавить патчи Debian quilt.

Вы должны протестировать это на локально скомпилированной сборке, не упаковывая
ее для каждого изменения. Настройте свою сборку следующим образом:

.. code-block:: console

    $ git clone https://github.com/asterisk/asterisk
    $ # or: http://gerrit.asterisk.org/asterisk
    $ cd asterisk
    $ git fetch --all   # make sure we also fetch all tags
    $ cp -a ~/asterisk-deb/debian debian  # or use a bind-mount

Выберите версию. В зависимости от того, что вы делали ранее, вам понадобятся
только некоторые из них. Для получения дополнительной информации обратитесь
к местному источнику знаний git.

.. code-block:: console

    $ git reset         # unstages staged changes
    $ git checkout .    # drops all changes
    $ git clean -fdxe debian   # drop all untracked files except 'debian/'

    $ VERSION=16.17.0
    $ git checkout -b local-${VERSION} ${VERSION}   # branch tag 11.20.0 onto local-11.20.0

Во-первых, вы должны исправить все изменения Debian/OSSO. Зафиксируйте
quilted вещи, чтобы они не мешали, когда вы начнете редактировать.

.. code-block:: console

    $ quilt push -a
    $ git commit -m "WIP: asterisk-deb quilted"

Теперь вы можете начать изменять материал, компилировать, устанавливать. И так далее.

.. code-block:: console

    $ ./bootstrap.sh
    $ ./configure --enable-dev-mode
    $ make menuconfig

    ... change stuff ...

    $ make && sudo make install

Когда вы довольны результатом, то записываем изменения в патч-файл Debian:

.. code-block:: console

    $ git diff > debian/patches/my-awesome-changes.patch
    $ echo my-awesome-changes.patch >> debian/patches/series
    $ git checkout .    # drop the local changes
    $ quilt push        # reapply the changes, using quilt

Для получения бонусных баллов вы отредактируете недавно сгенерированный
``debian/patches/my-awesome-changes.patch`` и добавьте соответствующие значения заголовка,
как описано в `Руководстве по тегированию исправлений DEP3 <http://dep.debian.net/deps/dep3/>`_.

Храните обновленные патчи в своем собственном репозитории и перебазируйте
изменения в соответствии с изменениями в ``asterisk-deb``.


Известные проблемы
------------------

После квилтинга или неудачной сборки вы можете столкнуться с этим::

    make[1]: Entering directory '/home/osso/asterisk/asterisk-11.25.1'
    if [ ! -r configure.debian_sav ]; then cp -a configure configure.debian_sav; fi
    cp: cannot stat 'configure': No such file or directory
    debian/rules:76: recipe for target 'override_dh_autoreconf' failed
    make[1]: *** [override_dh_autoreconf] Error 1

Это исправляется либо путем принудительного возвращения конфигурации на место,
либо просто с помощью нетронутого исходного каталога Asterisk.

Установка и конфигурирование
----------------------------

Смотри ``INSTALL.rst`` в этом каталоге для получения советов о том, как его установить.

Использование OSSO ppa
------------------

Если вы довольны этими файлами без каких-либо дополнительных изменений,
вы можете получить предварительно скомпилированные двоичные пакеты из OSSO ppa, если хотите.

ИСПОЛЬЗУЙТЕ ЕГО НА СВОЙ СТРАХ И РИСК. OSSO НЕ ГАРАНТИРУЕТ ДОСТУПНОСТЬ СЕРВЕРА.
OSSO НЕ ГАРАНТИРУЕТ, ЧТО ФАЙЛЫ ЯВЛЯЮТСЯ ВМЕНЯЕМЫМИ.

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
