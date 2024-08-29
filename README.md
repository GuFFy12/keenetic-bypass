## Установка и настройка обхода блокировок с использованием Zapret + Dnsmasq

### Требования:
- Keenetic OS версии 4.0 или выше
- Установленный Entware

### Шаги установки:

1. **Установка необходимых пакетов через Entware:**

    ```bash
    opkg install coreutils-sort curl git-http grep gzip ipset iptables kmod_ndms xtables-addons_legacy dnsmasq
    ```

2. **Настройка Keenetic:**

    - **Socks-прокси:** Включите и настройте Socks-прокси в веб-интерфейсе Keenetic.
    - **HTTP DNS:** Настройте кастомный HTTP DNS сервер.
    - **Подзаписи DNS:** Создайте подзаписи DNS на адресе `192.168.1.1:5300` для доменов, доступ к которым блокируется без использования прокси.

3. **Установка скриптов и конфигурационных файлов:**

    - Скачайте Zapret:

      ```bash
      cd /opt/
      git clone --depth=1 https://github.com/bol-van/zapret.git
      ```

    - Скопируйте все файлы из репозитория в корень `/opt` с заменой существующих (руками или через ftp / webui).
    - Если symlink в init.d сломаны, удалите их и создайте заново:

      ```bash
      ln -s /opt/zapret/init.d/sysv/zapret /opt/etc/init.d/S52zapret
      ln -s /opt/etc/dnsmasq_routing.sh /opt/etc/init.d/S53dnsmasq_routing
      ```

   - Выполните первоначальную настройку:

     ```bash
     cd /opt/zapret/
     sh install_easy.sh
     ```

### Настройка конфигурационных файлов:

1. **Конфигурация zapret:**

    - Откройте и отредактируйте файл конфигурации `zapret` используя readme оригинального репозитория.
    - Установите переменную `IFACE_WAN` на интерфейс `wan`, который использует внешний IP-адрес. Чтобы получить его, выполните команду:

      ```bash
      ip addr
      ```

    - Если в `NFQWS_OPT_DESYNC_QUIC` используется что то помимо `fake`, например, `split`, раскомментируйте строки:

      ```bash
      # INIT_FW_PRE_UP_HOOK
      # INIT_FW_POST_DOWN_HOOK
      ```

    - Рекомендуется также ознакомиться с комментариями внутри этих файлов для корректной настройки.

2. **Конфигурация dnsmasq:**

    - В графе `server` укажите ваш внутренний HTTP DNS. Чтобы получить его, выполните команду:

      ```bash
      cat /tmp/ndnproxymain.stat
      ```

3. **Конфигурация dnsmasq_routing:**

    - `KILL_SWITCH` - если установлено в `1`, то при отключении VPN или прокси, трафик не пойдет в сеть.

    - Выберите нужный интерфейс и подсеть VPN или прокси. Для этого используйте команду:

      ```bash
      ip addr
      ```

### Дополнительные настройки:

- Обратите внимание на другие возможные настройки в конфигурационных файлах, которые могут понадобиться для специфичных сценариев.
