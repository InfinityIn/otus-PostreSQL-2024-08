# Домашнее задание по уроку №10
Блокировки

## Чек-лист домашнего задания:
### 1. Настройте сервер так, чтобы в журнал сообщений сбрасывалась информация о блокировках, удерживаемых более 200 миллисекунд. 
```sql
postgres=# select * from pg_settings where name='deadlock_timeout' \gx
-[ RECORD 1 ]---+--------------------------------------------------------------
name            | deadlock_timeout
setting         | 1000
unit            | ms
category        | Lock Management
short_desc      | Sets the time to wait on a lock before checking for deadlock.
extra_desc      | 
context         | superuser
vartype         | integer
source          | default
min_val         | 1
max_val         | 2147483647
enumvals        | 
boot_val        | 1000
reset_val       | 1000
sourcefile      | 
sourceline      | 
pending_restart | f

postgres=# alter system set deadlock_timeout to 200;
ALTER SYSTEM

postgres=# select pg_reload_conf()
;
 pg_reload_conf 
----------------
 t
(1 row)

postgres=# show deadlock_timeout ;
 deadlock_timeout 
------------------
 200ms
(1 row)
```
### Воспроизведите ситуацию, при которой в журнале появятся такие сообщения.
```sql
-- session 1;
postgres=# \c test 
You are now connected to database "test" as user "admin".
test=# CREATE TABLE text_table (
    id SERIAL PRIMARY KEY,
    text TEXT
);
CREATE TABLE
test=# INSERT INTO text_table
SELECT id, MD5(random()::TEXT)::TEXT
FROM generate_series(1, 1000000) AS id;
INSERT 0 1000000
test=# select * from text_table limit 5;
 id |               text               
----+----------------------------------
  1 | 0a02563b601fcb2c42846f2eaf63ac8a
  2 | 909489dd68827d1c48528dddb8414813
  3 | 442a981e07c4518b95e3b6b9f3d56645
  4 | 7119ba6e7c9f09482cb77964c7daf41c
  5 | ba6f1f664467caefc4b5a84518b95e33
(5 rows)

test=# begin; 
update text_table SET text = 'text' where id = 1;
BEGIN
UPDATE 1

-- session 2

test=# vacuum FULL text_table ;

2024-11-11 12:19:03.344 UTC [112] LOG:  process 112 still waiting for AccessExclusiveLock on relation 14160 of database 14163 after 200.070 ms
2024-11-11 12:19:03.344 UTC [112] DETAIL:  Process holding the lock: 90. Wait queue: 112.
2024-11-11 12:19:03.344 UTC [112] STATEMENT:  vacuum FULL text_table ;
2024-11-11 12:20:01.864 UTC [112] LOG:  process 112 acquired AccessExclusiveLock on relation 14160 of database 14163 after 47488.114 ms
2024-11-11 12:20:01.864 UTC [112] STATEMENT:  vacuum FULL text_table ;
```
### 2. Смоделируйте ситуацию обновления одной и той же строки тремя командами UPDATE в разных сеансах. Изучите возникшие блокировки в представлении pg_locks и убедитесь, что все они понятны. Пришлите список блокировок и объясните, что значит каждая.
```sql
-- session 1
begin; 
update text_table SET text = 'test1' where id=2;

-- session 2
begin; 
update text_table SET text = 'test2' where id=2;

-- session 3
begin; 
update text_table SET text = 'test3' where id=2;

Из лога постгри:

2024-11-11 12:25:11.547 UTC [112] LOG:  process 112 still waiting for ShareLock on transaction 778 after 200.143 ms
2024-11-11 12:25:11.547 UTC [112] DETAIL:  Process holding the lock: 90. Wait queue: 112.
2024-11-11 12:25:11.547 UTC [112] CONTEXT:  while updating tuple (0,1) in relation "text_table"
2024-11-11 12:25:11.547 UTC [112] STATEMENT:  update text_table SET text = 'test2' where id=2;
2024-11-11 12:25:52.547 UTC [122] STATEMENT:  update text_table SET text = 'test3' where id=2;
2024-11-11 12:25:56.547 UTC [125] LOG:  process 125 still waiting for ExclusiveLock on tuple (0,1) of relation 14160 of database 14163 after 200.148 ms
2024-11-11 12:25:56.547 UTC [125] DETAIL:  Process holding the lock: 112. Wait queue: 125.
2024-11-11 12:25:56.547 UTC [125] STATEMENT:  update text_table SET text = 'test3' where id=2;

test=# select pg_blocking_pids(112);
 pg_blocking_pids 
------------------
 {90}
(1 row)

test=# select pg_blocking_pids(125);
 pg_blocking_pids 
------------------
 {112}
(1 row)


test=# select 'text_table'::regclass::int;
 int4  
-------
 14160
(1 row)

test=# select 16416::regclass;
    regclass     
-----------------
 text_table_pkey
(1 row)


postgres=# select locktype,database,relation,page,tuple,transactionid,virtualtransaction,pid,mode,granted,fastpath from pg_locks where pid in (90,112,125)  order by pid ;
   locktype    | database | relation | page | tuple | transactionid | virtualtransaction | pid |       mode       | granted | fastpath 
---------------+----------+----------+------+-------+---------------+--------------------+-----+------------------+---------+----------
 relation      |    14163 |    14160 |      |       |               | 6/91               |  90 | RowExclusiveLock | t       | t
 transactionid |          |          |      |       |           778 | 6/91               |  90 | ExclusiveLock    | t       | f
 virtualxid    |          |          |      |       |               | 6/91               |  90 | ExclusiveLock    | t       | t
 relation      |    14163 |    16416 |      |       |               | 6/91               |  90 | RowExclusiveLock | t       | t
 relation      |    14163 |    14160 |      |       |               | 5/187              | 112 | RowExclusiveLock | t       | t
 relation      |    14163 |    16416 |      |       |               | 5/187              | 112 | RowExclusiveLock | t       | t
 virtualxid    |          |          |      |       |               | 5/187              | 112 | ExclusiveLock    | t       | t
 transactionid |          |          |      |       |           778 | 5/187              | 112 | ShareLock        | f       | f
 transactionid |          |          |      |       |           779 | 5/187              | 112 | ExclusiveLock    | t       | f
 tuple         |    14163 |    14160 |    0 |     1 |               | 5/187              | 112 | ExclusiveLock    | t       | f
 virtualxid    |          |          |      |       |               | 7/2                | 125 | ExclusiveLock    | t       | t
 transactionid |          |          |      |       |           780 | 7/2                | 125 | ExclusiveLock    | t       | f
 relation      |    14163 |    16416 |      |       |               | 7/2                | 125 | RowExclusiveLock | t       | t
 relation      |    14163 |    14160 |      |       |               | 7/2                | 125 | RowExclusiveLock | t       | t
 tuple         |    14163 |    14160 |    0 |     1 |               | 7/2                | 125 | ExclusiveLock    | f       | f
```
Далее, подробнее: 
#### а) Транзакция обновила tuple, возникла эксклюзивная блокировка для нашей таблицы и её ключа
```
 relation      |    14163 |    14160 |      |       |               | 6/91               |  90 | RowExclusiveLock | t       | t
 relation      |    14163 |    16416 |      |       |               | 6/91               |  90 | RowExclusiveLock | t       | t
```
Эксклюзивная блокировка транзакции самой на себя по xid и vxid
```
 virtualxid    |          |          |      |       |               | 6/91               |  90 | ExclusiveLock    | t       | t
```
Исключительная блокировка реального номера транзакции
```
 transactionid |          |          |      |       |           778 | 6/91               |  90 | ExclusiveLock    | t       | f
```
#### б) Получила эксклюзивную блокировку для целевой таблицы и ключа
```
 relation      |    14163 |    14160 |      |       |               | 5/187              | 112 | RowExclusiveLock | t       | t
 relation      |    14163 |    16416 |      |       |               | 5/187              | 112 | RowExclusiveLock | t       | t
```
Эксклюзивная блокировка транзакции самой на себя по xid и vxid
```
 virtualxid    |          |          |      |       |               | 5/187              | 112 | ExclusiveLock    | t       | t
```
Исключительная блокировка настоящего номера транзакции
```
 transactionid |          |          |      |       |           779 | 5/187              | 112 | ExclusiveLock    | t       | f
```
Эксклюзивная блокировка версии строки для обновления 
```
 tuple         |    14163 |    14160 |    0 |     1 |               | 5/187              | 112 | ExclusiveLock    | t       | f
```
Установка ShareLock раздельной блокировки на строку, заблокировавшую транзакцию 
```
 transactionid |          |          |      |       |           778 | 5/187              | 112 | ShareLock        | f       | f
```

