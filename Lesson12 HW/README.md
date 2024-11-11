# Домашнее задание по уроку №12
Резервное копирование и восстановление

## Чек-лист домашнего задания:
### Создаем ВМ/докер c ПГ.
Продолжаем работать в Яндекс.Облаке
### Создаем БД, схему и в ней таблицу.
```sql
postgres=# create database test_backup_db;
CREATE DATABASE

postgres=# \c test_backup_db 
You are now connected to database "test_backup_db" as user "admin".

test_backup_db=# create schema test_backup_schema;
CREATE SCHEMA

test_backup_db=# CREATE TABLE test_backup_schema.table1  (
    id SERIAL PRIMARY KEY,
    text TEXT
);
CREATE TABLE
```
### Заполним таблицы автосгенерированными 100 записями.
```sql
test_backup_db=# INSERT INTO test_backup_schema.table1          
SELECT id, MD5(random()::TEXT)::TEXT
FROM generate_series(1, 100) AS id;
INSERT 0 100
```
### Под линукс пользователем Postgres создадим каталог для бэкапов
```
> mkdir /backup
> chown -R postgres: /backup
```
### Сделаем логический бэкап используя утилиту COPY
```sql
test_backup_db=# copy test_backup_schema.table1 TO '/backup/table1' ;
COPY 100
```
### Восстановим в 2 таблицу данные из бэкапа.
```sql
test_backup_db=# CREATE TABLE test_backup_schema.table2  (
    id SERIAL PRIMARY KEY,
    text TEXT
);
CREATE TABLE
test_backup_db=# copy test_backup_schema.table2 from '/backup/table1' ;
COPY 100
```
### Используя утилиту pg_dump создадим бэкап в кастомном сжатом формате двух таблиц
```sql
> pg_dump -Fc -Z -C  -n test_backup_schema -f /backup/test_backup.gz backup -U admin -W
```
### Используя утилиту pg_restore восстановим в новую БД только вторую таблицу!
```sql
test_backup_db=# create database test_backup_db2;
CREATE DATABASE

> pg_restore -l /backup/test_backup.gz 
;
; Archive created at 2024-11-11 15:15:11 UTC
;     dbname: backup
;     TOC Entries: 19
;     Compression: 0
;     Dump Version: 1.14-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 14.12 
;     Dumped by pg_dump version: 14.12
;
;
; Selected TOC Entries:
;
5; 2615 16385 SCHEMA - test_backup_schema admin
211; 1259 16387 TABLE test_backup_schema table1 admin
213; 1259 16397 TABLE test_backup_schema table2 admin
212; 1259 16396 SEQUENCE test_backup_schema table2_id_seq admin
3351; 0 0 SEQUENCE OWNED BY test_backup_schema table2_id_seq admin
210; 1259 16386 SEQUENCE test_backup_schema table1_id_seq admin
3352; 0 0 SEQUENCE OWNED BY test_backup_schema table1_id_seq admin
3196; 2604 16423 DEFAULT test_backup_schema table1 id admin
3197; 2604 16424 DEFAULT test_backup_schema table2 id admin
3342; 0 16387 TABLE DATA test_backup_schema table1 admin
3344; 0 16397 TABLE DATA test_backup_schema table2 admin
3353; 0 0 SEQUENCE SET test_backup_schema table2_id_seq admin
3354; 0 0 SEQUENCE SET test_backup_schema table1_id_seq admin
3201; 2606 16404 CONSTRAINT test_backup_schema table2 table2_pkey admin
3199; 2606 16394 CONSTRAINT test_backup_schema table1 table1_pkey admin

pg_restore -l /backup/test_backup.gz  > list.xxx

Используем следующий контент для востановления только второй таблицы и схемы

5; 2615 16385 SCHEMA - test_backup_schema admin
213; 1259 16397 TABLE test_backup_schema table2 admin
212; 1259 16396 SEQUENCE test_backup_schema table2_id_seq admin
3351; 0 0 SEQUENCE OWNED BY test_backup_schema table2_id_seq admin
3197; 2604 16424 DEFAULT test_backup_schema table2 id admin
3344; 0 16397 TABLE DATA test_backup_schema table2 admin
3353; 0 0 SEQUENCE SET test_backup_schema table2_id_seq admin
3201; 2606 16404 CONSTRAINT test_backup_schema table2 table2_pkey admin


pg_restore -L list.xxx -d test_backup_db2 -U admin -W /backup/test_backup.gz

test_backup_db2=# \dt test_backup_schema.*
       List of relations
 Schema                |   Name  | Type  | Owner 
-----------------------+---------+-------+-------
 test_backup_schema    | table2  | table | admin
(1 row)
```