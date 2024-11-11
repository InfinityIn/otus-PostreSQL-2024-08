# Домашнее задание по уроку №11
Нагрузочное тестирование и тюнинг

## Чек-лист домашнего задания:
### развернуть виртуальную машину любым удобным способом
Продолжаем работать в Яндекс.Облаке
### поставить на неё PostgreSQL 15 любым способом
На базовых настройках выполним нагрузку, чтобы было, с чем сравнивать
```sql
postgres=# create database bgbench
CREATE DATABASE

> pgbench -i bgbench
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
done in 0.4 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.22 s, vacuum 0.04 s, primary keys 0.14 s).

> pgbench -c 40 -j 2 -P 10 -T 60 bgbench
pgbench (15.7 (Ubuntu 15.7-1.pgdg22.04+1))
starting vacuum...end.
progress: 10.0 s, 552.0 tps, lat 73.721 ms stddev 53.453, 0 failed
progress: 20.0 s, 546.7 tps, lat 74.522 ms stddev 54.783, 0 failed
progress: 30.0 s, 512.4 tps, lat 79.654 ms stddev 72.128, 0 failed
progress: 40.0 s, 588.5 tps, lat 69.328 ms stddev 59.853, 0 failed
progress: 50.0 s, 555.1 tps, lat 72.843 ms stddev 49.749, 0 failed
progress: 60.0 s, 488.3 tps, lat 83.349 ms stddev 70.624, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 40
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 32391
number of failed transactions: 0 (0.000%)
latency average = 72.467 ms
latency stddev = 62.725 ms
initial connection time = 56.411 ms
tps = 515.887254 (without initial connection time)
```
### настроить кластер PostgreSQL 15 на максимальную производительность не обращая внимание на возможные проблемы с надежностью в случае аварийной перезагрузки виртуальной машины
Пришёл к следующим настройкам:
```
max_connections = 40
shared_buffers = 1GB # Для быстродейтсвия, память быстрее диска.
effective_cache_size = 3GB 
maintenance_work_mem = 256MB
checkpoint_completion_target = 0.9 # Максимально растянуть чекпоинт по времени
wal_buffers = 16MB # Отправляем в память
default_statistics_target = 150 # Эффективность статистики
random_page_cost = 1.1 
effective_io_concurrency = 200 # Запросы можем слать в несколько потоков
work_mem = 13107kB # В зависимости от количества подключений можно увеличить work_mem - операции станут быстрее
huge_pages = off
min_wal_size = 1GB
max_wal_size = 4GB
```
Далее, в соответствии с условиями задания - пренебрежение надёжности и долговечности - изменим следующие настройки:
```
data_checksums # Проверяем, что отключено
synchronous_commit = off # Отключаем синхронную запись WAL на диск
fsync = off # Отключим синхронизацию с диском
wal_level = minimal # Туда же
checkpoint_timeout = 30min # Редкие чекпоинты - меньше ресурсов на обработку
full_page_writes = off
max_wal_senders = 0
```
### нагрузить кластер через утилиту через утилиту pgbench (https://postgrespro.ru/docs/postgrespro/14/pgbench)
```sql
> pgbench -i bgbench
dropping old tables...
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.07 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.15 s (drop tables 0.01 s, create tables 0.00 s, client-side generate 0.06 s, vacuum 0.04 s, primary keys 0.04 s).

> pgbench -c 40 -j 2 -P 10 -T 60 bgbench
pgbench (15.7)
starting vacuum...end.
progress: 10.0 s, 2088.0 tps, lat 18.785 ms stddev 11.724, 0 failed
progress: 20.0 s, 2115.4 tps, lat 18.453 ms stddev 10.354, 0 failed
progress: 30.0 s, 2179.6 tps, lat 18.782 ms stddev 10.745, 0 failed
progress: 40.0 s, 2129.7 tps, lat 18.435 ms stddev 10.852, 0 failed
progress: 50.0 s, 2200.3 tps, lat 18.782 ms stddev 11.954, 0 failed
progress: 60.0 s, 2198.2 tps, lat 18.452 ms stddev 11.756, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 40
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 128895
number of failed transactions: 0 (0.000%)
latency average = 18.984 ms
latency stddev = 11.112 ms
initial connection time = 58.984 ms
tps = 2151.654145 (without initial connection time)
```
### написать какого значения tps удалось достичь, показать какие параметры в какие значения устанавливали и почему
Получили рост с  tps = 515.887254 до tps = 2151.654145

Такие показатели достигнуты из-за достаточно высокого снижения надёжности и долговечности. В основом - записи WAL и синхронизации его с диском.

Выводы: в реалии продуктивных сред параметры надёжности и долговечности играют важную роль, поэтому отказываться от них нельзя. 
Полученные знания я бы использовал на тестовых контурах в своих проектах для сопоставления с продуктивной средой, которая значительно выигрывает в ресурсах.

### Задание со звёздочкой пока пропущу