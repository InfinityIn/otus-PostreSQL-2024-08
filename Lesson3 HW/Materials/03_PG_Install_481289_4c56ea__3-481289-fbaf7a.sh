brew services stop postgresql@14
brew services start postgresql@14

# Если не работает
rm /opt/homebrew/var/postgresql@14/postmaster.pid
brew services restart postgresql@14

'yc' в составе Яндекс.Облако CLI для управления облачными ресурсами в Яндекс.Облако
https://cloud.yandex.com/en/docs/cli/quickstart

Подключаемся к Яндекс.Облако и выполняем конфигурацию окружения с помощью команды:
yc init

Проверяем установленную версию 'yc' (рекомендуется последняя доступная версия):
yc version

Список географических регионов и зон доступности для размещения VM:
yc compute zone list
yc config set compute-default-zone ru-central1-a && yc config get compute-default-zone

Далее будем использовать географический регион ‘ru-central1’ и зону доступности 'ru-central1-a'.

Список доступных типов дисков:
yc compute disk-type list

Далее будем использовать тип диска ‘network-hdd’.

Создаем сетевую инфраструктуру для VM:

yc vpc network create \
    --name otus-net \
    --description "otus-net" \

yc vpc network list

yc vpc subnet create \
    --name otus-subnet \
    --range 192.168.0.0/24 \
    --network-name otus-net \
    --description "otus-subnet" \

yc vpc subnet list

Сгенерируем ssh-key:
ssh-keygen -t rsa -b 2048
ssh-add ~/.ssh/yc_key

Устанавливаем ВМ:
yc compute instance create \
    --name otus-vm \
    --hostname otus-vm \
    --cores 2 \
    --memory 4 \
    --create-boot-disk size=15G,type=network-hdd,image-folder-id=standard-images,image-family=ubuntu-2004-lts \
    --network-interface subnet-name=otus-subnet,nat-ip-version=ipv4 \
    --ssh-key ~/.ssh/yc_key.pub \

yc compute instances show otus-vm
yc compute instances list

Подключаемся к ВМ:
ssh -i ~/.ssh/yc_key yc-user@89.169.147.163
yc compute ssh --name otus-vm --folder-id b1gng73q9608ing1dl74

Удаляем ВМ и сети:
yc compute instance delete otus-vm && yc vpc subnet delete otus-subnet && yc vpc network delete otus-net


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

yc compute instances list - 51.250.2.232

yc compute instance delete otus-vm && yc vpc subnet delete otus-subnet && yc vpc network delete otus-net


Более новая версия не содержит бинарники предыдущих, при создании кластера pg_createcluster 13 main, т.е. если мы хотим иметь на сервере несколько кластеров разных версий, нужно скачивать их бинарники. Соответственно чтобы обновиться с 15 на 16 версию, нужны бинарники обоих. Кластеры друг другу не мешают, у них разные директории и разные порты. Независимо друг от друга они могут включаться и выключаться.

И мы хотим обновить 13 кластер до 15.


sudo apt update && sudo apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt -y install postgresql-15

sudo apt install -y postgresql-13

pg_lsclusters

pg_upgradecluster 13 main

для всех утилит есть мануал man pg_upgradecluster к примеру.

Для того чтобы открыть доступ во вне, нам нужно соответственно создать пользователя и пароль.

sudo -u postgres psql -p 5433

мы создали пользователя и пароль в версии 13 и обновляем кластер до 15

-- зададим пароль
CREATE ROLE testpass PASSWORD 'testpass' LOGIN; \du
CREATE DATABASE otus; \l

-- переименуем старый кластер
sudo pg_renamecluster 13 main main13

-- заапдейтим версию кластера
sudo pg_upgradecluster 13 main13

-- обратите внимание, что старый кластер остался. Давайте удалим его
sudo pg_dropcluster 13 main13

Можно настроить подключение только по внутренней сети, т.е. из интернета не будет доступа. Обычно открытие PostgreSQL в интернет не несет особого смысла, т.к. Обычно он должен быть за всякими файрволлами.

-- Откроем доступ извне - на каком интерфейсе мы будем слушать подключения. Открываем маску подсети пошире, это не продакт решение конечно особенно с простыми паролями, но для эксперимента пойдет.
sudo nano /etc/postgresql/15/main13/postgresql.conf
sudo nano /etc/postgresql/15/main13/pg_hba.conf
sudo pg_ctlcluster 15 main13 restart

ALTER USER postgres PASSWORD 'postgres';

-- с ноута
psql -p 5433 -U postgres -h 89.169.147.163 -W
psql -p 5433 -U testpass -h 89.169.147.163 -d otus -W

-- проверим настройки шифрования для внешних подключений
sudo cat /etc/postgresql/15/main13/pg_hba.conf

-- scram-sha-256
sudo nano /etc/postgresql/15/main13/pg_hba.conf
sudo pg_ctlcluster 15 main13 reload

