### Домашнее задание по уроку №9
Журналы

## Чек-лист домашнего задания:
Продолжаем работать в Яндекс.Облаке
### 1. Настройте выполнение контрольной точки раз в 30 секунд.
```
postgres=# show checkpoint_timeout;
 checkpoint_timeout 
--------------------
 5min
(1 row)

postgres=# show checkpoint_completion_target ;
 checkpoint_completion_target 
------------------------------
0.5
(1 row)

postgres=# alter system set checkpoint_timeout TO '30s';
ALTER SYSTEM

postgres=# select pg_reload_conf();
 pg_reload_conf 
----------------
 t
(1 row)

> pg_conftool 13 main set checkpoint_timeout 30s;

postgres=# show checkpoint_timeout ;
 checkpoint_timeout 
--------------------
 30s
(1 row)
```
### 2. 10 минут c помощью утилиты pgbench подавайте нагрузку.
```
postgres=# create database test_db;
CREATE DATABASE
```

```
> pgbench -i test_db
dropping old tables...
NOTICE:  table "pgbench_accounts" does not exist, skipping
NOTICE:  table "pgbench_branches" does not exist, skipping
NOTICE:  table "pgbench_history" does not exist, skipping
NOTICE:  table "pgbench_tellers" does not exist, skipping
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.07 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.46 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.33 s, vacuum 0.05 s, primary keys 0.07 s).

postgres=# select pg_current_wal_lsn(), pg_current_wal_insert_lsn();
 pg_current_wal_lsn | pg_current_wal_insert_lsn 
--------------------+---------------------------
 0/2249818          | 0/2249818
(1 row)

SELECT * FROM pg_stat_bgwriter \gx
-[ RECORD 1 ]---------+------------------------------
checkpoints_timed     | 4
checkpoints_req       | 2
checkpoint_write_time | 15359
checkpoint_sync_time  | 15
buffers_checkpoint    | 1713
buffers_clean         | 0
maxwritten_clean      | 0
buffers_backend       | 1690
buffers_backend_fsync | 0
buffers_alloc         | 2008
stats_reset           | 2024-11-10 08:12:07.854234+00


> pgbench -P 60 -T 600 test_db
starting vacuum...end.
progress: 60.0 s, 475.7 tps, lat 2.106 ms stddev 2.139
progress: 120.0 s, 537.7 tps, lat 1.863 ms stddev 1.914
progress: 180.0 s, 508.8 tps, lat 1.961 ms stddev 2.004
progress: 240.0 s, 561.6 tps, lat 1.781 ms stddev 1.799
progress: 300.0 s, 574.1 tps, lat 1.742 ms stddev 2.009
progress: 360.0 s, 508.6 tps, lat 1.966 ms stddev 2.118
progress: 420.0 s, 553.4 tps, lat 1.807 ms stddev 1.723
progress: 480.0 s, 535.1 tps, lat 1.868 ms stddev 1.802
progress: 540.0 s, 536.5 tps, lat 1.864 ms stddev 1.855
progress: 600.0 s, 529.9 tps, lat 1.887 ms stddev 1.944
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 1
number of threads: 1
duration: 600 s
number of transactions actually processed: 319233
latency average = 1.866 ms
latency stddev = 1.943 ms
tps = 531.053236 (including connections establishing)
tps = 531.156012 (excluding connections establishing)
```
### 3. Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку.
```
postgres=# select pg_current_wal_lsn(), pg_current_wal_insert_lsn();
 pg_current_wal_lsn | pg_current_wal_insert_lsn 
--------------------+---------------------------
 0/1B38A8B7         | 0/1B38A8B7
(1 row)


postgres=# SELECT * FROM pg_stat_bgwriter \gx
-[ RECORD 1 ]---------+------------------------------
checkpoints_timed     | 25
checkpoints_req       | 2
checkpoint_write_time | 327132
checkpoint_sync_time  | 398
buffers_checkpoint    | 42420
buffers_clean         | 0
maxwritten_clean      | 0
buffers_backend       | 3809
buffers_backend_fsync | 0
buffers_alloc         | 4453
stats_reset           | 2024-11-10 08:12:07.854234+00

postgres=# select pg_size_pretty('0/1B38A8B7'::pg_lsn - '0/2249818'::pg_lsn);
 pg_size_pretty 
----------------
 403 MB
(1 row)
```

В среднем на одну контрольную точку (21 конторльных точек за 10 минут)
```
postgres=# select pg_size_pretty(('0/1B39A7B8'::pg_lsn - '0/2249818'::pg_lsn) / 21 );
 
 pg_size_pretty 
----------------
 19 MB
(1 row)
```
Это подтверждается журналом:
```
2024-11-10 08:42:27.138 UTC [4568] LOG:  checkpoint starting: time
2024-11-10 08:42:42.011 UTC [4568] LOG:  checkpoint complete: wrote 1800 buffers (11.0%); 0 WAL file(s) added, 0 removed, 2 recycled; write=14.836 s, sync=0.006 s, total=14.898 s; sync files=5, longest=0.006 s, average=0.002 s; distance=19523 kB, estimate=20015 kB
```

