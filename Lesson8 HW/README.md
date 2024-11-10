### Домашнее задание по уроку №8
MVCC, vacuum и autovacuum

## Чек-лист домашнего задания:
### Создать инстанс ВМ с 2 ядрами и 4 Гб ОЗУ и SSD 10GB
### Установить на него PostgreSQL 15 с дефолтными настройками
Работаем в Яндекс.Облаке.
### Создать БД для тестов: выполнить pgbench -i postgres
```
> psql -c 'create database pgtest'
```
Запустим pgbench:
```
> pgbench -i pgtest
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
done in 1.17 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.87 s, vacuum 0.03 s, primary keys 0.26 s).
```
### Запустить pgbench -c8 -P 6 -T 60 -U postgres postgres
```
> pgbench -c8 -P 6 -T 60 -U postgres pgtest
pgbench (15.7)
starting vacuum...end.
progress: 6.0 s, 712.5 tps, lat 11.186 ms stddev 8.251, 0 failed
progress: 12.0 s, 590.5 tps, lat 13.506 ms stddev 16.148, 0 failed
progress: 18.0 s, 615.5 tps, lat 13.039 ms stddev 11.282, 0 failed
progress: 24.0 s, 773.3 tps, lat 10.336 ms stddev 6.909, 0 failed
progress: 30.0 s, 750.7 tps, lat 10.489 ms stddev 8.597, 0 failed
progress: 36.0 s, 717.2 tps, lat 11.329 ms stddev 19.217, 0 failed
progress: 42.0 s, 605.0 tps, lat 13.205 ms stddev 13.245, 0 failed
progress: 48.0 s, 624.7 tps, lat 12.826 ms stddev 11.245, 0 failed
progress: 54.0 s, 697.7 tps, lat 11.466 ms stddev 8.310, 0 failed
progress: 60.0 s, 669.7 tps, lat 11.924 ms stddev 8.498, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 40548
number of failed transactions: 0 (0.000%)
latency average = 11.836 ms
latency stddev = 11.722 ms
initial connection time = 15.283 ms
tps = 675.625779 (without initial connection time)
```
### Применить параметры настройки PostgreSQL из прикрепленного к материалам занятия файла
Применим настройки:
```
max_connections = 40 # максимальное число подключиений
shared_buffers = 1GB # размер буфферного кэша под страницы
effective_cache_size = 3GB # эффиктивный размер кэша диска
maintenance_work_mem = 512MB # влияет на рабочие процессы постгри (например автовакуум)
checkpoint_completion_target = 0.9 # Задаёт целевое время для завершения процедуры контрольной точки, как коэффициент для общего времени между контрольными точками. 
wal_buffers = 16MB # буффер для wal
default_statistics_target = 500 # планировщик будет более точнее
random_page_cost = 4 # стоимость для планировщика рандомного чтения (в принципе у нас network-ssd с SLA R=W iops/read можно ставить что то вроде 1.1)
effective_io_concurrency = 2 #  Number of simultaneous requests that can be handled efficiently by the disk subsystem для SSD можно поставить и по больше
work_mem = 6553kB # рабочая память для процессса 
min_wal_size = 4GB # размер вал лога
max_wal_size = 16GB # какой то суицид на разделе с 10G ;]
```

Пересоздадим кластер и проверим настройки:

```
postgres=# select sourcefile,name,setting,applied from pg_file_settings ;
                 sourcefile                  |             name             |                setting                 | applied 
---------------------------------------------+------------------------------+----------------------------------------+---------
 /etc/postgresql/15/main/postgresql.conf     | data_directory               | /opt/pgdata/15/main                    | t
 /etc/postgresql/15/main/postgresql.conf     | hba_file                     | /etc/postgresql/15/main/pg_hba.conf    | t
 /etc/postgresql/15/main/postgresql.conf     | ident_file                   | /etc/postgresql/15/main/pg_ident.conf  | t
 /etc/postgresql/15/main/postgresql.conf     | external_pid_file            | /var/run/postgresql/15-main.pid        | t
 /etc/postgresql/15/main/postgresql.conf     | port                         | 5432                                   | t
 /etc/postgresql/15/main/postgresql.conf     | max_connections              | 100                                    | f
 /etc/postgresql/15/main/postgresql.conf     | unix_socket_directories      | /var/run/postgresql                    | t
 /etc/postgresql/15/main/postgresql.conf     | ssl                          | on                                     | t
 /etc/postgresql/15/main/postgresql.conf     | ssl_cert_file                | /etc/ssl/certs/ssl-cert-snakeoil.pem   | t
 /etc/postgresql/15/main/postgresql.conf     | ssl_key_file                 | /etc/ssl/private/ssl-cert-snakeoil.key | t
 /etc/postgresql/15/main/postgresql.conf     | shared_buffers               | 128MB                                  | f
 /etc/postgresql/15/main/postgresql.conf     | dynamic_shared_memory_type   | posix                                  | t
 /etc/postgresql/15/main/postgresql.conf     | max_wal_size                 | 1GB                                    | f
 /etc/postgresql/15/main/postgresql.conf     | min_wal_size                 | 80MB                                   | f
 /etc/postgresql/15/main/postgresql.conf     | log_line_prefix              | %m [%p] %q%u@%d                        | t
 /etc/postgresql/15/main/postgresql.conf     | log_timezone                 | Etc/UTC                                | t
 /etc/postgresql/15/main/postgresql.conf     | cluster_name                 | 15/main                                | t
 /etc/postgresql/15/main/postgresql.conf     | datestyle                    | iso, mdy                               | t
 /etc/postgresql/15/main/postgresql.conf     | timezone                     | Etc/UTC                                | t
 /etc/postgresql/15/main/postgresql.conf     | lc_messages                  | en_US.UTF-8                            | t
 /etc/postgresql/15/main/postgresql.conf     | lc_monetary                  | en_US.UTF-8                            | t
 /etc/postgresql/15/main/postgresql.conf     | lc_numeric                   | en_US.UTF-8                            | t
 /etc/postgresql/15/main/postgresql.conf     | lc_time                      | en_US.UTF-8                            | t
 /etc/postgresql/15/main/postgresql.conf     | default_text_search_config   | pg_catalog.english                     | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | max_connections              | 40                                     | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | shared_buffers               | 1GB                                    | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | effective_cache_size         | 3GB                                    | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | maintenance_work_mem         | 512MB                                  | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | checkpoint_completion_target | 0.9                                    | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | wal_buffers                  | 16MB                                   | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | default_statistics_target    | 500                                    | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | random_page_cost             | 4                                      | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | effective_io_concurrency     | 2                                      | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | min_wal_size                 | 4GB                                    | t
 /etc/postgresql/15/main/conf.d/pgbench.conf | max_wal_size                 | 16GB                                   | t
(35 rows)

Все настройки из конфигурации применились
```

