#!/bin/bash

# Global variable declartion, Change as per your need
USER_NAME='hadoop'
USER_PASS='smith'
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
	JAVA_VERSION=`echo "$(java -version 2>&1)" | grep "java version" | awk '{ print substr($3, 4, length($3)-9); }'`

	if [ $JAVA_VERSION -eq "8" ] ; then
		echo "Java 8 is installed in your system "
		
	else 
		echo "-----------------Removing older version of Java and installing default JDK of Ubuntu--------------"
		sudo apt-get autoremove java-common
		sudo apt-get install default-jdk
		
	fi 
	
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/
	java_home=`echo $JAVA_HOME`
	echo $java_home
}

function add_user_group()
{
	
	if [ `grep -c $USER_NAME /etc/group` -eq 0 ]; then
		sudo addgroup $USER_NAME -q
	fi
	if [ `grep -c $USER_NAME /etc/passwd` -eq 0 ]; then
		sudo adduser --ingroup $USER_NAME $USER_NAME
		echo hadoop:$USER_PASS | sudo chpasswd
		sudo usermod -a -G $USER_NAME $USER_NAME
	else
		if [ `id $USER_NAME | egrep groups=[0-9]*'\($USER_NAME\)' -c` -eq 0 ]; then
			sudo usermod -a -G $USER_NAME $USER_NAME
		fi
	fi
}

function update()
{
	
	sudo apt-get update
}

function ssh_configure()
{
	
	if [ ! -f /home/$USER_NAME/.ssh/id_rsa ] && [ ! -f /home/$USER_NAME/.ssh/id_rsa.pub ]; then
		sudo pkexec --user $USER_NAME ssh-keygen -t rsa -P "" -f "/home/$USER_NAME/.ssh/id_rsa" -q
	fi

	#sudo pkexec --user $USER_NAME ssh-agent bash -c ssh-add -i /home/$USER_NAME/.ssh/id_rsa -q

	if [ ! -f /home/$USER_NAME/.ssh/authorized_keys ]; then
		sudo pkexec touch /home/$USER_NAME/.ssh/authorized_keys
	fi

	if [ `sudo pkexec --user hadoop grep $USER_NAME@\`hostname\` -c \/home\/$USER_NAME\/\.ssh\/authorized_keys` -eq 0 ]; then
		sudo cat /home/$USER_NAME/.ssh/id_rsa.pub >> /home/$USER_NAME/.ssh/authorized_keys
	    	sudo chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh/authorized_keys
		sudo chmod 640 /home/$USER_NAME/.ssh/authorized_keys
	fi
	sudo pkexec --user $USER_NAME ssh -o StrictHostKeyChecking=no $USER_NAME@localhost exit >> /tmp/hadoop_install.log 2>&1
	if [[ "$1" = "m" ]]; then
		sudo pkexec --user $USER_NAME ssh -o StrictHostKeyChecking=no $USER_NAME@master exit >> /tmp/hadoop_install.log 2>&1
	else
		sudo pkexec --user $USER_NAME ssh -o StrictHostKeyChecking=no $USER_NAME@slave exit >> /tmp/hadoop_install.log 2>&1
	fi
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

	#Extracing Hadoop Files
	#sudo mkdir /tmp/hadoop_installation
	sudo tar xvfz hadoop-2.6.0.tar.gz

	sudo  mv hadoop-2.6.0 /home/hadoop/hadoop

	#Renaming extracted folder to hadoop from `echo $HADOOP_FILENAME | sed "s/.tar.gz//g"` at $HADOOP_LOCATION
	#sudo mv /tmp/hadoop_installation/hadoop* $HADOOP_LOCATION/hadoop
}

