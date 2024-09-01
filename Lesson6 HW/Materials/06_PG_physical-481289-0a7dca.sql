-- Создаем сетевую инфраструктуру и саму VM:
yc vpc network create --name otus-net --description "otus-net" && \
yc vpc subnet create --name otus-subnet --range 192.168.0.0/24 --network-name otus-net --description "otus-subnet" && \
yc compute instance create --name otus-vm --hostname otus-vm --cores 2 --memory 4 --create-boot-disk size=15G,type=network-hdd,image-folder-id=standard-images,image-family=ubuntu-2004-lts --network-interface subnet-name=otus-subnet,nat-ip-version=ipv4 --ssh-key ~/.ssh/yc_key.pub 

-- Подключимся к VM:
vm_ip_address=$(yc compute instance show --name otus-vm | grep -E ' +address' | tail -n 1 | awk '{print $2}') && ssh -o StrictHostKeyChecking=no -i ~/.ssh/yc_key yc-user@$vm_ip_address 

-- Установим PostgreSQL:
sudo apt update && sudo apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt -y install postgresql-14 

pg_lsclusters

sudo nano /etc/postgresql/14/main/postgresql.conf
sudo nano /etc/postgresql/14/main/pg_hba.conf

sudo -u postgres psql
alter user postgres password 'postgres';

sudo pg_ctlcluster 14 main restart

yc compute instances list - 192.168.0.33 (i), 89.169.152.145 (e)

yc compute instance delete otus-vm && yc vpc subnet delete otus-subnet && yc vpc network delete otus-net

/* Открываем наш порт
sudo firewall-cmd --zone=public --add-port=5432/tcp
sudo firewall-cmd --zone=public --permanent --add-port=5432/tcp
sudo firewall-cmd --zone=public --list-ports

sudo systemctl restart firewalld.service
sudo systemctl -l status firewalld.service
*/

-- Посмотрим на пользователей Linux:
cat /etc/passwd
cut -d: -f1 /etc/passwd
awk -F: '{ print $1 }' /etc/passwd

-- Посмотрим на наши сетевые подклбчения:
ss -tlpn
sudo apt install net-tools && netstat -a | grep postgresql

/*
В файле pg_hba.conf в записи host all all 192.168.1.100/32 md5 число 32 после IP-адреса обозначает длину префикса подсети (CIDR нотация). В данном случае /32 указывает на то, что это конкретный IP-адрес 192.168.1.100, так как длина префикса равна 32 битам, что означает, что все биты IP-адреса совпадают с указанным адресом.
CIDR нотация используется для указания диапазона IP-адресов в виде адреса с префиксом. Например, /24 означает первые 24 бита адреса являются сетевой частью, а оставшиеся биты - хостовой частью.
В данном случае /32 указывает на один конкретный IP-адрес без возможности подсети или диапазона адресов.
*/

-- Посмотрим файлы PostgreSQL:
sudo su postgres
cd /var/lib/postgresql/14/main
ls -la

sudo -u postgres psql
-- sudo su postgres
-- psql

-- Как посмотреть конфигурационные файлы?
show hba_file;
show config_file;
show data_directory;

-- Все параметры (как думаете сколько у нас параметров для настроек?:):
show all;
-- context
-- postmaster - перезапуск инстанса
-- sighup - во время работы
select name, setting, context, short_desc from pg_settings;

192.168.0.12
85.192.189.175


-- open access
show listen_addresses;
alter system set listen_addresses = 'localhost, 192.168.0.22'; -- создает в /var/lib/postgresql postgresql.auto.conf с параметрами

-- uncomment listen_addresses = 'localhost, 192.168.0.22'
sudo nano /etc/postgresql/14/main/postgresql.conf

-- Посмотрим на свой ip для доутспа в интернет: (в данном случае это динамический ip от провайдера)
curl ifconfig.me
dig +short myip.opendns.com @resolver1.opendns.com

-- host    all             all             0.0.0.0/0               md5/scram-sha-256
sudo nano /etc/postgresql/14/main/pg_hba.conf

-- change password
alter user postgres password 'postgres';

-- restart server
sudo pg_ctlcluster 14 main restart

-- try access
psql -p 5432 -U postgres -h 89.169.152.145 -d postgres -W

-- Использование linux команд:
\! pwd
\! ls -la

Расширенный вывод информации - вертикальный вывод колонок
select * from pg_stat_activity;
\x

select * from pg_stat_activity \gx

-- Постранично
psql -c "select * from pg_stat_activity" postgres | less


-- Отображает фактические запросы, генерируемые \d и другими командами, начинающимися с \. Это можно использовать для изучения внутренних операций в psql.
\set ECHO_HIDDEN on
\l
\set ECHO_HIDDEN off

-- Посмотрим историю psql команд:
sudo su postgres
cat ~/.psql_history

