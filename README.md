# Установка и настройка обхода блокировок с использованием Zapret и Dnsmasq-based static routing

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005) версии 4.0 или выше.
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Установка необходимых компонентов

- Выполните следующую команду:
  ```sh
  curl -s https://raw.githubusercontent.com/GuFFy12/keenetic-bypass/refs/heads/main/install.sh | sh
  ```

## Настройка конфигурационных файлов

### 1. Конфигурация Zapret

- Файл `/opt/zapret/config` уже настроен. Подгоните его под свои нужды с учетом оригинальной
  документации [zapret](https://github.com/bol-van/zapret).
- Переменная `IFACE_WAN` установлена автоматически на дефолтный интерфейс `wan`, который использует внешний IP-адрес.
  Чтобы вручную узнать его, выполните команду:
  ```sh
  ip addr
  ```
- Опционально обновите списки доменов `/opt/zapret/ipset/zapret-hosts-user.txt` и выполните команду:
  ```sh
  /opt/zapret/ipset/get_config.sh
  ```

### 2. Настройки в веб-панели Keenetic

- Настройте и включите туннель [VPN](https://help.keenetic.com/hc/ru/articles/115005342025)
  или [Proxy](https://help.keenetic.com/hc/ru/articles/7474374790300).
- Настройте пользовательский [DNS-over-HTTPS](https://help.keenetic.com/hc/ru/articles/360007687159).
- Создайте записи DNS на адресе `127.0.0.1:5300` для доменов, к которым нужен доступ через туннель.
- Пример списка доменов:
  ```
  chatgpt.com
  openai.com
  oaiusercontent.com
  github.com
  githubusercontent.com
  ```

### 3. Конфигурация Dnsmasq

- Файл `/opt/dnsmasq_routing/dnsmasq.conf` уже настроен. Подгоните его под свои нужды с учетом оригинальной
  документации [dnsmasq](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).
- Переменная `server` установлена автоматически на первый найденный `127.0.0.1:port`, который используется для получения DNS записей.
  Чтобы вручную узнать его, выполните команду:
  ```sh
  cat /tmp/ndnproxymain.stat
  ```

### 4. Конфигурация Dnsmasq Routing

- Когда устройство отправляет запрос на получение IP-адреса по доменному имени, запрос поступает на маршрутизатор.
  Маршрутизатор использует dnsmasq для обработки запроса и возвращает IP-адрес, одновременно добавляя этот IP-адрес в набор ipset.
  Все IP-адреса, которые входят в указанный набор ipset, перенаправляются через интерфейс туннеля.
  Для корректной работы этой системы критически важно, чтобы все DNS-запросы направлялись через маршрутизатор,
  а не обрабатывались непосредственно устройством.
- Файл `/opt/dnsmasq_routing/dnsmasq_routing.conf` уже настроен. Подгоните его под свои нужды.
- Переменные `INTERFACE` и `INTERFACE_SUBNET` установлены автоматически на первый найденный туннель в системе если он есть.
  Чтобы вручную узнать параметры туннеля выполните команду:
  ```sh
  ip addr
  ```
- Опционально настройте следующие переменные:
  - `KILL_SWITCH` - если установлено в `1`, при отключении VPN или прокси трафик не будет направляться в сеть.
  - `IPSET_TABLE_SAVE` - если установлено в `1`, таблица с IP-адресами будет сохранена при перезагрузке.
  - `IPSET_TABLE` - имя таблицы ipset.
  - `IPSET_TABLE_TIMEOUT` - тайм-аут для записей в таблице (`0` для неограниченного времени).
  - `INTERFACE` - интерфейс выходного узла туннеля.
  - `INTERFACE_SUBNET` - подсеть интерфейса выходного узла туннеля.
  - `MARK` - маркер, используемый в iptables.

## Запуск скриптов

- При перезагрузке маршрутизатора скрипты запускаться автоматически. Однако, если вы не хотите перезагружать его,
  выполните следующие команды:
  - Для запуска Zapret:
    ```sh
    /opt/zapret/init.d/sysv/zapret_keenetic.sh restart
    ```
  - Для запуска Dnsmasq Routing:
    ```sh
      /opt/dnsmasq_routing/dnsmasq_routing.sh restart
    ```

## Настройка WireGuard на роутере в качестве сервера для обхода блокировок

- Подробности: [WireGuard VPN](https://help.keenetic.com/hc/ru/articles/360010592379).
