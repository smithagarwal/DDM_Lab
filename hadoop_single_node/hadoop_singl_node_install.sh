#!/bin/bash

echo -n "Enter the new 'GroupName' for new Hadoop user : "
read hdGroup
echo -n "Enter the new 'UserName' for Hadoop: "
read hdUserName

echo "...................Updating your System.................."

sudo apt-get update

JAVA_VERSION=`echo "$(java -version 2>&1)" | grep "java version" | awk '{ print substr($3, 4, length($3)-9); }'`

#checking for java 7, In this script we are using default jdk from ubuntu  
if [ $JAVA_VERSION -eq "7" ] ; then
	echo "Java 7 is installed in your system "

else 
	echo "-----------------Removing older version of Java and installing default JDK of Ubuntu--------------"
	sudo apt-get autoremove java-common
	sudo apt-get install default-jdk
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/
fi 

#Getting JAVA_HOME value and storing in java_home variable

echo $JAVA_HOME
java_home=`echo $JAVA_HOME`
echo $java_home

echo "-----------------Adding a dedicated HADOOP user---------------------------"

sudo addgroup $hdGroup

echo "------------------Enter the Details for new HADOOP user---------------------------"
sudo adduser -ingroup $hdGroup $hdUserName

echo "--------New $hdGroup  GROUP is created and $hdUserName USER is assaigned to Group------------------"

#Giving sudo permissions to the user
echo "...................Giving sudo permission to the newly created user........................"
usermod -aG sudo $hdUserName

echo "------------------------Installing SSH------------------------------- "

sudo apt-get install ssh


echo "--------Please press Enter when asking for file to save RSA keys -------------------------------"

sudo -u $hdUserName ssh-keygen -t rsa -P ""
sudo -u $hdUserName cat /home/$hdUserName/.ssh/id_rsa.pub >> /home/$hdUserName/.ssh/authorized_keys

#Download hadoop2.6.0 from apache
sudo wget http://archive.apache.org/dist/hadoop/core/hadoop-2.6.0/hadoop-2.6.0.tar.gz  

sudo tar xvfz hadoop-2.6.0.tar.gz

sudo  mv hadoop-2.6.0 /home/$hdUserName/hadoop

sudo chown -R $hdUserName:$hdGroup /home/$hdUserName/hadoop

#Creating tmp folder for hadoop under hadoop/app/hadoop/tmp 

sudo -u $hdUserName mkdir -p /home/$hdUserName/hadoop/app/hadoop/tmp
sudo -u $hdUserName chown -R $hdUserName:$hdGroup /home/$hdUserName/hadoop/app/hadoop/tmp

#Re naming  mapred-site.xml.template file to mapred-site.xml

sudo -u $hdUserName cp /home/$hdUserName/hadoop/etc/hadoop/mapred-site.xml.template /home/$hdUserName/hadoop/etc/hadoop/mapred-site.xml

#Creating hadoop storage location for NameNode and DataNode under hadoop/hadoop_store/hdfs
sudo -u $hdUserName mkdir -p /home/$hdUserName/hadoop/hadoop_store/hdfs/namenode
sudo -u $hdUserName mkdir -p /home/$hdUserName/hadoop/hadoop_store/hdfs/datanode

sudo -u $hdUserName chown -R $hdUserName:$hdGroup /home/$hdUserName/hadoop/hadoop_store

#Giving permission to write the .bashrc, hadoop-env.sh core-site.xml, mapred-site.xml, hdfs-site.xml, yarn-site.xml.

sudo -u $hdUserName chmod o+w /home/$hdUserName/.bashrc
sudo -u $hdUserName chmod o+w /home/$hdUserName/hadoop/etc/hadoop/hadoop-env.sh
sudo -u $hdUserName chmod o+w /home/$hdUserName/hadoop/etc/hadoop/core-site.xml
sudo -u $hdUserName chmod o+w /home/$hdUserName/hadoop/etc/hadoop/mapred-site.xml
sudo -u $hdUserName chmod o+w /home/$hdUserName/hadoop/etc/hadoop/hdfs-site.xml
sudo -u $hdUserName chmod o+w /home/$hdUserName/hadoop/etc/hadoop/yarn-site.xml