### Протестировать заново
```
postgres=# create database pgtest;
CREATE DATABASE
\q

> pgbench -i pgtest
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
done in 1.16 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.86 s, vacuum 0.06 s, primary keys 0.24 s).

> pgbench -c8 -P 6 -T 60 -U postgres pgtest
pgbench (15.7 (Ubuntu 15.7-1.pgdg22.04+1))
starting vacuum...end.
progress: 6.0 s, 467.7 tps, lat 16.982 ms stddev 21.905, 0 failed
progress: 12.0 s, 712.7 tps, lat 11.262 ms stddev 9.734, 0 failed
progress: 18.0 s, 798.0 tps, lat 10.004 ms stddev 6.616, 0 failed
progress: 24.0 s, 713.3 tps, lat 11.235 ms stddev 9.045, 0 failed
progress: 30.0 s, 599.3 tps, lat 13.342 ms stddev 10.208, 0 failed
progress: 36.0 s, 455.0 tps, lat 17.556 ms stddev 22.433, 0 failed
progress: 42.0 s, 611.7 tps, lat 13.093 ms stddev 10.396, 0 failed
progress: 48.0 s, 649.3 tps, lat 12.308 ms stddev 8.993, 0 failed
progress: 54.0 s, 637.0 tps, lat 12.558 ms stddev 10.202, 0 failed
progress: 60.0 s, 468.8 tps, lat 17.072 ms stddev 11.934, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 36685
number of failed transactions: 0 (0.000%)
latency average = 13.083 ms
latency stddev = 12.566 ms
initial connection time = 16.006 ms
tps = 611.307141 (without initial connection time)
```
### Что изменилось и почему?
Результаты сравнимы. 
Мы уперлись в дисковую подсистему, к сожалению диски на яндексе ограничены iops, поэтому заметного изменения производительности мы не получили.
### Создать таблицу с текстовым полем и заполнить случайными или сгенерированными данным в размере 1млн строк
```sql
CREATE TABLE text_table (
    id SERIAL PRIMARY KEY,
    text TEXT
);

postgres=# INSERT INTO text_table
SELECT id, random()::TEXT
FROM generate_series(1, 1000000) AS id;
INSERT 0 1000000
```
### Посмотреть размер файла с таблицей
```
postgres=# SELECT pg_size_pretty(pg_total_relation_size('text_table'));
 pg_size_pretty 
----------------
 72 MB
(1 row)
```
### 5 раз обновить все строчки и добавить к каждой строчке любой символ
```
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
```
### Посмотреть количество мертвых строчек в таблице и когда последний раз приходил автовакуум
```
postgres=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_tables WHERE relname = 'text_table';
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum        
------------+------------+------------+--------+-------------------------------
 text_table |    1000000 |    4158974 |    415 | 2024-11-09 17:49:25.751215+00
(1 row)
```
### Подождать некоторое время, проверяя, пришел ли автовакуум
```
postgres=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_tables WHERE relname = 'text_table';
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum        
------------+------------+------------+--------+-------------------------------
 text_table |    1000000 |          0 |      0 | 2024-11-09 17:55:44.431245+00
```
### 5 раз обновить все строчки и добавить к каждой строчке любой символ
```
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
```
### Посмотреть размер файла с таблицей
```
postgres=# SELECT pg_size_pretty(pg_total_relation_size('text_table'));
 pg_size_pretty 
----------------
 520 MB
(1 row)
```
### Отключить Автовакуум на конкретной таблице
```
postgres=# alter table text_table set (autovacuum_enabled=off);
ALTER TABLE
```
### 10 раз обновить все строчки и добавить к каждой строчке любой символ
```
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
postgres=# update text_table SET text = random()::TEXT || '1';
UPDATE 1000000
```
### Посмотреть размер файла с таблицей
```sql
SELECT pg_size_pretty(pg_total_relation_size('text_table'));
postgres=# SELECT pg_size_pretty(pg_total_relation_size('text_table'));
 pg_size_pretty 
----------------
 957 MB
(1 row)
```
### Объясните полученный результат
При отключенном автовакууме tuples не освобождаются, следовательно не возвращаются в пул для переиспользования.
Приходится создавать новые - что приводит к росту размера файла с таблицей.
### Не забудьте включить автовакуум
```
postgres=# alter table text_table set (autovacuum_enabled=on);
ALTER TABLE
```
### Задание со *: Написать анонимную процедуру, в которой в цикле 10 раз обновятся все строчки в искомой таблице. Не забыть вывести номер шага цикла.
```sql
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        update text_table SET text = gen_random_uuid() || '1';
        RAISE NOTICE 'Номер шага: ', i;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```