function hadoop_configure()
{
	
	
	if [[ "$1" = "m" ]]; then
		sudo rm -f -r $HADOOP_LOCATION/hadoop/etc/hadoop/masters
		sudo mkdir -p $HADOOP_LOCATION/hadoop/etc/hadoop
		sudo echo "master" > $HADOOP_LOCATION/hadoop/etc/hadoop/masters
		sudo rm -f -r $HADOOP_LOCATION/hadoop/etc/hadoop/slaves
		for (( c=1; c<=$SLAVECNT; c++ ))
		do
			echo -e "slave$c" >> $HADOOP_LOCATION/hadoop/etc/hadoop/slaves
		done
	fi


	#Giving permission to write the .bashrc, hadoop-env.sh core-site.xml, mapred-site.xml, hdfs-site.xml, yarn-site.xml.
	sudo chown hadoop /home/hadoop/hadoop
	sudo chmod o+w /home/hadoop/.bashrc
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/hadoop-env.sh
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/core-site.xml
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/mapred-site.xml
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/hdfs-site.xml
	sudo chmod o+w /home/hadoop/hadoop/etc/hadoop/yarn-site.xml

	#Setting JAVA_HOME environment variable for hadoop under $HADOOP_LOCATION/hadoop/etc/hadoop/hadoop-env.sh file
	sudo sed -i "s|\${JAVA_HOME}|$java_home|g" $HADOOP_LOCATION/hadoop/etc/hadoop/hadoop-env.sh
	sudo echo -e "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/" >> /home/hadoop/hadoop/etc/hadoop/hadoop-env.sh	

	#Configuring $HADOOP_LOCATION/hadoop/etc/hadoop/core-site.xml file for single node
	sudo sed "s/<configuration>/<configuration>\\`echo -e '\n\r'`\\`echo -e '\n\r'`<\!-- In: conf\/core-site.xml -->\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>hadoop.tmp.dir<\/name>\\`echo -e '\n\r'`	<value>\/app\/hadoop\/tmp<\/value>\\`echo -e '\n\r'`	<description>A base for other temporary directories\.<\/description>\\`echo -e '\n\r'`<\/property>\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>fs.default.name<\/name>\\`echo -e '\n\r'`	<value>hdfs\:\/\/master\:9000<\/value>\\`echo -e '\n\r'`	<description>The name of the default file system\. A URI whose\\`echo -e '\n\r'`	scheme and authority determine the FileSystem implementation\. The\\`echo -e '\n\r'`	uri\'s scheme determines the config property \(fs\.SCHEME\.impl\) naming\\`echo -e '\n\r'`	the FileSystem implementation class. The uri\'s authority is used to\\`echo -e '\n\r'`	determine the host\, port\, etc\. for a filesystem\.\\`echo -e '\n\r'`	<\/description>\\`echo -e '\n\r'`<\/property>/g" $HADOOP_LOCATION/hadoop/etc/hadoop/core-site.xml > /tmp/core-site.xml.mod
	sudo mv /tmp/core-site.xml.mod $HADOOP_LOCATION/hadoop/etc/hadoop/core-site.xml

	#Configuring $HADOOP_LOCATION/hadoop/etc/hadoop/mapred-site.xml for single node
	sudo cp /home/hadoop/hadoop/etc/hadoop/mapred-site.xml.template /home/hadoop/hadoop/etc/hadoop/mapred-site.xml
	sudo sed "s/<configuration>/<configuration>\\`echo -e '\n\r'`\\`echo -e '\n\r'`<\!-- In: conf\/mapred-site.xml -->\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>mapred\.job\.tracker<\/name>\\`echo -e '\n\r'`	<value>master\:9000<\/value>\\`echo -e '\n\r'`	<description>The host and port that the MapReduce job tracker runs\\`echo -e '\n\r'`	at\. If \"local\", then jobs are run in-process as a single map\\`echo -e '\n\r'`	and reduce task\.\\`echo -e '\n\r'`	<\/description>\\`echo -e '\n\r'`<\/property>/g" /home/hadoop/hadoop/etc/hadoop/mapred-site.xml > /tmp/mapred-site.xml.mod
	sudo mv /tmp/mapred-site.xml.mod /home/hadoop/hadoop/etc/hadoop/mapred-site.xml

	#Configuring $HADOOP_LOCATION/hadoop/etc/hadoop/hdfs-site.xml for single node
	sudo sed "s/<configuration>/<configuration>\\`echo -e '\n\r'`\\`echo -e '\n\r'`<\!-- In: conf\/hdfs-site.xml -->\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>dfs\.replication<\/name>\\`echo -e '\n\r'`	<value>$SLAVECNT<\/value>\\`echo -e '\n\r'`	<description>Default block replication\.\\`echo -e '\n\r'`	The actual number of replications can be specified when the file is created\.\\`echo -e '\n\r'`	The default is used if replication is not specified in create time\.\\`echo -e '\n\r'`     <\/description>\\`echo -e '\n\r'`<\/property>/g" $HADOOP_LOCATION/hadoop/etc/hadoop/hdfs-site.xml > /tmp/hdfs-site.xml.mod
	sudo mv /tmp/hdfs-site.xml.mod $HADOOP_LOCATION/hadoop/etc/hadoop/hdfs-site.xml


	#Creating /app/hadoop/tmp folder for hadoop file system and changing ownership to $USER_NAME user
	sudo mkdir -p /app/hadoop/tmp
	sudo chown -R $USER_NAME:$USER_NAME /app
	sudo chmod -R 750 /app
}

function install_hadoop()
{
	echo -ne "Ques: Will this system be Master/Slave(m/s)? "
	read -n 1 nodeType
	nodeType=`echo $nodeType | tr '[:upper:]' '[:lower:]'`
	echo -e "\n"
	if [[ "$nodeType" = "m" ]] || [[ "$nodeType" = "s" ]]; then
		update
		install_java
		add_user_group
		ssh_configure "$nodeType"
		host_file "a"
		bashrc_file "a"
		hadoop_download
		hadoop_setup
		hadoop_configure "$nodeType"
		echo "=> Hadoop installation complete";
		echo "=> Format hadoop filesystem using the below code:";
		echo "$HADOOP_LOCATION/hadoop/bin/hdfs namenode -format";
		
	else
		echo "Incorrect input"
	fi
	echo -e "\nPress a key. . ."
	read -n 1	
}

install_hadoop
    