если мы изменим вид шифрования с версии md5 на scram-sha-256 (которая поддерживается 15й версией пг), то у нас будет ошибка аутентификации. Чтобы сенить тип шифрования на более современный, необходимо пользователю сменить пароль.


-- md5
sudo nano /etc/postgresql/15/main13/pg_hba.conf
sudo pg_ctlcluster 15 main13 reload

sudo -u postgres psql -p 5433 -U testpass -h localhost -d otus -W

ALTER USER testpass PASSWORD 'testpass';

-- change back to scram-sha-256
sudo nano /etc/postgresql/15/main13/pg_hba.conf
sudo pg_ctlcluster 15 main13 reload

sudo -u postgres psql -p 5433 -U testpass -h localhost -d postgres -W


-- Установка клиента PostgreSQL
sudo apt install postgresql-client
export PATH=$PATH:/usr/bin
psql --version


-- уберем лишние кластера
pg_lsclusters
sudo pg_ctlcluster 15 main stop && sudo pg_dropcluster 15 main && sudo pg_ctlcluster 15 main13 stop && sudo pg_dropcluster 15 main13





- поставим докер
-- https://docs.docker.com/engine/install/ubuntu/
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && rm get-docker.sh && sudo usermod -aG docker $USER && newgrp docker


-- 1. Создаем docker-сеть: 
sudo docker network create pg-net

d166b0b1ac165e9f754fe97192d5cdb25a4f73a14d6d18c7eec9638653902df5

-- 2. подключаем созданную сеть к контейнеру сервера Postgres:
sudo docker run --name pg-server --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:15

-- 3. Запускаем отдельный контейнер с клиентом в общей сети с БД: 
sudo docker run -it --rm --network pg-net --name pg-client postgres:15 psql -h pg-server -U postgres

CREATE DATABASE otus; 

-- 4. Проверяем, что подключились через отдельный контейнер:
sudo docker ps -a

sudo docker stop 901cc056bad6

sudo docker rm 901cc056bad6

psql -h localhost -U postgres -d postgres

-- с ноута
psql -p 5432 -U postgres -h 89.169.147.163 -d otus -W

-- подключение без открытия порта наружу
sudo docker run --name pg-server --network pg-net -e POSTGRES_PASSWORD=postgres -d -v /var/lib/postgres:/var/lib/postgresql/data postgres:15
sudo docker run -it --rm --network pg-net --name pg-client postgres:15 psql -h pg-server -U postgres


-- минимальный запуск
sudo docker run --name pg-server -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15



-- зайти внутрь контейнера (посмотреть использование дискового пространства файловой системы контейнера)
sudo docker exec -it pg-server bash
df

Этот вывод команды df показывает использование дискового пространства на вашей системе. Вот как можно интерпретировать каждую строку:

1. Filesystem: это тип файловой системы.
2. 1K-blocks: общий объем дискового пространства в килобайтах.
3. Used: количество использованного дискового пространства в килобайтах.
4. Available: доступное дисковое пространство в килобайтах.
5. Use%: процент использования дискового пространства.
6. Mounted on: точка монтирования файловой системы.

Интерпретация каждой строки:
- overlay: это файловая система контейнера Docker, где контейнер хранит свои файлы.
- tmpfs: это виртуальная файловая система в оперативной памяти (RAM), используемая для временных файлов.
- shm: это общая память (shared memory), используемая для обмена данными между процессами.
- /dev/vda2: это файловая система, связанная с /etc/hosts.
- /proc/acpi, /proc/scsi, /sys/firmware: это виртуальные файловые системы, предоставляющие информацию о аппаратном обеспечении и процессах.

Общее использование дискового пространства на вашей системе составляет 31%.


-- установить VIM & NANO
-- внутри контейнера ubuntu
cat /proc/version

apt-get update && apt-get install vim nano -y

psql -U postgres

show hba_file;
show config_file;
show data_directory;



sudo docker ps

sudo docker stop

-- рестарт контейнера после смерти
docker run -d --restart unless-stopped/always



-- docker compose
sudo apt install docker-compose -y

-- используем утилиту защищенного копирования по сети
MAC OS
echo $HOME/Desktop
scp -i ~/.ssh/yc_key /Users/admin/Desktop/docker-compose.yml yc-user@89.169.133.154:/home/yc-user/

UBUNTU
scp -i ~/.ssh/yc_key /mnt/c/Users/admin/docker-compose.yml yc-user@158.160.127.142:/home/yc-user/ 

cat docker-compose.yml

sudo docker-compose up -d
sudo docker ps -a

-- с ноута
psql -p 5432 -U postgres -h 89.169.133.154 -d stage -W

-- password - postgres
sudo -u postgres psql -h localhost -p 5432

sudo su
cd /var/lib/docker/volumes/yc-user_pg_project/_data
ls -la


