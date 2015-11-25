#!/bin/bash

read -p 'Username: ' USER
read -sp 'Password: ' PASSWORD

while read HOST;do
	spawn ssh -t $USER@$HOST sho inv > $HOST.out
	expect \"password\"
	send \"$PASSWORD\r\"
	cat $HOST.out |grep -i serial >> serials.list
done < hostlist