#hadoop-env.sh

sudo sed -i "s|\${JAVA_HOME}|$java_home|g" /home/$hdUserName/hadoop/etc/hadoop/hadoop-env.sh

echo -e '\n\n #Hadoop Variable START \n export HADOOP_HOME=/home/'$hdUserName'/hadoop \n export HADOOP_INSTALL=$HADOOP_HOME \n export HADOOP_MAPRED_HOME=$HADOOP_HOME \n export HADOOP_COMMON_HOME=$HADOOP_HOME \n export HADOOP_HDFS_HOME=$HADOOP_HOME \n export YARN_HOME=$HADOOP_HOME \n export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native \n export PATH=$PATH:$HADOOP_HOME/sbin/:$HADOOP_HOME/bin \n #Hadoop Variable END\n\n' >> /home/$hdUserName/.bashrc

source /home/$hdUserName/.bashrc

#core-site.xml
sudo sed -i '/<configuration>/a <property>\n\t\t<name>fs.default.name</name>\n\t\t<value>hdfs://master:9000</value>\n</property>' /home/$hdUserName/hadoop/etc/hadoop/core-site.xml

#mapred-site.xml
sudo sed -i '/<configuration>/a <property>\n\t\t <name>mapreduce.framework.name</name>\n\t\t <value>yarn</value>\n</property>' /home/$hdUserName/hadoop/etc/hadoop/mapred-site.xml

#Yarn-site.xml
sudo sed -i '/<configuration>/a <property>\n\t\t<name>yarn.nodemanager.aux-services</name>\n\t\t<value>mapreduce_shuffle</value>\n</property>\n<property>\n\t\t<name>yarn.nodemanager.auxservices.mapreduce.shuffle.class</name>\n\t\t<value>org.apache.hadoop.mapred.ShuffleHandler</value>\n</property>' /home/$hdUserName/hadoop/etc/hadoop/yarn-site.xml

#hdfs-site.xml
sudo sed -i "/<configuration>/a <property>\n\t\t<name>dfs.replication</name>\n\t\t<value>2</value>\n</property>\n<property>\n\t\t<name>dfs.permissions</name>\n\t\t<value>false</value>\n</property>\n<property>\n\t\t<name>dfs.namenode.name.dir</name>\n\t\t<value>/home/${hdUserName}/hadoop/hadoop_store/hdfs/namenode</value>\n</property>\n<property>\n\t\t<name>dfs.datanode.data.dir</name>\n\t\t<value>/home/${hdUserName}/hadoop/hadoop_store/hdfs/datanode</value>\n</property>" /home/$hdUserName/hadoop/etc/hadoop/hdfs-site.xml

#revoking write permission for .bashrc, hadoop-env.sh core-site.xml, mapred-site.xml, hdfs-site.xml, yarn-site.xml files. 
sudo -u $hdUserName chmod o-w /home/$hdUserName/.bashrc
sudo -u $hdUserName chmod o-w /home/$hdUserName/hadoop/etc/hadoop/hadoop-env.sh
sudo -u $hdUserName chmod o-w /home/$hdUserName/hadoop/etc/hadoop/core-site.xml
sudo -u $hdUserName chmod o-w /home/$hdUserName/hadoop/etc/hadoop/mapred-site.xml
sudo -u $hdUserName chmod o-w /home/$hdUserName/hadoop/etc/hadoop/hdfs-site.xml
sudo -u $hdUserName chmod o-w /home/$hdUserName/hadoop/etc/hadoop/yarn-site.xml

#Opening the port in iptables
sudo -u $hdUserName sudo /sbin/iptables -A INPUT -p tcp --dport 50070 -j ACCEPT

echo "--------------------HADOOP DIRECTORY------------------------- "
sudo ls /home/$hdUserName/hadoop/
echo "--------------------Proceed with 'yes' for continue connecting---------------------------- "
sudo -u $hdUserName ssh localhost
