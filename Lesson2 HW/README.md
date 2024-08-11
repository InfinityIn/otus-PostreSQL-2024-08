### Домашнее задание по уроку №2
Уровни изоляции транзакций

### Генерация SSH-ключей

```
ssh-keygen -t ed25519
```

Создался приватный и публичный ключ

### Копируем публичный ключ

### Создаём виртуальную машину (ВМ) в Яндекс.Клауд (через WEB-UI)
При создании ВМ указываем скопированный публичный ключ SSH

### Подключаемся к ВМ с помощью SSH

Нужно указать имя админской учетной записи + публичный IPv4 адрес. У меня так:

```
ssh admin@89.169.163.106
```
В первый раз SSH client скажет, что соединение неизвестное и спросит доп. разрешение на подключение

## Работа с PostgreSQL

### Установка PostgreSQL

```sh
sudo apt update && sudo apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt -y install postgresql-15
```

### Запустим psql

```sh
sudo -u postgres psql -p 5432
```

Видим:
```sh
psql (15.7 (Ubuntu 15.7-1.pgdg24.04+1), server 14.12 (Ubuntu 14.12-1.pgdg24.04+1))
Type "help" for help.

postgres=# 
```

### Создаём БД и таблицу для тестов

```sql
postgres=# CREATE DATABASE test;
test=# SELECT current_database();
SELECT * FROM persons;
test=# INSERT INTO persons(first_name, second_name) VALUES ('Иван', 'Иванов');
INSERT 0 1
test=# INSERT INTO persons(first_name, second_name) VALUES ('Петр', 'Петров');
INSERT 0 1

test=# SELECT * FROM persons;
 id | first_name | second_name
----+------------+-------------
  1 | Иван       | Иванов
  2 | Петр       | Петров
(2 rows)
```

### Отключим автокоммит и проверим текущий уровень изоляции транзакций

```sql
test=# \echo :AUTOCOMMIT
on
test=# \set AUTOCOMMIT OFF
test=# show transaction isolation level;
 transaction_isolation 
-----------------------
 read committed
(1 row)
```

## Чек-лист домашнего задания:
### Начать новую транзакцию в обоих сессиях с дефолтным (не меняя) уровнем изоляции

Снимков экрана или листинга, к сожалению, нет, потому что ssh сессия постоянно вылетала и не получилось всё круто отснять

1. В первой сессии добавить новую запись insert into persons(first_name, second_name) values('Сергей', 'Сергеев');
2. Сделать select from persons во второй сессии
3. Видите ли вы новую запись и если да то почему?

#### Ответ: 
##### Запись не видно уровень изоляции ReadCommited предполагает, что для чтения доступны записи, которые были "закоммичены".

4. Завершить первую транзакцию - commit;
5. Сделать select from persons во второй сессии
6. Видите ли вы новую запись и если да то почему?

#### Ответ: 
##### Запись видно. Потому что первая сессия завершила транзакцию и запись стала доступна для чтения второй транзакции/сессии

7. Завершите транзакцию во второй сессии

### Начать новые но уже repeatable read транзации - set transaction isolation level repeatable read;

Изменяем уровень изоляции транзакций на RepetableRead

```sql
test=*# set transaction isolation level repeatable read;
```

1. В первой сессии добавить новую запись insert into persons(first_name, second_name) values('Света', 'Светова');
2. Сделать select* from persons во второй сессии*
3. Видите ли вы новую запись и если да то почему?

#### Ответ: 
##### Запись не видно, потому что RepeatableRead включает в себя ограничения из ReadCommited - незакоммиченые записи недоступны для других транзакций

4. Завершить первую транзакцию - commit;
5. Сделать select from persons во второй сессии
6. Видите ли вы новую запись и если да то почему?

#### Ответ: 
##### Запись также не видно, потому что (хоть и завершилась первая транзкация) не завершилась вторая транзакция с таким же уровнем изоляции RepeatableRead, т.е. есть доступны все данные, которые были закоммиченны до начала транзакции

7. Завершить вторую транзакцию
8. Сделать select * from persons во второй сессии
9. Видите ли вы новую запись и если да то почему?

#### Ответ: 
##### Видно, т.к. теперь и вторая транзакция завершилась, новый Select - это третья транзакция, а ей доступны все данные по завершенным транзакциям.
