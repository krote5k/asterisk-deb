Установка сборки пакетов Asterisk для Ubuntu
============================================

Если у вас нет пакетов ``*.deb`` или репозитория, в котором они
размещены, то *пожалуйста, сначала обратитесь к README.rst*.

Установка Asterisk из пользовательского пакета Debian должна быть
примерно такой же простой, как обычная установка Asterisk из пакетов Debian.

Если вы используете репозиторий для размещения файлов ``*.deb``,
``apt-get install`` для пакета ``asterisk`` должна предоставить вам эти установленные модули::


    ii  asterisk                       1:11.20.0-osso0~jessie
    ii  asterisk-config                1:11.20.0-osso0~jessie
    ii  asterisk-core-sounds-en        1.4.22-1
    ii  asterisk-core-sounds-en-gsm    1.4.22-1
    ii  asterisk-modules               1:11.20.0-osso0~jessie
    ii  asterisk-moh-opsound-gsm       2.03-1
    ii  asterisk-voicemail             1:11.20.0-osso0~jessie

(Версии могут различаться.)



Создание начальной конфигурации
-------------------------------

Normally, ``/etc/asterisk`` would be populated with lots of example
config files. In this build, it is not.

Instead, you'll have to compile the list of files you need yourself.
You can find lots of useful examples in ``/usr/share/asterisk/conf``.

For starters, you'll do this:

.. code-block:: console

    $ sudo sh -c 'cat >/etc/asterisk/logger.conf' << EOF
    [logfiles]
    console => debug,verbose,notice,warning,error
    debug_log => debug,verbose,notice,warning,error
    ;dtmf_log => dtmf,debug,verbose
    messages_log = notice,warning,error
    syslog.local0 => warning,error
    EOF

Now you can start Asterisk in the foreground. Do it, while copying
and editing config files until you run out of ERRORs and WARNINGs.

For example:

.. code-block:: console

    $ sudo asterisk -c
    ...
    [Oct 27 14:12:44] ERROR[31346]: config_options.c:531 aco_process_config: Unable to load config file 'acl.conf'
    ^C

    $ sudo cp /usr/share/asterisk/conf/acl.conf.sample /etc/asterisk/acl.conf
    $ #vi /etc/asterisk/acl.conf  # and remove everything that you don't use

Also, it's possible to exclude the module if you know you're not going to need
it. Apart from the excluded CDR modules below, it's highly likely that you're
not going to need any of these modules.

(As for the CDR modules: if you can use CEL instead, it's better in the long
run.)

.. code-block:: console

    $ sudo sh -c 'cat > /etc/asterisk/modules.conf' << EOF
    [modules]
    autoload=yes

    preload => res_fax.so
    preload => res_odbc.so

    noload => app_amd.so
    noload => app_festival.so
    noload => app_followme.so
    noload => app_minivm.so
    noload => app_speech_utils.so

    noload => chan_agent.so
    noload => chan_alsa.so
    noload => chan_console.so
    noload => chan_iax2.so
    noload => chan_mgcp.so
    noload => chan_motif.so
    noload => chan_oss.so
    noload => chan_phone.so
    noload => chan_skinny.so
    noload => chan_unistim.so

    noload => cdr_adaptive_odbc.so
    noload => cdr_csv.so
    noload => cdr_custom.so
    noload => cdr_manager.so
    noload => cdr_odbc.so
    noload => cdr_pgsql.so
    noload => cdr_radius.so
    noload => cdr_sqlite3_custom.so
    noload => cdr_syslog.so
    noload => cdr_tds.so

    noload => pbx_ael.so
    noload => pbx_dundi.so
    noload => pbx_lua.so
    noload => pbx_realtime.so

    noload => res_adsi.so
    noload => res_ael_share.so
    noload => res_agi.so
    noload => res_calendar_caldav.so
    noload => res_calendar_ews.so
    noload => res_calendar_exchange.so
    noload => res_calendar_icalendar.so
    noload => res_calendar.so
    noload => res_clialiases.so
    noload => res_config_ldap.so
    noload => res_config_pgsql.so
    noload => res_config_sqlite3.so
    noload => res_config_sqlite.so
    noload => res_corosync.so
    noload => res_mutestream.so
    noload => res_phoneprov.so
    noload => res_realtime.so
    noload => res_smdi.so
    noload => res_snmp.so
    noload => res_speech.so
    noload => res_xmpp.so
    EOF

Or, you could disable autoload with ``autoload=no`` and only load those modules
that you need.

When ``asterisk -c`` starts without warnings and errors, you can configure it
as system daemon. See the next section.



Using SysV init
---------------

A wrapper called ``safe_asterisk`` is included that starts Asterisk and
restarts it if it stops for whatever reason. Use it together with core
dump support and crash mailings, like this:

.. code-block:: console

    $ sudo sed -i -e 's/^#\(RUNASTSAFE=yes\)/\1/' /etc/default/asterisk
    $ sudo sed -i -e 's/^#\(AST_DUMPCORE=yes\)/\1/' /etc/default/asterisk
    $ sudo sh -c 'cat > /etc/sysctl.d/core_pattern.conf' << EOF
    kernel.core_pattern = core.%p
    EOF
    $ sudo sysctl -p /etc/sysctl.d/core_pattern.conf

Now restart Asterisk and confirm that it's up and running:

.. code-block:: console

    $ sudo service asterisk restart
    Stopping Asterisk PBX: asterisk.
    Starting Asterisk PBX: asterisk.
    $ ps fax
    ...
    25979 ?        S      0:00 /bin/sh /usr/sbin/safe_asterisk -p -g -U asterisk
    25993 ?        Sl     0:01  \_ /usr/sbin/asterisk -f -p -g -U asterisk -vvvg -c
    25994 ?        S      0:00      \_ astcanary /var/run/alt.asterisk.canary.tweet.tweet.tweet 25993

For bonus points, take ``examples/safe_asterisk/startup.d--mail-backtrace.sh``
and add it to startup.d:

.. code-block:: console

    $ cd /etc/asterisk/startup.d
    $ sudo wget https://raw.githubusercontent.com/ossobv/asterisk-deb/11-jessie/examples/safe_asterisk/startup.d--mail-backtrace.sh \
        -O mail-backtrace.sh

Note that new files in ``/etc/asterisk/startup.d`` require a full daemon restart
to get picked up.

Подключение к Asterisk
----------------------

Вы можете подключиться к локально запущенному экземпляру Asterisk с помощью
``asterisk -r``. Введите ``core show help``, чтобы получить дополнительную информацию.

В Интернете полно информации о том, как правильно настроить Asterisk.

Вы, вероятно, потратите большую часть своего времени на редактирование в ``sip.conf``
(или более новой версии pjsip, если вы используете Asterisk 13 или новее) и ``extensions.conf``.

Удачи!



/Walter Doekes <wjdoekes+asterisk-deb@osso.nl>  Tue, 27 Oct 2015 15:15:54 +0100
