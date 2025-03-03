# Keenetic Zapret

## Замечания

- Этот код создан для изучения сетевых технологий. Он может быть полезен для улучшения работы интернета, но то, как вы его используете — ваш выбор.
  Автор ответственности не несет.

- Конфигурация zapret протестирована и работает стабильно. Со временем настройки могут стать не актуальными,
  проверяйте актуальные методы в репозитории и обсуждениях [zapret](https://github.com/bol-van/zapret).

- Настройка `--dpi-desync-fooling=badsum` в zapret может работать не корректно если роутер keenetic находится за другим nat.
  Как пример таким устройством может быть оптический терминал который преобразует сигнал из оптоволокна.
  В этом случае данное устройство нужно перевести в режим моста (bridge).

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005) версии 4.0 или выше.
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Настройки в веб-панели Keenetic

- В [компонентах KeeneticOS](https://help.keenetic.com/hc/ru/articles/360000358039) нужно включить `Kernel modules for Netfilter` или `Модули ядра подсистемы Netfilter`.
- Купите, настройте и включите туннель [VPN](https://help.keenetic.com/hc/ru/articles/115005342025)
  или [Proxy](https://help.keenetic.com/hc/ru/articles/7474374790300).

### 2. Установка необходимых компонентов

- Выполните следующую команду:

  ```sh
  opkg update && opkg install curl && sh -c "$(curl -H 'Cache-Control: no-cache' -f -L https://raw.githubusercontent.com/GuFFy12/keenetic-zapret/refs/heads/main/install.sh)"
  ```

- Или если хотите установить в режиме оффлайн, то разархивируйте на роутере
  [файл релиз](https://github.com/GuFFy12/keenetic-zapret/releases/latest) и запустите:

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
