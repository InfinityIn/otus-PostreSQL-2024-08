## Чек-лист домашнего задания:
### создать ВМ с Ubuntu 20.04/22.04 или развернуть докер любым удобным способом

Работаем локально. 
Запускаем Docker Desktop

### поставить на нем Docker Engine
### сделать каталог /var/lib/postgres
### развернуть контейнер с PostgreSQL 15 смонтировав в него /var/lib/postgresql
### развернуть контейнер с клиентом postgres
Монтировать будем сразу и сервер и клиент.

С помощью файла docker-compose.yaml монтируем контейнеры в нашем Docker Desktop

```yaml
version: "3.9"
services:
  postgres:
    container_name: postgres_container
    image: postgres:14.8-alpine3.18    
    environment:
      POSTGRES_DB: "postgres"
      POSTGRES_USER: "postgres"
      POSTGRES_PASSWORD: "postgres"
    volumes:
      - pg_project:/var/lib/postgresql/data
    ports:
      - "5432:5433"
    restart: always
    networks:
      - postgres

  pgadmin:
    container_name: pgadmin_container
    image: dpage/pgadmin4:7.2
    environment:
      PGADMIN_DEFAULT_EMAIL: "postgres@postgres.com"
      PGADMIN_DEFAULT_PASSWORD: "postgres"
      PGADMIN_CONFIG_SERVER_MODE: "False"
    volumes:
      - pgadmin-data:/var/lib/pgadmin
    ports:
      - "5050:80"
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 1G
    networks:
      - postgres

volumes:
  pg_project:
  pgadmin-data:  

networks:
  postgres:
    driver: bridge
```

В папке с файлом docker-compose.yaml выполняю простую команду:
```
docker-compose up -d
```
(не указываю название файла, по умолчанию берется дефолтное название)

Запуск такой конфигурации создаст контейнер pg_db и скачает Image Postgre с docker-hub

Запускаю контейнер на порту 5433, потому что на моём компьютере уже установлен сервер PostgreSQL для работы
Чтобы не конфликтовал. 
Внутри контейнера оставляю порт 5432

### подключится из контейнера с клиентом к контейнеру с сервером и сделать таблицу с парой строк
После монтирования контейнеров, наружу "торчит" pg-admin, находящийся рядом с контейнером сервера postgres
#### Создаём новое подключение и вводим туда "координаты" сервера:
- hostname: обычно это сетевой путь, но т.к. мы находимся внутри докера, можно обратиться по имени контейнера: postgres_container
- port: внутри докера контейнер с сервером находится по порту 5432

#### Остальные параметры дефолтные. подключаемся к нему, создаём БД и таблицу с парой строк:

```sql
CREATE DATABASE otus
    WITH
    OWNER = test_user
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf-8'
    LC_CTYPE = 'en_US.utf-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;
```

Выберем в дереве объектов pgAdmin'a новую БД и выполним там следующие скрипты:

```sql
CREATE TABLE test_table
(
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    test_integer integer NOT NULL,
    test_timestamp timestamp without time zone,
    test_text text,
)

INSERT INTO test_table(test_integer, test_timestamp, test_text)
VALUES (1, "2024-08-25 06:41:20.977539", "text1");
INSERT INTO test_table(test_integer, test_timestamp, test_text)
VALUES (2, "2024-08-25 06:41:20.977539", "text2");
INSERT INTO test_table(test_integer, test_timestamp, test_text)
VALUES (3, "2024-08-25 06:41:20.977539", "text3");

```

### подключится к контейнеру с сервером с ноутбука/компьютера извне инстансов ЯО/места установки докера

Подключаемся к контейнеру postgres внутри докера из pgAdmin, который установлен локально на компьютере
Для этого, создаём новое подключение и прописываем следующие параметры:
- hostname: localhost, т.к. мы уже не находимся внутри докера
- port: снаружи докера контейнер с сервером находится по порту 5433

### удалить контейнер с сервером
Удаляем контейнер с сервером в docker desktop
Все анонимные volumes удаляются вместе с контейнером, но этого не происходит с именованными. 
Потому, volume с названием pg_project, указанный в docker-compose.yaml успешно сохраняется

### создать его заново

```
docker-compose up -d
```

### подключится снова из контейнера с клиентом к контейнеру с сервером
Повторяем действия, описанные выше

### проверить, что данные остались на месте
данные остались на месте, т.к. volume не был удалён

### оставляйте в ЛК ДЗ комментарии что и как вы делали и как боролись с проблемами
