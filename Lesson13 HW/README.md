# Домашнее задание по уроку №13
Репликации

Цель: реализовать свой миникластер на 3 ВМ.

Развернём сразу все 4 ВМ:
```
pg_main = [
  "10.128.0.6",  # ВМ №1
  "10.128.0.12", # ВМ №2 
  "10.128.0.26", # ВМ №3
  "10.128.0.32",  # ВМ №4
]
```
## Чек-лист домашнего задания:
### На 1 ВМ создаем таблицы test для записи, test2 для запросов на чтение.
```sql
-- ВМ №1 (10.128.0.6)

postgres=# CREATE DATABASE test_db;
CREATE DATABASE

postgres=# \c test_db ;
You are now connected to database "test_db" as user "postgres".

test_db=# CREATE TABLE test  (
    id SERIAL PRIMARY KEY,
    text TEXT
);
    CREATE TABLE test2  (
        id SERIAL PRIMARY KEY,
        text TEXT
    );
CREATE TABLE
CREATE TABLE

```
### Создаем публикацию таблицы test и подписываемся на публикацию таблицы test2 с ВМ №2.
```sql
test_db=# create user test_user LOGIN REPLICATION PASSWORD '123passpass123';
CREATE ROLE

grant all ON test to test_user ;
grant all ON test2 to test_user ;

CREATE PUBLICATION test FOR TABLE test;

test_db=# CREATE SUBSCRIPTION test2
    CONNECTION 'host=10.128.0.12 port=5432 user=test_user dbname=test_db password=123passpass123'
    PUBLICATION test2;
NOTICE:  created replication slot "test2" on publisher
CREATE SUBSCRIPTION

test_db=# select * from pg_replication_origin_status;
 local_id | external_id | remote_lsn | local_lsn 
----------+-------------+------------+-----------
        1 | pg_16551    | 0/0        | 0/0
        2 |             | 0/1968390  | 0/0
(2 rows)

test_db=# insert into test2 values (1, 'text_on_vm1');
INSERT 0 1

test_db=# \dRs;
          List of subscriptions
 Name  |  Owner   | Enabled | Publication 
-------+----------+---------+-------------
 test2 | postgres | t       | {test2}
(1 row)

test_db=# \dRp;
                               List of publications
 Name |  Owner   | All tables | Inserts | Updates | Deletes | Truncates | Via root 
------+----------+------------+---------+---------+---------+-----------+----------
 test | postgres | f          | t       | t       | t       | t         | f
(1 row)
```
### На 2 ВМ создаем таблицы test2 для записи, test для запросов на чтение.
```sql
-- ВМ №2 (10.128.0.12)
Добавим воможность репликации с подсети и перезагрузимся

CREATE DATABASE test_db;

CREATE TABLE test  (
    id SERIAL PRIMARY KEY,
    text TEXT
);

CREATE TABLE test2  (
    id SERIAL PRIMARY KEY,
    text TEXT
);

```

### Создаем публикацию таблицы test2 и подписываемся на публикацию таблицы test1 с ВМ №1.
```sql
test_db=# create user test_user LOGIN REPLICATION PASSWORD '123passpass123';
CREATE ROLE

grant all ON test to test_user ;
grant all ON test2 to test_user ;

CREATE PUBLICATION test2 FOR TABLE test2;

test_db=# CREATE SUBSCRIPTION test
    CONNECTION 'host=10.128.0.6 port=5432 user=test_user dbname=test_db password=123passpass123'
    PUBLICATION test;
NOTICE:  created replication slot "test" on publisher
CREATE SUBSCRIPTION


test_db=# select * from pg_replication_origin_status ;
 local_id | external_id | remote_lsn | local_lsn 
----------+-------------+------------+-----------
        1 | pg_16410    | 0/0        | 0/0
        2 |             | 0/1972A48  | 0/0
(2 rows)


test_db=# select * from test;
 id |      text       
----+-----------------
  1 | text_on_vm1
(1 row)

test_db=# insert into test2 values (2, 'text_on_vm2');
INSERT 0 1
```
### 3 ВМ использовать как реплику для чтения и бэкапов (подписаться на таблицы из ВМ №1 и №2 ).
```sql
-- ВМ №3 (10.128.0.26)

CREATE DATABASE test_db;

postgres=# \c test_db ;
You are now connected to database "test_db" as user "postgres".

CREATE TABLE test  (
    id SERIAL PRIMARY KEY,
    text TEXT
);
CREATE TABLE test2  (
    id SERIAL PRIMARY KEY,
    text TEXT
);

grant all ON test to test_db ;
grant all ON test2 to test_db ;

test_db-# \dt;
         List of relations
 Schema | Name  | Type  |  Owner   
--------+-------+-------+----------
 public | test  | table | postgres
 public | test2 | table | postgres
(2 rows)

test_db=# CREATE SUBSCRIPTION test31
    CONNECTION 'host=10.128.0.6 port=5432 user=test_user dbname=test_db password=123passpass123'
    PUBLICATION test;
CREATE SUBSCRIPTION test32
    CONNECTION 'host=10.128.0.12 port=5432 user=test_user dbname=test_db password=123passpass123'
    PUBLICATION test2;
NOTICE:  created replication slot "test31" on publisher
CREATE SUBSCRIPTION
NOTICE:  created replication slot "test32" on publisher
CREATE SUBSCRIPTION

test_db=# select * from pg_replication_origin;
 roident |  roname  
---------+----------
       1 | pg_16410
       2 | pg_16410
(2 rows)

test_db=# select * from test;
 id |      text       
----+-----------------
  1 | text_on_vm1
(1 row)

test_db=# select * from test2;
 id |      text       
----+-----------------
  2 | text_on_vm2
(1 row)


test_db=# \dRs
           List of subscriptions
  Name  |  Owner   | Enabled | Publication 
--------+----------+---------+-------------
 test31 | postgres | t       | {test}
 test32 | postgres | t       | {test2}
(2 rows)
```

### * реализовать горячее реплицирование для высокой доступности на 4ВМ. Источником должна выступать ВМ №3. Написать с какими проблемами столкнулись.
```sql
-- ВМ №4 (10.128.0.32)
> pg_lsclusters 
Ver Cluster Port Status Owner    Data directory              Log file
15  main    5432 online postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log

> pg_basebackup -R -D /var/lib/postgresql/15/main -h 10.128.0.26 -U test_db -W

> pg_lsclusters 
Ver Cluster Port Status        Owner    Data directory              Log file
15  main    5432 down,recovery postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log

> sudo systemctl start postgresql@15-main.service

-- ВМ №3 (10.128.0.26)
postgres=# select * from pg_stat_replication \gx
-[ RECORD 1 ]----+------------------------------
pid              | 7494
usesysid         | 16388
usename          | test_db
application_name | 15/main
client_addr      | 10.128.0.32
client_hostname  | 
client_port      | 60046
backend_start    | 2024-11-12 12:14:33.654812+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/5000148
write_lsn        | 0/5000148
flush_lsn        | 0/5000148
replay_lsn       | 0/5000148
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2024-11-12 12:16:41.458745+00
```