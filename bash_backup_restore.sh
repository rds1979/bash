#!/bin/bash
source ${HOME}/.bash_profile

SRCDB=esb
DSTDB=esb_rest
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
pg_dump -h 3d-esb-postgre01.12stz.local -d $SRCDB -Fc > $DMPDIR/esb.dump
psql << EOF
DROP DATABASE IF EXISTS esb_tmp;
CREATE DATABASE esb_tmp WITH owner esb;
EOF
pg_restore -d esb_tmp -Fc -v $DMPDIR/esb.dump
killQueries
psql -c "ALTER DATABASE esb_tmp RENAME TO $DSTDB"
rm $DMPDIR/esb.dump
}

main
