#!/bin/bash
source ${HOME}/.bash_profile

SHOST=src_host
SRCDB=src_base
DSTDB=dst_base
DMPDIR="/pgdump/dump"

killQueries(){
psql << EOF
SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
WHERE datname = '$DSTDB'
    AND pid <> pg_backend_pid()
EOF
}

main(){
pg_dump -h $SHOST -d $SRCDB -Fc > $DMPDIR/mydb.dump
psql -c "CREATE DATABASE dst_tmp WITH owner esb"
pg_restore -d dst_tmp -Fc -v $DMPDIR/mydb.dump
killQueries
psql <<EOF
DROP DATABASE $DSTDB;
ALTER DATABASE dst_tmp RENAME TO $DSTDB;
EOF
rm $DMPDIR/mydb.dump
}

main