test=# SELECT * FROM pgrowlocks('text_table') \gx
-[ RECORD 1 ]-----------------
locked_row | (0,1)
locker     | 778
multi      | f
xids       | {778}
modes      | {"No Key Update"}
pids       | {90}

#### в) Экслюзивная блокировка транзакции самой на себя xid и vxid
```
 virtualxid    |          |          |      |       |               | 7/2                | 125 | ExclusiveLock    | t       | t
```
Исключительная блокировка настоящего номера транзакции
```
 transactionid |          |          |      |       |           780 | 7/2                | 125 | ExclusiveLock    | t       | f
```
Получение эксклюзивной блокировки для нашей таблицы и ключа
```
 relation      |    14163 |    16416 |      |       |               | 7/2                | 125 | RowExclusiveLock | t       | t
 relation      |    14163 |    14160 |      |       |               | 7/2                | 125 | RowExclusiveLock | t       | t
```
Эксклюзивная блокировка версии строки для обновления не удалась  
```
 tuple         |    14163 |    14160 |    0 |     1 |               | 7/2                | 125 | ExclusiveLock    | f       | f
```

Другой вариант представления
```sql
test=# SELECT locktype, mode, granted, pid, pg_blocking_pids(pid) AS wait_for FROM pg_locks WHERE relation = 'text_table'::regclass order by pid;
 locktype |       mode       | granted | pid | wait_for 
----------+------------------+---------+-----+----------
 relation | RowExclusiveLock | t       |  90 | {}
 relation | RowExclusiveLock | t       | 112 | {90}
 tuple    | ExclusiveLock    | t       | 112 | {90}
 relation | RowExclusiveLock | t       | 125 | {112}
 tuple    | ExclusiveLock    | f       | 125 | {112}
```
### 3. Воспроизведите взаимоблокировку трех транзакций. Можно ли разобраться в ситуации постфактум, изучая журнал сообщений?
```sql
-- session 1
>begin; update text_table SET text = text || 'test1' where id=1;
BEGIN
UPDATE 1
-- session 2
>begin; update text_table SET text = text || 'test2' where id=2;
BEGIN
UPDATE 1
-- session 3
>begin; update text_table SET text = text || 'test3' where id=3;
BEGIN
UPDATE 1
```
Затем, 
```sql
-- session 1
>update text_table SET text = text || 'test1' where id=2;
-- session 2
>update text_table SET text = text || 'test2' where id=3;
-- session 3
>update text_table SET text = text || 'test3' where id=1;
ERROR:  deadlock detected
DETAIL:  Process 125 waits for ShareLock on transaction 788; blocked by process 90.
Process 90 waits for ShareLock on transaction 789; blocked by process 112.
Process 112 waits for ShareLock on transaction 790; blocked by process 125.
HINT:  See server log for query details.
CONTEXT:  while updating tuple (8333,40) in relation "text_table"

2024-11-11 13:12:01.678 UTC [90] LOG:  process 90 still waiting for ShareLock on transaction 789 after 200.107 ms
2024-11-11 13:12:01.678 UTC [90] DETAIL:  Process holding the lock: 112. Wait queue: 90.
2024-11-11 13:12:01.678 UTC [90] CONTEXT:  while updating tuple (8333,44) in relation "text_table"
2024-11-11 13:12:01.678 UTC [90] STATEMENT:  update text_table SET text = text || 'test1' where id=2;
2024-11-11 13:12:11.112 UTC [112] LOG:  process 112 still waiting for ShareLock on transaction 790 after 201.464 ms
2024-11-11 13:12:11.112 UTC [112] DETAIL:  Process holding the lock: 125. Wait queue: 112.
2024-11-11 13:12:11.112 UTC [112] CONTEXT:  while updating tuple (0,2) in relation "text_table"
2024-11-11 13:12:11.112 UTC [112] STATEMENT:  update text_table SET text = text || 'test2' where id=3;
2024-11-11 13:12:24.314 UTC [125] LOG:  process 125 detected deadlock while waiting for ShareLock on transaction 788 after 200.180 ms
2024-11-11 13:12:24.314 UTC [125] DETAIL:  Process holding the lock: 90. Wait queue: .
2024-11-11 13:12:24.314 UTC [125] CONTEXT:  while updating tuple (8333,40) in relation "text_table"
2024-11-11 13:12:24.314 UTC [125] STATEMENT:  update text_table SET text = text || 'test3' where id=1;
2024-11-11 13:12:24.314 UTC [125] ERROR:  deadlock detected
2024-11-11 13:12:24.314 UTC [125] DETAIL:  Process 125 waits for ShareLock on transaction 788; blocked by process 90.
	Process 90 waits for ShareLock on transaction 789; blocked by process 112.
	Process 112 waits for ShareLock on transaction 790; blocked by process 125.
	Process 125: update text_table SET text = text || 'test3' where id=1;
	Process 90: update text_table SET text = text || 'test1' where id=2;
	Process 112: update text_table SET text = text || 'test2' where id=3;
2024-11-11 13:12:24.314 UTC [125] HINT:  See server log for query details.
2024-11-11 13:12:24.314 UTC [125] CONTEXT:  while updating tuple (8333,40) in relation "text_table"
2024-11-11 13:12:24.314 UTC [125] STATEMENT:  update text_table SET text = text || 'test3' where id=1;
2024-11-11 13:12:24.314 UTC [112] LOG:  process 112 acquired ShareLock on transaction 790 after 8732.124 ms
2024-11-11 13:12:24.314 UTC [112] CONTEXT:  while updating tuple (0,2) in relation "text_table"
2024-11-11 13:12:24.314 UTC [112] STATEMENT:  update text_table SET text = text || 'test2' where id=3;
```
Восстановить картину происходящего постфактум сложно, особенно учитывая обстоятельства реального сервера на продуктиве

