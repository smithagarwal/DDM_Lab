#!/bin/bash

# Global variable declartion, Change as per your need
USER_NAME='hadoop'
USER_PASS'smith12345'
HADOOP_LOCATION="/home/hadoop"
HADOOP_FILENAME="hadoop-2.6.0.tar.gz"
HADOOP_VERSION="2.6.0"
HADOOP_DOWNLOAD="http://archive.apache.org/dist/hadoop/core/hadoop-2.6.0/hadoop-2.6.0.tar.gz"
HADOOP_COMMAND="hadoop"


MASTERIP=`cat hadoop_install.conf | grep master | cut -d ":" -f2`
SLAVECNT=`cat hadoop_install.conf | grep slave | cut -d ":" -f2 | tr "," "\n" | wc -l`
declare -a SLAVEIP
for (( c=1; c<=$SLAVECNT; c++ ))
do
	SLAVEIP[c]=`cat hadoop_install.conf | grep slave | cut -d ":" -f2 | cut -d ',' -f$c`
done

function install_java()
{
	
	sudo apt-get install default-jdk
	
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/
	java_home=/usr/lib/jvm/java-8-openjdk-amd64/jre/
	
}

function update()
{
	
	sudo apt-get update
}


function host_file()
{

	sudo sed -i '/Hadoop Master/Id;/Hadoop Slave/Id' /etc/hosts
	if [[ "$1" = "a" ]] ; then
		sudo echo -e "# Start: Hadoop Master/Slave Machines Configuration" >> /etc/hosts
		sudo echo -e "$MASTERIP\tmaster\t#Hadoop Master" >> /etc/hosts
		for (( c=1; c<=$SLAVECNT; c++ ))
		do
			echo -e "${SLAVEIP[$c]}\tslave$c\t#Hadoop Slave(s)" >> /etc/hosts
		done
		sudo echo -e "# End: Hadoop Master/Slave Machines Configuration" >> /etc/hosts
	fi
}

function bashrc_file()
{
	
	sudo sed -i '/Hadoop/Id' /home/$USER_NAME/.bashrc
	if [[ "$1" = "a" ]] ; then
	    	sudo echo -e "# Start: Set Hadoop-related environment variables" >> /home/$USER_NAME/.bashrc
	    	sudo echo -e "export HADOOP_HOME=$HADOOP_LOCATION/hadoop\t#Hadoop Home Folder Path" >> /home/$USER_NAME/.bashrc
	    	sudo echo -e "export HADOOP_VERSION=$HADOOP_VERSION\t#Hadoop Version No" >> /home/$USER_NAME/.bashrc
	    	sudo echo -e "export PATH=\$PATH:\$HADOOP_HOME/bin\t#Add Hadoop bin/ directory to PATH" >> /home/$USER_NAME/.bashrc
		sudo echo -e "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/" >> /home/$USER_NAME/.bashrc
		sudo echo -e "# End: Set Hadoop-related environment variables" >> /home/$USER_NAME/.bashrc
	fi
}

function hadoop_download()
{
	
	if [ ! -f $HADOOP_FILENAME ] && [ ! -f $HADOOP_LOCATION/$HADOOP_FILENAME ]; then
		wget $HADOOP_DOWNLOAD >> /tmp/hadoop_install.log 2>&1
	fi
	if [ -f $HADOOP_FILENAME ]; then
		sudo mv /tmp/$HADOOP_FILENAME $HADOOP_LOCATION 	
	fi
}

function hadoop_setup()
{
	
	#Cleaning Old Installation
	sudo rm -f -r $HADOOP_LOCATION/`echo $HADOOP_FILENAME | sed "s/.tar.gz//g"`
	sudo rm -f -r $HADOOP_LOCATION/hadoop
	sudo rm -f -r /app
	sudo rm -f -r /tmp/hadoop_installation

	sudo tar xvfz hadoop-2.6.0.tar.gz

	sudo  mv hadoop-2.6.0 /home/hadoop/hadoop

}

function hadoop_configure()
{
	
	
	
	sudo rm -f -r $HADOOP_LOCATION/hadoop/etc/hadoop/masters
	sudo echo "master" > $HADOOP_LOCATION/hadoop/etc/hadoop/masters
	sudo rm -f -r $HADOOP_LOCATION/hadoop/etc/hadoop/slaves
	for (( c=1; c<=$SLAVECNT; c++ ))
	do
		echo -e "slave$c" >> $HADOOP_LOCATION/hadoop/etc/hadoop/slaves
	done
	


	#Giving permission to write the .bashrc, hadoop-env.sh core-site.xml, mapred-site.xml, hdfs-site.xml, yarn-site.xml.
	sudo chown hadoop /home/hadoop/hadoop
	sudo chmod o+w /home/hadoop/.bashrc
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/hadoop-env.sh
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/core-site.xml
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/mapred-site.xml
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/hdfs-site.xml
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/yarn-site.xml
	usermod -aG sudo $USER_NAME

	#Setting JAVA_HOME environment variable for hadoop under $HADOOP_LOCATION/hadoop/etc/hadoop/hadoop-env.sh file
	sudo sed -i "s|\${JAVA_HOME}|$java_home|g" $HADOOP_LOCATION/hadoop/etc/hadoop/hadoop-env.sh
	sudo echo -e "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/" >> /home/hadoop/hadoop/etc/hadoop/hadoop-env.sh	



	#Creating /app/hadoop/tmp folder for hadoop file system and changing ownership to $USER_NAME user
	sudo mkdir -p /app/hadoop/tmp
	sudo chown -R $USER_NAME:$USER_NAME /app
	sudo chmod -R 750 /app

	#Creating hadoop storage location for NameNode and DataNode under hadoop/hadoop_store/hdfs
	sudo mkdir -p /home/$USER_NAME/hadoop/hadoop_store/hdfs/namenode
	sudo mkdir -p /home/$USER_NAME/hadoop/hadoop_store/hdfs/datanode

	sudo chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/hadoop/hadoop_store

	#Sourcing bashrc
	source /home/$USER_NAME/.bashrc
}

function install_hadoop()
{
	update
	install_java
	host_file "a"
	bashrc_file "a"
	hadoop_configure
}

install_hadoop
    
