#!/bin/bash

reservation_id=$1

#get id of instances have provided reservation id.
mapfile -t array < <(euca-describe-instances --filter reservation-id=$reservation_id)
tLen=(${#array[@]}-1)/2
for ((i=1; i<=${tLen}; i++)); 
do
	temp=(${array[2*(i-1)+1]})
	instance_ids[i]=${temp[1]}
done

#terminate those instances
for ((i=1; i<=${tLen}; i++));
do 
	euca-terminate-instances ${instance_ids[i]}
done
