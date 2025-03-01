# Keenetic Bypass

![logo](https://github.com/user-attachments/assets/66087228-edfa-4957-82db-5bd7233f8ab9)

## Замечания

- Этот код создан для изучения сетевых технологий. Он может быть полезен для улучшения работы интернета, но то, как вы его используете — ваш выбор.
  Автор ответственности не несет.

- Конфигурация zapret протестирована и работает стабильно. Со временем настройки могут стать не актуальными,
  проверяйте актуальные методы в репозитории и обсуждениях [zapret](https://github.com/bol-van/zapret).

- Настройка `--dpi-desync-fooling=badsum` в zapret может работать не корректно если роутер keenetic находится за другим nat.
  Как пример таким устройством может быть оптический терминал который преобразует сигнал из оптоволокна.
  В этом случае данное устройство нужно перевести в режим моста (bridge).

- Статическая маршрутизация на основе dnsmasq требует времени для сбора IP-адресов доменов.
  В начале возможна нестабильность — просто обновите страницу пару раз что бы собрались возможные IP-адреса домена.

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005) версии 4.0 или выше.
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Настройки в веб-панели Keenetic

- В [компонентах KeeneticOS](https://help.keenetic.com/hc/ru/articles/360000358039) нужно включить `Kernel modules for Netfilter` или `Модули ядра подсистемы Netfilter`.
- Купите, настройте и включите туннель [VPN](https://help.keenetic.com/hc/ru/articles/115005342025)
  или [Proxy](https://help.keenetic.com/hc/ru/articles/7474374790300).
- Настройте пользовательский [DNS-over-HTTPS](https://help.keenetic.com/hc/ru/articles/360007687159) (пример: `https://dns.google/dns-query`).
- Отключите [DNS от провайдера](https://help.keenetic.com/hc/ru/articles/360008609399).
- Создайте записи DNS на адресе `192.168.1.1:5300` для доменов, к которым нужен доступ через туннель.
- Пример списка доменов (не ставьте dns записи для GitHub до установки):

  ```plaintext
  chatgpt.com
  openai.com
  oaiusercontent.com
  github.com
  githubusercontent.com
  githubcopilot.com
  ```

### 2. Установка необходимых компонентов

- Выполните следующую команду:

  ```sh
  opkg update && opkg install curl && sh -c "$(curl -H 'Cache-Control: no-cache' -f -L https://raw.githubusercontent.com/GuFFy12/keenetic-bypass/refs/heads/main/install.sh)"
  ```

- Или если хотите установить в режиме оффлайн, то разархивируйте на роутере
  [файл релиз](https://github.com/GuFFy12/keenetic-bypass/releases/latest) и запустите:

  ```sh
  sh install.sh
  ```

### 3. Конфигурация Zapret ([`/opt/zapret/config`](https://github.com/bol-van/zapret))

- Переменная `IFACE_WAN` установлена автоматически на дефолтный интерфейс `wan`, который использует внешний IP-адрес.
  Чтобы вручную получить его, выполните команду:

  ```sh
  ip route show default 0.0.0.0/0
  ```

- Опционально обновите списки доменов `/opt/zapret/ipset/zapret-hosts-user.txt` и выполните команду:

  ```sh
  /opt/zapret/ipset/get_config.sh
  ```

### 4. Конфигурация Dnsmasq ([`/opt/dnsmasq_routing/dnsmasq.conf`](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html))

- Переменная `server` установлена автоматически на первый найденный `127.0.0.1:port`, который используется для получения DNS записей.
  Чтобы вручную получить список DNS серверов, выполните команду:

  ```sh
  cat /tmp/ndnproxymain.stat
  ```

### 5. Конфигурация Dnsmasq Routing (`/opt/dnsmasq_routing/dnsmasq_routing.conf`)

- Устройство отправляет DNS-запрос на маршрутизатор, который с помощью dnsmasq возвращает IP-адрес и добавляет его в ipset.
  Все IP-адреса из ipset перенаправляются через туннель. Для работы системы важно, чтобы все DNS-запросы шли через маршрутизатор.
- Переменные `INTERFACE` и `INTERFACE_SUBNET` установлены в зависимости от вашего выбора во время установки.
  Чтобы вручную получить список интерфейсов выполните команду:

  ```sh
  ip -o -4 addr show
  ```

- Опционально настройте следующие переменные:
  - `KILL_SWITCH` - если установлено в `1`, при отключении VPN или прокси трафик не будет направляться в сеть.
  - `IPSET_TABLE_SAVE` - если установлено в `1`, таблица с IP-адресами будет сохранена при перезагрузке.
  - `IPSET_TABLE` - имя таблицы ipset.
  - `IPSET_TABLE_TIMEOUT` - тайм-аут для записей в таблице (`0` для неограниченного времени).
  - `INTERFACE` - интерфейс выходного узла туннеля.
  - `INTERFACE_SUBNET` - подсеть интерфейса выходного узла туннеля.
  - `MARK` - маркер, используемый в iptables.

## Настройка WireGuard на роутере в качестве сервера для улучшения интернета

- Подробности: [WireGuard VPN](https://help.keenetic.com/hc/ru/articles/360010592379).
