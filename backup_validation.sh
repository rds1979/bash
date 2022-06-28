#!/bin/bash

source ~/.bash_profile

E_ROOTID=10
E_NODTIR=11
E_PSTATS=12
E_PGRUNN=13

DOW=`date +"%a"`

function select_backup(){

	declare -A weekDays
	weekDays[Mon]=3d-esb-postgre02
	weekDays[Tue]=3d-owms-postgre02
	weekDays[Wed]=3d-wiki-postgre01
	weekDays[Thu]=3d-esb-postgre02
	weekDays[Fri]=3d-owms-postgre02
	weekDays[Sat]=3d-wiki-postgre01
	
	for key in "${!weekDays[@]}"
	do
		if [ $key == $DOW ]
		then
			echo "Today $DOW, `date +"%d.%m.%Y"`"
			BACKUP=${weekDays[$key]}
		fi
	done

}

function restore() {

	echo "Restore database from server $1"
	RMTD=/pgdump/backups/freenas/postgresql/$1/base_copy
	FLDR=`ls -ltr $RMTD | tail -1 | awk '{print $NF}'`
	echo "Start restore backup from directory $RMTD/$FLDR"
	
	echo "Stopping PostgreSQL"
	pg_ctl stop
	echo "Clearing data directory $PGDATA"
	rm -rf $PGDATA/*
	
	echo "Copying data files to $PGDATA"
	cp -a $RMTD/$FLDR/* $PGDATA
	
	rm $PGDATA/backup_label
	rm $PGDATA/backup_manifest
	if [ -e $PGDATA/standby.signal ]
	then
		rm $PGDATA/standby.signal
	fi
	
	ln -s /pgdata/log $PGDATA/log
	mkdir -pv $PGDATA/pg_wal/archive_status
	pg_resetwal -D $PGDATA -f
	
	echo "Starting PostgreSQL"
	pg_ctl start
	
}

function main(){

	echo ========================= START TEST RESTORE =========================
	
	rm /home/postgres/logs/autorestore/status.txt

	ROOT_UID=0
	if [ $UID == $ROOT_UID ]
	then
		echo "Root can't run this script. Use user postgres please"
		exit $E_ROOTID
	fi

	if [ -d $PGDATA ] 
	then
		echo "Data directory: $PGDATA"
	else
		echo "Data directory not exist. Exit"
		exit $E_NODTIR
	fi
	
	PROC=`ps -ef | grep walwriter | grep -v grep | wc -l`
	if [ $PROC == 0 ]
	then
		echo "PostgreSQL not running on this server. Exit"
		exit $E_PGRUNN
	else
		select_backup
	    restore $BACKUP
	fi
	
	REST=`psql -X -A -t -c 'SELECT pg_is_in_recovery()'`
	if [ $REST == 'f' ]
	then
		echo "Restore completed successfully"
		echo "0" > /home/postgres/logs/autorestore/status.txt
	else
		echo "Restore doesn't ompleted successfully. Try again."
		echo "1" > /home/postgres/logs/autorestore/status.txt
	fi
	
	echo ========================= STOP TEST RESTORE =========================
	
}

main
exit 0