### 4. Могут ли две транзакции, выполняющие единственную команду UPDATE одной и той же таблицы (без where), заблокировать друг друга?
Вполне, на ум приходит несколько способов
### Задание со звездочкой* Попробуйте воспроизвести такую ситуацию.
Вот один из них

Сделаем так, чтобы работа транзакций заключалась в обработке одних и тех же строк, но в разном порядке.
```sql
-- session 1
UPDATE text_table set text = (select text from text_table order by id limit 1 for update);

--session 2
UPDATE text_table set text = (select text from text_table order by id desc limit 1 for update);
```

Вот, что получилось:
```sql
-- session 1
>UPDATE text_table set text = (select text from text_table order by id limit 1 for update);
ERROR:  deadlock detected
DETAIL:  Process 90 waits for ShareLock on transaction 855; blocked by process 112.
Process 112 waits for ShareLock on transaction 854; blocked by process 90.
HINT:  See server log for query details.
CONTEXT:  while updating tuple (13092,117) in relation "text_table"

-- session 2
> UPDATE text_table set text = (select text from text_table order by id desc limit 1 for update);
UPDATE 1000000
```

Логи:

```sql
2024-11-11 14:15:02.441 UTC [112] LOG:  process 112 still waiting for ShareLock on transaction 856 after 200.126 ms
2024-11-11 14:15:02.441 UTC [112] DETAIL:  Process holding the lock: 90. Wait queue: 112.
2024-11-11 14:15:02.441 UTC [112] CONTEXT:  while updating tuple (17440,1) in relation "text_table"
2024-11-11 14:15:02.441 UTC [112] STATEMENT:  UPDATE text_table set text = (select text from text_table order by id desc limit 1 for update);
2024-11-11 14:15:02.933 UTC [90] LOG:  process 90 detected deadlock while waiting for ShareLock on transaction 857 after 200.128 ms
2024-11-11 14:15:02.933 UTC [90] DETAIL:  Process holding the lock: 112. Wait queue: .
2024-11-11 14:15:02.933 UTC [90] CONTEXT:  while updating tuple (18778,37) in relation "text_table"
2024-11-11 14:15:02.933 UTC [90] STATEMENT:  UPDATE text_table set text = (select text from text_table order by id limit 1 for update);
2024-11-11 14:15:02.933 UTC [90] ERROR:  deadlock detected
2024-11-11 14:15:02.933 UTC [90] DETAIL:  Process 90 waits for ShareLock on transaction 857; blocked by process 112.
	Process 112 waits for ShareLock on transaction 856; blocked by process 90.
	Process 90: UPDATE text_table set text = (select text from text_table order by id limit 1 for update);
	Process 112: UPDATE text_table set text = (select text from text_table order by id desc limit 1 for update);
2024-11-11 14:15:02.933 UTC [90] HINT:  See server log for query details.
2024-11-11 14:15:02.933 UTC [90] CONTEXT:  while updating tuple (18778,37) in relation "text_table"
2024-11-11 14:15:02.933 UTC [90] STATEMENT:  UPDATE text_table set text = (select text from text_table order by id limit 1 for update);
2024-11-11 14:15:02.933 UTC [112] LOG:  process 112 acquired ShareLock on transaction 856 after 655.386 ms
2024-11-11 14:15:02.933 UTC [112] CONTEXT:  while updating tuple (17440,1) in relation "text_table"
2024-11-11 14:15:02.933 UTC [112] STATEMENT:  UPDATE text_table set text = (select text from text_table order by id desc limit 1 for update);
```