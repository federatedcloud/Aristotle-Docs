#!/bin/bash
#Use euca-run-instances to create instances of image emi-ff331268 (this image contains hadoop-2.7.2)
mapfile -t array < <(euca-run-instances $* emi-ff331268)

tLen=${#array[@]}

temp=(${array[0]})
reservation_id=${temp[1]}

sleep 60

#Parse output of euca-run-instances to get id and address of created VM instances
while true; 
do
	mapfile -t array < <(euca-describe-instances --filter reservation-id=$reservation_id)
	check=1
	for ((i=1; i<${tLen}; i++)); 
	do
		temp=(${array[2*(i-1)+1]})
		instance_ids[i]=${temp[1]}
		public_address[i]=${temp[3]}
		private_address[i]=${temp[4]}
		if [ "${temp[5]}" != "running" ]; 
		then
			check=0
		fi
	done
	
	if [ $check -eq 0 ];
	then
		sleep 20
	else
		break
	fi
done

# Configure created VM instances as a hadoop cluster
# The first VM will be namenode of created cluster.
slaves=${private_address[2]}
for ((i=3; i<${tLen}; i++));
do 
	slaves=${slaves}\\\\n${private_address[i]}
done

sh-keygen -f "/home/ubuntu/.ssh/known_hosts" -R ${public_address[1]}

ssh -i  ~/bash-scripts/privatekeys/dtran2.private  -o StrictHostKeychecking=no ubuntu@${public_address[1]} "echo "" > .ssh/known_hosts"

ssh -i  ~/bash-scripts/privatekeys/dtran2.private -o StrictHostKeychecking=no ubuntu@${public_address[1]} 'echo -e "Host * \n StrictHostKeyChecking no" > ~/.ssh/config'

ssh -i  ~/bash-scripts/privatekeys/dtran2.private -o StrictHostKeychecking=no ubuntu@${public_address[1]} "echo -e ${slaves} > /home/ubuntu/hadoop-2.7.2/etc/hadoop/slaves"

for ((i=1; i<${tLen}; i++));
do 
	ssh -i  ~/bash-scripts/privatekeys/dtran2.private -o StrictHostKeychecking=no ubuntu@${public_address[i]} "sed -i s/euca.*nal/${private_address[1]}/g /home/ubuntu/hadoop-2.7.2/etc/hadoop/core-site.xml"
	ssh -i  ~/bash-scripts/privatekeys/dtran2.private -o StrictHostKeychecking=no ubuntu@${public_address[i]} "sed -i s/euca.*nal/${private_address[1]}/g /home/ubuntu/hadoop-2.7.2/etc/hadoop/yarn-site.xml"
done

ssh -i  ~/bash-scripts/privatekeys/dtran2.private -o StrictHostKeychecking=no ubuntu@${public_address[1]} '/home/ubuntu/hadoop-2.7.2/bin/hdfs namenode -format hadoopcluster'

ssh -i  ~/bash-scripts/privatekeys/dtran2.private -o StrictHostKeychecking=no ubuntu@${public_address[1]} '/home/ubuntu/hadoop-2.7.2/sbin/start-dfs.sh'

ssh -i ~/bash-scripts/privatekeys/dtran2.private  -o StrictHostKeychecking=no ubuntu@${public_address[1]} '/home/ubuntu/hadoop-2.7.2/sbin/start-yarn.sh'

ssh -i ~/bash-scripts/privatekeys/dtran2.private  -o StrictHostKeychecking=no ubuntu@${public_address[1]} '/home/ubuntu/hadoop-2.7.2/bin/hdfs dfsadmin -report'

echo "RESERVATION $reservation_id"
echo "NAMENODE ${public_address[1]} ${private_address[1]}"

