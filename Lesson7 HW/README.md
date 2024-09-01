### Домашнее задание по уроку №7
Логический уровень PostgreSQL

## Чек-лист домашнего задания:
### создайте новый кластер PostgresSQL 14
Работаем в докер
### зайдите в созданный кластер под пользователем postgres
```
sudo -i -u postgres psql
```
### создайте новую базу данных testdb
```
postgres=# create database testdb;
CREATE DATABASE
postgres=#
```
### зайдите в созданную базу данных под пользователем postgres
```
postgres=# \c testdb 
You are now connected to database "testdb" as user "postgres".
postgres=# select current_user;
 current_user 
--------------
 postgres
(1 row)
```
### создайте новую схему testnm
```
testdb=# create schema testnm;
CREATE SCHEMA
testdb=# \dn
List of schemas
  Name  | Owner 
--------+-------
 public | postgres
 testnm | postgres
(2 rows)
```
### создайте новую таблицу t1 с одной колонкой c1 типа integer
```
testdb=# create table t1 ( c1 integer )
testdb-# ;
CREATE TABLE
testdb=# \dt t1
       List of relations
 Schema | Name | Type  | Owner 
--------+------+-------+-------
 public | t1   | table | postgres
(1 row)

testdb=# \d t1
                 Table "public.t1"
 Column |  Type   | Collation | Nullable | Default 
--------+---------+-----------+----------+---------
 c1     | integer |           |          | 
```
### вставьте строку со значением c1=1
```
testdb=# insert into t1 values (1);
INSERT 0 1
testdb=# select * from t1;
 c1 
----
  1
(1 row)
```
### создайте новую роль readonly
```
testdb=# create role readonly;
CREATE ROLE
testdb=# \du
                                   List of roles
 Role name |                         Attributes                         | Member of 
-----------+------------------------------------------------------------+-----------
 admin     | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
 readonly  | Cannot login                                               | {}
 ```
### дайте новой роли право на подключение к базе данных testdb
### дайте новой роли право на использование схемы testnm
### дайте новой роли право на select для всех таблиц схемы testnm
```
testdb=# grant CONNECT ON DATABASE testdb TO readonly ;
GRANT
testdb=# grant USAGE ON SCHEMA testnm TO readonly ;
GRANT
testdb=# grant SELECT ON ALL TABLES IN SCHEMA testnm TO readonly ;
GRANT
```
### создайте пользователя testread с паролем test123
```
testdb=# create user testread with password 'test123';
CREATE ROLE
testdb=# \du testread 
           List of roles
 Role name | Attributes | Member of 
-----------+------------+-----------
 testread  |            | {}
```
### дайте роль readonly пользователю testread
```
testdb=# grant readonly TO testread ;
GRANT ROLE
testdb=# \du testread 
            List of roles
 Role name | Attributes | Member of  
-----------+------------+------------
 testread  |            | {readonly}
```
### зайдите под пользователем testread в базу данных testdb
```
psql -h db -d testdb -U testread 
Password for user testread: 
psql (14.12 (Debian 14.12-1.pgdg120+1))
Type "help" for help.

testdb=#
```
### сделайте select * from t1;
```
testdb=# select * from t1;
ERROR:  permission denied for table t1
```
### получилось? (могло если вы делали сами не по шпаргалке и не упустили один существенный момент про который позже) напишите что именно произошло в тексте домашнего задания у вас есть идеи почему? ведь права то дали? посмотрите на список таблиц подсказка в шпаргалке под пунктом 20. а почему так получилось с таблицей (если делали сами и без шпаргалки то может у вас все нормально)
Нет, потому что таблица в другой схеме. По умолчанию - public
```
testdb=> \dt public.t1 
       List of relations
 Schema | Name | Type  | Owner 
--------+------+-------+-------
 public | t1   | table | admin
(1 row)
testdb=> \dn+
                       List of schemas
  Name  | Owner    | Access privileges |      Description       
--------+----------+-------------------+------------------------
 public | postgres | admin=UC/admin   +| standard public schema
        |          | =UC/admin         | 
 testnm | postgres | admin=UC/admin   +| 
        |          | readonly=U/admin  | 
(2 rows)
```
### вернитесь в базу данных testdb под пользователем postgres. удалите таблицу t1
```
testdb=# drop table t1 ;
DROP TABLE
```
### создайте ее заново но уже с явным указанием имени схемы testnm. вставьте строку со значением c1=1
```
testdb=# create table testnm.t1 ( c1 integer );
CREATE TABLE
testdb=# \d t1
Did not find any relation named "t1".
testdb=# \d testnm.t1
                 Table "testnm.t1"
 Column |  Type   | Collation | Nullable | Default 
--------+---------+-----------+----------+---------
 c1     | integer |           |          | 

testdb=# insert into testnm.t1 values (1);
INSERT 0 1

testdb=# select * from testnm.t1 ;
 c1 
----
  1
(1 row)
```
### зайдите под пользователем testread в базу данных testdb. сделайте select * from testnm.t1;
```
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
```
### получилось? есть идеи почему? если нет - смотрите шпаргалку
Не получилось. Таблица создана после того, как мы предоставили права. По умолчанию права выдаются только владельцу.
### как сделать так чтобы такое больше не повторялось? если нет идей - смотрите шпаргалку
Нужно изменить default привилегии для схемы testnm
```
testdb=# alter default privileges IN SCHEMA testnm GRANT SELECT ON TABLES TO readonly;
ALTER DEFAULT PRIVILEGES
```
### сделайте select * from testnm.t1; получилось? есть идеи почему? если нет - смотрите шпаргалку
```
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
```

Все так же, таблица создана после изменения схемы. При создании таблицы выдаются права. Обычно только owner. 

Если создать сейчас таблицу t2 в схеме testnm, то мы получим права на неё
```
testdb=# create table testnm.t2 ( c1 integer);
CREATE TABLE

testdb=> \dp testnm.t2 
                             Access privileges
 Schema | Name | Type  |  Access privileges  | Column privileges | Policies 
--------+------+-------+---------------------+-------------------+----------
 testnm | t2   | table | admin=arwdDxt/admin+|                   | 
        |      |       | readonly=r/admin    |                   | 


testdb=> select * from testnm.t2;
 c1 
----
(0 rows)
```
Чтобы получить доступ к таблице t1, еще раз выдадим права роли readonly на чтение всех существующих таблиц
```
testdb=# grant SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;
GRANT
```
### сделайте select * from testnm.t1; получилось?
да
### ура!
ура!
### теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);
```
testdb=> create table t2(c1 integer); insert into t2 values (2);
CREATE TABLE
INSERT 0 1
```
### а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly?
Получилось, потому что права даются на схему по умолчанию всем пользователям
### есть идеи как убрать эти права? если нет - смотрите шпаргалку
Чтобы убрать эти права, нужно отобрать права на схему public

```
testdb=# REVOKE CREATE on SCHEMA public FROM PUBLIC ;
REVOKE
testdb=# REVOKE ALL on DATABASE testdb FROM public; 
REVOKE
```
### если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку - объясните что сделали и почему ### выполнив указанные в ней команды
### теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);
```
testdb=> create table t3(c1 integer); insert into t2 values (2);
ERROR:  permission denied for schema public
LINE 1: create table t3(c1 integer);
                     ^
INSERT 0 1
```
### расскажите что получилось и почему
Не получилось создать таблицу - нет прав на создание объектов в схеме public