-- Конфигурация утилиты psql: (https://www.8host.com/blog/nastrojka-komandnoj-stroki-postgresql-c-pomoshhyu-psqlrc-v-ubuntu-14-04/)
sudo -u postgres psql
\set PROMPT1 '%M:%> %n@%/%R%#%x '
\set PROMPT1 '%033[1;31m%]%M:%[%033[0m%[%033[1;32m%]%>%[%033[0m%] %n@%/%R%#%x ' 


-- Поподробнее из psql:
# select pg_backend_pid();
# select inet_client_addr();
# select inet_client_port();
# select inet_server_addr();
# select inet_server_port();
# select datid, datname, pid, usename, application_name, client_addr, backend_xid from pg_stat_activity;

/*
fork() - это системный вызов в операционной системе Linux (и других UNIX-подобных системах), который используется для создания нового процесса. При вызове fork(), текущий процесс делится на два процесса: родительский процесс и дочерний процесс. Оба процесса начинают выполнение с точно такого же состояния, что включает в себя код, данные, открытые файлы и другие ресурсы.

Родительский процесс продолжает выполнение после вызова fork(), но возвращает идентификатор дочернего процесса (PID), который равен 0 внутри дочернего процесса. Таким образом, после вызова fork(), у вас есть два процесса, которые выполняют один и тот же код, но могут иметь разные пути выполнения.

fork() является основой для создания многопроцессорных приложений в UNIX-подобных системах. Дочерний процесс может быть использован для выполнения различных задач, таких как обработка запросов, параллельное выполнение операций и т.д. Важно помнить, что после вызова fork(), оба процесса продолжают работу независимо друг от друга и могут иметь свои собственные переменные и ресурсы.

Каждый fork() происходит не мнгновенно - это ресурсы и время, поэтому у PoostgreSQL большая проблема с подключениями (по-умолчанию их 100), и для того чтобы решить эту проблему используют пулеров соединений, например pgPool-II, pgBouncer, odissey (https://docs.selectel.ru/cloud/managed-databases/postgresql/connection-pooler/).
*/

-- Создаем новый диск для ВМ:
yc compute disk-type list

yc compute disk create \
    --name new-disk \
    --type network-hdd \
    --size 5 \
    --description "second disk for otus-vm"

yc compute disk list
yc compute instance list

-- Подключим новый диск к нашей ВМ:
yc compute instance attach-disk otus-vm \
    --disk-name new-disk \
    --mode rw \
    --auto-delete

yc compute instance list

-- Также должен появится новый диск vdb:
sudo lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL

-- Создадим разделы с помощью fdisk.
sudo fdisk /dev/vdb

-- В меню программы fdisk: (чтобы получить список доступных команд, нажмите клавишу M) - нижний регистр!
--     Создайте новый раздел — нажмите N.
--     Укажите, что раздел будет основным — нажмите P.
--     Появится предложение выбрать номер раздела. Нажмите Enter, чтобы создать первый раздел.
--     Номера первого и последнего секторов раздела оставьте по умолчанию — два раза нажмите Enter.
--     Убедитесь, что раздел успешно создан. Для этого нажмите клавишу P и выведите список разделов диска.
--     Для сохранения внесенных изменений нажмите клавишу W.

-- Отформатируем диск в нужную файловую систему, с помощью утилиты mkfs (файловую систему возьмем EXT4):
sudo mkfs.ext4 /dev/vdb1

-- Смонтируем раздел диска vdb1 в папку /mnt/vdb1, с помощью утилиты mount:
sudo mkdir /mnt/vdb1
sudo mount /dev/vdb1 /mnt/vdb1

-- Разрешим запись на диск всем пользователям, с помощью утилиты chmod:
sudo chmod a+w /mnt/vdb1


/*
OOM killer (Out of Memory Killer) - это механизм в ядрах операционных систем Linux, который запускается в случае, когда система сталкивается с нехваткой оперативной памяти (Out of Memory condition). Когда операционная система Linux обнаруживает, что доступная оперативная память исчерпана и больше не может удовлетворить запросы на выделение памяти процессам, она активирует OOM killer.

OOM killer работает следующим образом:
1. Операционная система Linux определяет процесс, который потребляет слишком много оперативной памяти и приводит к нехватке памяти.
2. OOM killer выбирает процесс для прекращения работы и освобождения памяти.
3. Выбранный процесс убивается (kill), чтобы освободить оперативную память для других процессов.
4. После завершения работы OOM killer система продолжает свою работу.
*/

-- Посмотрим на процессы PostgreSQL:
ps -xf

-- Табличное пространство практика:
sudo su postgres
cd /mnt/vdb1
mkdir tmptblspc

create tablespace my_ts location '/mnt/vdb1/tmptblspc';
\db
create database app tablespace my_ts;
\c app
\l+ -- посмотреть дефолтный tablespace
create table test (id int);
insert into test select g.x from generate_series(1, 1000) as g(x);
create table test2 (id int) tablespace pg_default;
insert into test2 select g.x from generate_series(1, 1000) as g(x);
create index idx_test on test(id);
select tablename, tablespace from pg_tables where schemaname = 'public';
alter table test set tablespace pg_default; -- физическое перемещение данных (полная блокировка)
select oid, spcname from pg_tablespace; -- oid унимальный номер, по которому можем найти файлы
select oid, datname, dattablespace from pg_database;
alter table test set tablespace my_ts;

/*
В PostgreSQL временные таблицы могут храниться в различных табличных пространствах. По умолчанию, временные таблицы создаются в специальном схематическом пространстве под названием pg_temp_N, где N - это идентификатор сеанса текущего соединения. Это означает, что каждое соединение к базе данных будет иметь свое собственное временное пространство для временных таблиц.

Когда соединение закрывается, все временные таблицы, созданные в этом пространстве, автоматически удаляются. Это обеспечивает изоляцию данных между различными сеансами и предотвращает конфликты имен временных таблиц.

Если вам нужно создать временную таблицу и сохранить ее содержимое между различными запросами или сеансами, вы можете использовать другие табличные пространства, например, pg_default. В этом случае, временная таблица будет существовать до тех пор, пока ее явно не удалить пользователь.

Итак, по умолчанию временные таблицы хранятся в pg_temp_N, но вы также можете явно указать другое табличное пространство для временных таблиц в PostgreSQL.
*/

-- всегда можем посмотреть, где лежит таблица
select pg_relation_filepath('test');

-- узнать размер, занимаемый базой данных и объектами в ней, можно с помощью ряда функций.
select pg_database_size('app');

-- для упрощения восприятия можно вывести число в отформатированном виде:
select pg_size_pretty(pg_database_size('app'));

-- полный размер таблицы (вместе со всеми индексами):
select pg_size_pretty(pg_total_relation_size('test'));

-- и отдельно размер таблицы...
select pg_size_pretty(pg_table_size('test'));

-- ...и индексов:
select pg_size_pretty(pg_indexes_size('idx_test'));

-- при желании можно узнать и размер отдельных слоев таблицы, например:
select pg_size_pretty(pg_relation_size('test','vm'));

-- размер табличного пространства показывает другая функция:
select pg_size_pretty(pg_tablespace_size('my_ts'));

-- !!!При создании бэкапа нужно чтобы на машине куда мы будем восстанавливаться было уже такое табличное пространство (т.е. его нужно предварительно создать в ФС).


/*
Лучше не создавать из шаблонов т.к.: (выдержка из документации)
CREATE DATABASE завершится с ошибкой, если существует другое активное соединение в момент его запуска; в противном случае, новые соединения с шаблонной базой данных блокируются до завершения операции CREATE DATABASE.
*/

/*
RAID (Redundant Array of Independent Disks) - это технология, которая объединяет несколько физических дисков в одну логическую единицу для повышения производительности, надежности данных или обеих функций. RAID массивы могут быть сконфигурированы по-разному в зависимости от нужд пользователя.

Существует несколько уровней RAID, таких как RAID 0, RAID 1, RAID 5, RAID 10 и другие, каждый из которых имеет свои особенности и преимущества.

Чтобы распараллелить RAID массив, можно использовать технику, называемую "строкирование" (striping). При стрипировании данные записываются на несколько дисков одновременно, что позволяет увеличить скорость чтения и записи данных. Например, в RAID 0 данные разбиваются на блоки и записываются на разные диски, что позволяет увеличить скорость доступа к данным.

Другие уровни RAID, такие как RAID 5 или RAID 10, также используют параллельную запись данных на несколько дисков для обеспечения баланса между производительностью и надежностью хранения данных.
*/

-- Посмотрим на структуру нашего кластера:
\l+ 
select d.datname as "name",
       r.rolname as "owner",
       pg_catalog.pg_encoding_to_char(d.encoding) as "encoding",
       pg_catalog.shobj_description(d.oid, 'pg_database') as "description",
       t.spcname as "tablespace"
from pg_catalog.pg_database d
  join pg_catalog.pg_roles r on d.datdba = r.oid
  join pg_catalog.pg_tablespace t on d.dattablespace = t.oid
order by 1;

-- Зададим переменную для нашего табличного пространства:
select oid as my_ts_oid from pg_tablespace where spcname = 'my_ts' \gset -- \set (список всех наших переменных)
select datname from pg_database where oid in (select pg_tablespace_databases(:my_ts_oid));


-- с дефолтным неймспейсом не все так просто
select count(*) from pg_class where reltablespace = 0;

-- Выполнить команду из файла:
\i /var/lib/postgresql/14/main/s.sql


-- Удаляем ВМ и сети (дополнительный диск удалится автоматически):
yc compute instance delete otus-vm && yc vpc subnet delete otus-subnet && yc vpc network delete otus-net