### 4. Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?
```
postgres=# SELECT * FROM pg_stat_bgwriter \gx
-[ RECORD 1 ]---------+------------------------------
checkpoints_timed     | 25
checkpoints_req       | 2
checkpoint_write_time | 327132
checkpoint_sync_time  | 398
buffers_checkpoint    | 42420
buffers_clean         | 0
maxwritten_clean      | 0
buffers_backend       | 3809
buffers_backend_fsync | 0
buffers_alloc         | 4453
stats_reset           | 2024-11-10 08:12:07.854234+00

checkpoints_req - остался такой же.
Все чекпоинты уложились в checkpoints_timed.

show max_wal_size;
 max_wal_size 
--------------
 1GB
(1 row)

Все по расписанию, потому что данных недостаточно, что бы сработал чекпоинт от max_wal_size
```
### 5. Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.
```
Отключим
postgres=# ALTER SYSTEM SET synchronous_commit = off;
ALTER SYSTEM
postgres=# select pg_reload_conf();
 pg_reload_conf 
----------------
 t
(1 row)
postgres=# show synchronous_commit ;
 synchronous_commit 
--------------------
 off
(1 row)

postgres=# show wal_writer_delay ;
 wal_writer_delay 
------------------
 200ms
(1 row)

show fsync;
show wal_sync_method;
show data_checksums;
 fsync 
-------
 on
(1 row)

 wal_sync_method 
-----------------
 fdatasync
(1 row)

 data_checksums 
----------------
 off
(1 row)


> pgbench -P 60 -T 600 test_db
starting vacuum...end.
progress: 60.0 s, 2564.5 tps, lat 0.390 ms stddev 0.053
progress: 120.0 s, 2494.3 tps, lat 0.401 ms stddev 0.038
progress: 180.0 s, 2393.9 tps, lat 0.417 ms stddev 0.040
progress: 240.0 s, 2436.9 tps, lat 0.410 ms stddev 0.040
progress: 300.0 s, 2437.8 tps, lat 0.410 ms stddev 0.039
progress: 360.0 s, 2409.8 tps, lat 0.415 ms stddev 0.043
progress: 420.0 s, 2386.9 tps, lat 0.419 ms stddev 0.057
progress: 480.0 s, 2393.0 tps, lat 0.418 ms stddev 0.046
progress: 540.0 s, 2381.6 tps, lat 0.420 ms stddev 0.056
progress: 600.0 s, 2395.9 tps, lat 0.417 ms stddev 0.039
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 1
number of threads: 1
duration: 600 s
number of transactions actually processed: 1457668
latency average = 0.411 ms
latency stddev = 0.047 ms
tps = 2432.834354 (including connections establishing)
tps = 2432.882465 (excluding connections establishing)
```

fdatasync() подобна fsync(), однако не записывает изменившиеся метаданные в случае, если эти метаданные не нужны для последующего получения данных. 
Например, изменения st_atime или st_mtime (время последнего доступа и последнего изменения, соответственно; см. stat(2)) не нужно записывать, так как они ненужны для чтения самих данных. 
С другой стороны, при изменении размера файла (st_size, изменяется, например, ftruncate(2)) запись метаданных будет нужна.

Целью создания fdatasync() является сокращение обменов с диском для приложений, которым не нужна синхронизация метаданных с диском.

