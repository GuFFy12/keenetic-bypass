# Установка и настройка обхода блокировок с использованием Zapret и Dnsmasq-based static routing

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005) версии 4.0 или выше.
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Установка необходимых компонентов

Выполните поочередно следующие команды:

```bash
opkg update && opkg install coreutils-sort curl dnsmasq git-http grep gzip ipset iptables kmod_ndms xtables-addons_legacy
```

```bash
curl -L https://github.com/bol-van/zapret/releases/download/v69.6/zapret-v69.6.tar.gz | tar -xz -C /opt/ && mv /opt/zapret-v69.6/ /opt/zapret/
/opt/zapret/install_bin.sh
/opt/zapret/ipset/get_config.sh
```

```bash
git clone --depth=1 https://github.com/GuFFy12/keenetic-bypass.git /opt/tmp/keenetic-bypass/
find /opt/tmp/keenetic-bypass/opt/ -type f -exec sh -c 'dest="/opt/${1#/opt/tmp/keenetic-bypass/opt/}"; if [ -e "$dest" ]; then echo "File $dest already exists"; else mkdir -p "$(dirname "$dest")" && cp "$1" "$dest"; fi' _ {} \;
```

### 2. Настройки в веб-панели Keenetic

- Настройте и включите выходной узел [VPN](https://help.keenetic.com/hc/ru/articles/115005342025)
  или [Proxy](https://help.keenetic.com/hc/ru/articles/7474374790300).
- Настройте пользовательский [DNS-over-HTTPS](https://help.keenetic.com/hc/ru/articles/360007687159).
- Создайте записи DNS на адресе `192.168.1.1:5300` для доменов, доступ к которым блокируется без использования прокси.
- Пример списка доменов:
  ```
  chatgpt.com
  openai.com
  oaiusercontent.com
  github.com
  githubusercontent.com
  ```

## Настройка конфигурационных файлов

### 1. Конфигурация Zapret

- Файл `/opt/zapret/config` уже настроен. Подгоните его под свои нужды с учетом оригинальной
  документации [zapret](https://github.com/bol-van/zapret).
- Установите переменную `IFACE_WAN` на интерфейс `wan`, который использует внешний IP-адрес. Чтобы узнать его, выполните
  команду:
  ```bash
  ip addr
  ```
- Опционально обновите списки доменов `/opt/zapret/ipset/zapret-hosts.txt.gz`
  и `/opt/zapret/ipset/zapret-hosts-user.txt`.

### 2. Конфигурация Dnsmasq

- Файл `/opt/dnsmasq_routing/dnsmasq.conf` уже настроен. Подгоните его под свои нужды с учетом оригинальной
  документации [dnsmasq](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).
- Установите переменную `server` на `ip:port`, который использует ваш DNS-over-HTTPS. Чтобы его получить, выполните
  команду:
  ```bash
  cat /tmp/ndnproxymain.stat
  ```

### 3. Конфигурация Dnsmasq Routing

- Когда устройство отправляет запрос на получение IP-адреса по доменному имени, запрос поступает на маршрутизатор.
  Маршрутизатор использует dnsmasq для обработки запроса и возвращает IP-адрес, одновременно добавляя этот IP-адрес в
  набор ipset.
  Все IP-адреса, которые входят в указанный набор ipset, перенаправляются через интерфейс VPN или Proxy.
  Для корректной работы этой системы критически важно, чтобы все DNS-запросы направлялись через маршрутизатор, а не
  обрабатывались непосредственно устройством.

- Файл `/opt/dnsmasq_routing/dnsmasq_routing.conf` уже настроен. Подгоните его под свои нужды:
  - **KILL_SWITCH** - если установлено в `1`, при отключении VPN или прокси трафик не будет направляться в сеть.
  - **IPSET_TABLE_SAVE** - если установлено в `1`, таблица с IP-адресами будет сохранена при перезагрузке.
  - **IPSET_TABLE** - имя таблицы ipset.
  - **IPSET_TABLE_TIMEOUT** - тайм-аут для записей в таблице (`0` для неограниченного времени).
  - **INTERFACE** - интерфейс выходного узла VPN/Proxy (выполните `ip addr`).
  - **INTERFACE_SUBNET** - подсеть интерфейса выходного узла VPN/Proxy (выполните `ip addr`).
  - **MARK** - маркер, используемый в iptables.

## Запуск скриптов

При перезагрузке маршрутизатора скрипты запускаться автоматически. Однако, если вы хотите запустить их вручную,
выполните следующие команды:

- Для запуска Zapret:
  ```bash
  /opt/zapret/init.d/sysv/zapret_keenetic.sh restart
  ```
- Для запуска Dnsmasq Routing:
  ```bash
    /opt/dnsmasq_routing/dnsmasq_routing.sh restart
  ```

## Настройка WireGuard на роутере в качестве сервера для обхода блокировок из любой точки России

- Подробности: [WireGuard VPN](https://help.keenetic.com/hc/ru/articles/360010592379).
