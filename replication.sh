#!/bin/bash

VER=$(sudo -iu postgres psql -X -A -t -c 'SHOW server_version')
if [ ${VER::1} == 1 ];
then
VERSION=${VER::2}
fi

if [ ${VER::1} == 9 ];
then
VERSION=${VER::3}
fi

PGDATA=/var/lib/pgsql/$VERSION/data

is_master(){
RECOVERY=$(sudo -iu postgres psql -X -A -t -c "SELECT pg_is_in_recovery()")
}

main(){
is_master
if [ "$RECOVERY" == "f" ];
then
REPLICA=$(sudo -iu postgres psql -X -A -t <<EOF
SELECT client_addr FROM pg_stat_replication
WHERE application_name IN ('db_main_slot', 'walreceiver')
EOF
)
sudo -iu postgres psql -c "CREATE ROLE replication_user WITH LOGIN REPLICATION ENCRYPTED PASSWORD 'strong_password'"
sudo -iu postgres cat <<EOF | sudo -u postgres tee /var/lib/pgsql/.pgpass
#server:port:database:user:password
*:*:*:replication_user:strong_password
EOF
sudo -iu postgres chmod 600 /var/lib/pgsql/.pgpass
sudo -iu postgres cp $PGDATA/pg_hba.conf $PGDATA/pg_hba.default
sudo -iu postgres cp $PGDATA/pg_hba.conf $PGDATA/pg_hba.conf.`date +%Y%m%d`
sudo -iu postgres chmod 666 $PGDATA/pg_hba.conf
sudo -iu postgres echo "host    replication    replication_user    $REPLICA/32    md5" | sudo -iu postgres >> $PGDATA/pg_hba.conf
sudo -iu postgres chmod 600 $PGDATA/pg_hba.conf
#sudo salt-call state.highstate
#sudo -iu postgres psql -c "SELECT pg_reload_conf()"

else
MASTER=$(sudo -iu postgres psql -X -A -t -c "SELECT conninfo FROM pg_stat_wal_receiver;" | awk -F' host=*' '{print $2}' | cut -d ' ' -f1)
sudo -iu postgres cat <<EOF | sudo -u postgres tee /var/lib/pgsql/.pgpass
#server:port:database:user:password
*:*:*:replication_user:strong_password
EOF
sudo -iu postgres chmod 600 /var/lib/pgsql/.pgpass
sudo -iu postgres cp $PGDATA/recovery.conf $PGDATA/recovery.conf.default
sudo -iu postgres cp $PGDATA/recovery.conf $PGDATA/recovery.conf.`date +%Y%m%d`
sudo -iu postgres cat <<EOF | sudo -u postgres tee $PGDATA/recovery.conf
standby_mode = 'on'
primary_conninfo = 'application_name=db_main_slot user=replication_user host=$MASTER'
primary_slot_name = 'db_main_slot'
recovery_target_timeline = 'latest'
EOF
#sudo salt-call state.highstate
#sudo systemctl restart postgresql-$VERSION.service
fi
}

main