Получили большую производительность. 
С выключеным параметром synchronous_commit не гарантируется что wal записан на диск и не вызывается fdatasync(), которая имеет большие накладные расходы.
### 6. Создайте новый кластер с включенной контрольной суммой страниц. 
```c
> pg_dropcluster 13 main --stop
> pg_lsclusters 
Ver Cluster Port Status Owner Data directory Log file

> pg_createcluster 13 main --start -- -k
Creating new PostgreSQL cluster 13/main ... 
/usr/lib/postgresql/13/bin/initdb -D /var/lib/postgresql/13/main --auth-local peer --auth-host md5 -k
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.UTF-8".
The default database encoding has accordingly been set to "UTF8".
The default text search configuration will be set to "english".

Data page checksums are enabled.

fixing permissions on existing directory /var/lib/postgresql/13/main ... ok
creating subdirectories ... ok
selecting dynamic shared memory implementation ... posix
selecting default max_connections ... 100
selecting default shared_buffers ... 128MB
selecting default time zone ... Etc/UTC
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok
syncing data to disk ... ok

Success. You can now start the database server using:

    pg_ctlcluster 13 main start

Warning: systemd does not know about the new cluster yet. Operations like "service postgresql start" will not handle it. To fix, run:
  sudo systemctl daemon-reload
Warning: the cluster will not be running as a systemd service. Consider using systemctl:
  sudo systemctl start postgresql@13-main
Ver Cluster Port Status Owner    Data directory              Log file
13  main    5432 online postgres /var/lib/postgresql/13/main /var/log/postgresql/postgresql-13-main.log

postgres=# show data_checksums ;
 data_checksums 
----------------
 on
(1 row)
```
#### Создайте таблицу. Вставьте несколько значений. 
```sql
postgres=# CREATE TABLE text_table (
    id SERIAL PRIMARY KEY,
    text TEXT
);
CREATE TABLE

postgres=# INSERT INTO text_table
SELECT id, MD5(random()::TEXT)::TEXT
FROM generate_series(1, 1000000) AS id;
INSERT 0 1000000

postgres=# select * from text_table limit 5;
 id |               text               
----+----------------------------------
  1 | 164ecc16bc06f3df85fb08506929ddea
  2 | e7c29f3092241f29b04bbdd8bd3a8a5b
  3 | 6e007e3d2a6c6e6f6c0554fb53891299
  4 | 59d8fc52017b48107c9006b1d1aee72f
  5 | d22b4ff097f74661fda22b59c9ae47f0
(5 rows)

SELECT pg_relation_filepath('text_table');
 pg_relation_filepath 
----------------------
 base/13449/16386
(1 row)
```
#### Выключите кластер. 
```
pg_ctlcluster stop 13 main
```
#### Измените пару байт в таблице. 
```
> dd if=/dev/random of=/var/lib/postgresql/13/main/base/13449/16386 oflag=dsync conv=notrunc bs=1 count=8
8+0 records in
8+0 records out
8 bytes copied, 0.0075881 s, 1.2 kB/s
```
#### Включите кластер и сделайте выборку из таблицы. 
```
> pg_ctlcluster start 13 main

2024-11-10 08:55:07.854 UTC [5212] LOG:  shutting down
2024-11-10 08:55:07.995 UTC [5210] LOG:  database system is shut down
2024-11-10 08:56:06.112 UTC [5280] LOG:  starting PostgreSQL 13.15 (Ubuntu 13.15-1.pgdg22.04+1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0, 64-bit
2024-11-10 08:56:06.831 UTC [5280] LOG:  listening on IPv6 address "::1", port 5432
2024-11-10 08:56:06.831 UTC [5280] LOG:  listening on IPv4 address "127.0.0.1", port 5432
2024-11-10 08:56:07.001 UTC [5280] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2024-11-10 08:56:07.024 UTC [5281] LOG:  database system was shut down at 2024-11-10 08:55:07 UTC
2024-11-10 08:56:07.080 UTC [5280] LOG:  database system is ready to accept connections

postgres=# show data_checksums ;
 data_checksums 
----------------
 on
(1 row)

postgres=# select * from text_table limit 3;
WARNING:  page verification failed, calculated checksum 23782 but expected 64437
ERROR:  invalid page in block 0 of relation base/13449/16386
```
#### Что и почему произошло? 
Система упала из-за несовпадения контрольных сумм таблиц
#### как проигнорировать ошибку и продолжить работу?
```
postgres=# alter system set ignore_checksum_failure to true ;
ALTER SYSTEM
postgres=# select pg_reload_conf();
 pg_reload_conf 
----------------
 t
(1 row)
postgres=# show ignore_checksum_failure;
 ignore_checksum_failure 
-------------------------
 on
(1 row)

postgres=# select * from text_table limit 5;
WARNING:  page verification failed, calculated checksum 23782 but expected 64437
 id |               text               
----+----------------------------------
  1 | 164ecc16bc06f3df85fb08506929ddea
  2 | e7c29f3092241f29b04bbdd8bd3a8a5b
  3 | 6e007e3d2a6c6e6f6c0554fb53891299
  4 | 59d8fc52017b48107c9006b1d1aee72f
  5 | d22b4ff097f74661fda22b59c9ae47f0
(5 rows)

> apt-get install postgresql-13-pg-checksums

pg_checksums -c -D /var/lib/postgresql/13/main
pg_checksums: error: checksum verification failed in file "/var/lib/postgresql/13/main/base/13449/16386", block 0: calculated checksum 5CE6 but block contains FBB5
Checksum operation completed
Files scanned:  923
Blocks scanned: 14066
Bad checksums:  1
Data checksum version: 1
```

Используем VACUUM FULL для пересоздания файлов
```
postgres=# VACUUM FULL text_table ;
VACUUM

/usr/lib/postgresql/13/bin/pg_checksums_ext -c -D /var/lib/postgresql/13/main
Checksum operation completed
Files scanned:  927
Blocks scanned: 14060
Bad checksums:  0
Data checksum version: 1
```

Чего мы и добивались

```
postgres=# alter system set ignore_checksum_failure to DEFAULT ;
ALTER SYSTEM

postgres=# select pg_reload_conf();
 pg_reload_conf 
----------------
 t
(1 row)

postgres=# show ignore_checksum_failure;
 ignore_checksum_failure 
-------------------------
 off
(1 row)
``