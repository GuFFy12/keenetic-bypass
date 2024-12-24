<div align="center">

# Keenetic Bypass

<img src="https://github.com/user-attachments/assets/66087228-edfa-4957-82db-5bd7233f8ab9" alt="logo" width="50%" />
</div>

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005) версии 4.0 или выше.
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Установка необходимых компонентов

- Выполните следующую команду:
  ```sh
  curl -s https://raw.githubusercontent.com/GuFFy12/keenetic-bypass/refs/heads/main/install.sh | sh
  ```

### 2. Конфигурация Zapret ([`/opt/zapret/config`](https://github.com/bol-van/zapret))

- Переменная `IFACE_WAN` установлена автоматически на дефолтный интерфейс `wan`, который использует внешний IP-адрес.
  Чтобы вручную узнать его, выполните команду:
  ```sh
  ip addr
  ```
- Опционально обновите списки доменов `/opt/zapret/ipset/zapret-hosts-user.txt` и выполните команду:
  ```sh
  /opt/zapret/ipset/get_config.sh
  ```

### 3. Настройки в веб-панели Keenetic

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

### 4. Конфигурация Dnsmasq ([`/opt/dnsmasq_routing/dnsmasq.conf`](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html))

- Переменная `server` установлена автоматически на первый найденный `127.0.0.1:port`, который используется для получения DNS записей.
  Чтобы вручную узнать его, выполните команду:
  ```sh
  cat /tmp/ndnproxymain.stat
  ```

### 5. Конфигурация Dnsmasq Routing (`/opt/dnsmasq_routing/dnsmasq_routing.conf`)

- Устройство отправляет DNS-запрос на маршрутизатор, который с помощью dnsmasq возвращает IP-адрес и добавляет его в ipset.
  Все IP-адреса из ipset перенаправляются через туннель. Для работы системы важно, чтобы все DNS-запросы шли через маршрутизатор.
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

## Настройка WireGuard на роутере в качестве сервера для обхода блокировок

- Подробности: [WireGuard VPN](https://help.keenetic.com/hc/ru/articles/360010592379).
