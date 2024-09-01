### Домашнее задание по уроку №6
Физический уровень Postgres

## Чек-лист домашнего задания:
### создайте виртуальную машину c Ubuntu 20.04/22.04 LTS в ЯО/Virtual Box/докере
Работаем в ЯО.
### поставьте на нее PostgreSQL 15 через sudo apt
```
sudo apt -y install postgresql-15
```
### проверьте что кластер запущен через sudo -u postgres pg_lsclusters
```
sudo -i -u postgres pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
15  main    5432 online postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log
```
### зайдите из под пользователя postgres в psql и сделайте произвольную таблицу с произвольным содержимым
```
sudo -i -u postgres psql
psql (15.7 (Ubuntu 15.7-1.pgdg22.04+1))
Type "help" for help.

postgres=# 
```
```
postgres=# create table test(c1 text);
postgres=# insert into test values('1');
```
### остановите postgres например через sudo -u postgres pg_ctlcluster 15 main stop
```
sudo -i -u postgres pg_ctlcluster 15 main stop
Warning: stopping the cluster using pg_ctlcluster will mark the systemd unit as failed. Consider using systemctl:
  sudo systemctl stop postgresql@15-main

sudo -i -u postgres pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
15  main    5432 down   postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log
```
### создайте новый диск к ВМ размером 10GB
```
yc compute disk create --size 10 
done (11s)
id: x
folder_id: x
created_at: "2024-06-05T08:20:32Z"
type_id: network-hdd
zone_id: ru-central1-d
size: "10737418240"
block_size: "4096"
status: READY
disk_placement_policy: {}
```
### добавьте свеже-созданный диск к виртуальной машине - надо зайти в режим ее редактирования и дальше выбрать пункт attach existing disk проинициализируйте диск согласно инструкции и подмонтировать файловую систему, только не забывайте менять имя диска на актуальное, в вашем случае это скорее всего будет /dev/sdb - https://www.digitalocean.com/community/tutorials/how-to-partition-and-format-storage-devices-in-linux перезагрузите инстанс и убедитесь, что диск остается примонтированным (если не так смотрим в сторону fstab)
С помощью UI создаём диск и подключаем к виртуалке.
Монтируем файловую систему
Перезапускаем инстанс

Проверяем:
```
df -h /mnt/data/
Filesystem      Size  Used Avail Use% Mounted on
/dev/vdb         10G  104M  9.9G   2% /mnt/data
```
### сделайте пользователя postgres владельцем /mnt/data - chown -R postgres:postgres /mnt/data/
```
sudo chown -R postgres. /mnt/data
ls -lh /mnt/
total 0
drwxr-xr-x 2 postgres postgres 6 Jun  5 08:48 data
```
### перенесите содержимое /var/lib/postgres/15 в /mnt/data - mv /var/lib/postgresql/15/mnt/data
```
sudo mv /var/lib/postgresql/15/main /mnt/data
```
### попытайтесь запустить кластер - sudo -u postgres pg_ctlcluster 15 main start
```
sudo -u postgres pg_ctlcluster 15 main start
```
### напишите получилось или нет и почему
Запустить кластер не получилось, потому что мы не копировали, а переместили данные кластера в другое место
Не сообщив ему об этом)) Нужно прописать новый путь в конфигурации кластера
### задание: найти конфигурационный параметр в файлах раположенных в /etc/postgresql/15/main который надо поменять и поменяйте его
```
pg_conftool 15 main show all
cluster_name = '15/main'
data_directory = '/var/lib/postgresql/15/main'
datestyle = 'iso, mdy'
default_text_search_config = 'pg_catalog.english'
dynamic_shared_memory_type = posix
external_pid_file = '/var/run/postgresql/15-main.pid'
hba_file = '/etc/postgresql/15/main/pg_hba.conf'
ident_file = '/etc/postgresql/15/main/pg_ident.conf'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'
log_line_prefix = '%m [%p] %q%u@%d '
log_timezone = 'Etc/UTC'
max_connections = 100
max_wal_size = 1GB
min_wal_size = 80MB
port = 5432
shared_buffers = 128MB
ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
timezone = 'Etc/UTC'
unix_socket_directories = '/var/run/postgresql'

sudo -i -u postgres pg_conftool 15 main set data_directory /mnt/data/main
sudo -i -u postgres pg_conftool 15 main show data_directory
data_directory = '/mnt/data/main'
```
### напишите что и почему поменяли
Как и описывалось в прошлом примере, нужно сообщить кластеру, что нужная ему директория находится в другом месте. Меняем параметр data_directory
### попытайтесь запустить кластер - sudo -u postgres pg_ctlcluster 15 main start
Пробуем снова:
```
sudo -u postgres pg_ctlcluster 15 main start
```
### напишите получилось или нет и почему
Теперь получилось, т.к. кластер теперь смотрит в нужную папку и находит данные
### зайдите через через psql и проверьте содержимое ранее созданной таблицы
```
sudo -i -u postgres psql -c "select * from test;"
```
Данные на месте!
### задание со звездочкой *: не удаляя существующий инстанс ВМ сделайте новый, поставьте на его PostgreSQL, удалите файлы с данными из /var/lib/postgres, перемонтируйте внешний диск который сделали ранее от первой виртуальной машины ко второй и запустите PostgreSQL на второй машине так чтобы он работал с данными на внешнем диске, расскажите как вы это сделали и что в итоге получилось.
На выполнение задания со звёздочкой, к сожалению, нет времени. Но очень интересно! Обязательно вернусь к нему позже