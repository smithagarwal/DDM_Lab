#!/bin/bash

# Global variable declartion, Change as per your need
USER_NAME='hadoop'
USER_PASS='smith'
HADOOP_LOCATION="/home/hadoop"
HADOOP_FILENAME="hadoop-2.6.0.tar.gz"
HADOOP_VERSION="2.6.0"
HADOOP_DOWNLOAD="http://archive.apache.org/dist/hadoop/core/hadoop-2.6.0/hadoop-2.6.0.tar.gz"
HADOOP_COMMAND="hadoop"
totCols=`tput cols`
now=$(date +"%m-%d-%Y-%T")

MASTERIP=`cat hadoop_install.conf | grep master | cut -d ":" -f2`
SLAVECNT=`cat hadoop_install.conf | grep slave | cut -d ":" -f2 | tr "," "\n" | wc -l`
declare -a SLAVEIP
for (( c=1; c<=$SLAVECNT; c++ ))
do
	SLAVEIP[c]=`cat hadoop_install.conf | grep slave | cut -d ":" -f2 | cut -d ',' -f$c`
done


function check_sudo()
{
	if [ -z "$SUDO_USER" ]; then
		tput setf 4
		echo "$0 must be called as root. Try: 'sudo ${0}'"
		tput sgr0
		exit 1
	else
		sudo chmod 777 /tmp/hadoop_install.log
	fi
}

function printMsg()
{
	tput rev
	echo -ne $1
	str_len=`echo ${#1}`
	if [ `echo $(($totCols - $str_len - 6))` -gt 0 ]; then
		print_pos=`echo $(($totCols - $str_len - 6))`
	else
		print_pos=$str_len
	fi
	tput cuf $print_pos
	tput sgr0
}

function spinner()
{
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?} # #? is used to find last operation status code, in this case its 1
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"} # % is being used to delete the shortest possible matched string from right
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b[Done]\n"
}


function install_java()
{
	printMsg "Installing Java 8 JDK (Will skip if already installed)"
	if [ $JAVA_VERSION -eq "8" ] ; then
		echo "Java 7 is installed in your system "
		export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/
	else 
		echo "-----------------Removing older version of Java and installing default JDK of Ubuntu--------------"
		sudo apt-get autoremove java-common
		sudo apt-get install default-jdk
		export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/
	fi 
	
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/
	java_home=`echo $JAVA_HOME`
	echo $java_home
}

function add_user_group()
{
	printMsg "Adding $USER_NAME User/Group (Will skip if already exist)"
	if [ `grep -c $USER_NAME /etc/group` -eq 0 ]; then
		sudo addgroup $USER_NAME -q
	fi
	if [ `grep -c $USER_NAME /etc/passwd` -eq 0 ]; then
		sudo adduser --ingroup $USER_NAME $USER_NAME --disabled-login -gecos "Hadopp User" -q
		echo hadoop:$USER_PASS | sudo chpasswd
	else
		if [ `id $USER_NAME | egrep groups=[0-9]*'\($USER_NAME\)' -c` -eq 0 ]; then
			sudo usermod -a -G $USER_NAME $USER_NAME
		fi
	fi
}

function install_ssh()
{
	printMsg "Installing SSH Client (Will skip if already installed)"
	if [ `apt-cache search "^openssh-client$|^openssh-server$|^ssh$" | wc -l` -eq 3 ] && [ `apt-cache policy "^openssh-client$|^openssh-server$|^ssh$" | grep -i 'installed:' | grep -ic '(none)'` -gt 0 ]; then
		sudo apt-get -y install ssh >> /tmp/hadoop_install.log 2>&1
	fi
}

function ssh_configure()
{
	printMsg "Configuring SSH For $USER_NAME User (Will skip if RSA Key/Pair already exist)"
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

function print_header()
{
	tput bold & tput setf 9 & tput smul
	str_len=`echo ${#1}`
	if [ `echo $(($totCols - $str_len - 6))` -gt 0 ]; then
		print_pos=`echo $(($totCols/2 - $str_len/2))`
	else
		print_pos=$str_len
	fi
	tput cuf $print_pos
	echo $1
	tput sgr0
	awk "BEGIN{for(c=0;c<$totCols;c++) printf \"-\"; printf \"\n\"}"
	echo ""
}

function print_error()
{
	tput bold & tput setf 4
	echo $1
	tput sgr0
}

function ipv6_file()
{
	if [[ "$1" = "a" ]]; then
		printMsg "Disabling IPv6"
	else
		printMsg "Reverting IPv6 Changes"
	fi
	sudo sed -i '/net\.ipv6\.conf\.all\.disable_ipv6/d;/net\.ipv6\.conf\.default\.disable_ipv6/d;/net\.ipv6\.conf\.lo\.disable_ipv6/d' /etc/sysctl.conf
	if [[ "$1" = "a" ]]; then
	    	sudo echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
		sudo echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
		sudo echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	fi
}

function host_file()
{
	if [[ "$1" = "a" ]]; then
		printMsg "Adding Hadoop Cluster Mapping in Host File"
	else
		printMsg "Reverting Host File Changes"
	fi
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
	if [[ "$1" = "a" ]]; then
		printMsg "Adding Hadoop Environment Variables in $USER_NAME's .bashrc File"
	else
		printMsg "Reverting Hadoop Environment Variables Changes"
	fi
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
	printMsg "Downloading Hadoop Tar (Will skip if $HADOOP_FILENAME is found in $HADOOP_LOCATION or `pwd` folder)"
	if [ ! -f $HADOOP_FILENAME ] && [ ! -f $HADOOP_LOCATION/$HADOOP_FILENAME ]; then
		wget $HADOOP_DOWNLOAD >> /tmp/hadoop_install.log 2>&1
	fi
	if [ -f $HADOOP_FILENAME ]; then
		sudo mv /tmp/$HADOOP_FILENAME $HADOOP_LOCATION 	
	fi
}

function hadoop_setup()
{
	printMsg "Installing Hadoop (Installation Folder: $HADOOP_LOCATION/hadoop)"
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
	printMsg "Configuring Hadoop (Installation Folder: $HADOOP_LOCATION/hadoop/)"
	
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

	#Giving sudo permissions to the user
	echo "...................Giving sudo permission to the newly created user........................"
	usermod -aG sudo hadoop

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
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/ >> /home/hadoop/hadoop/etc/hadoop/hadoop-env.sh
	#sudo sed "s/# export JAVA_HOME=\/usr\/lib\/j2sdk[1-9].[1-9]-sun/export JAVA_HOME=\/usr\/lib\/jvm\/java-6-sun/g" $HADOOP_LOCATION/hadoop/etc/hadoop/hadoop-env.sh > /tmp/hadoop-env.sh.mod
	#sudo mv /tmp/hadoop-env.sh.mod $HADOOP_LOCATION/hadoop/etc/hadoop/hadoop-env.sh

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

	#Changing ownership of $HADOOP_LOCATION/hadoop folder to $USER_NAME user
	#sudo chown -R $USER_NAME:$USER_NAME $HADOOP_LOCATION/hadoop
	#sudo chmod -R 750 $HADOOP_LOCATION/hadoop

	#Creating /app/hadoop/tmp folder for hadoop file system and changing ownership to $USER_NAME user
	sudo mkdir -p /app/hadoop/tmp
	sudo chown -R $USER_NAME:$USER_NAME /app
	sudo chmod -R 750 /app
}

function install_hadoop()
{
	check_sudo
	clear
	print_header "Install Hadoop"
	echo -ne "Ques: Will this system be Master/Slave(m/s)? "
	read -n 1 nodeType
	nodeType=`echo $nodeType | tr '[:upper:]' '[:lower:]'`
	echo -e "\n"
	if [[ "$nodeType" = "m" ]] || [[ "$nodeType" = "s" ]]; then
		(install_java) & spinner $!
		(add_user_group) & spinner $!
		(install_ssh) & spinner $!
		(ssh_configure "$nodeType") & spinner $!
		(ipv6_file "a") & spinner $!
		(host_file "a") & spinner $!
		(bashrc_file "a") & spinner $!
		(hadoop_download) & spinner $!
		(hadoop_setup) & spinner $!
		(hadoop_configure "$nodeType") & spinner $!
		tput setf 2
		echo "=> Hadoop installation complete";
		echo "=> Format hadoop filesystem using the below code:";
		tput sgr0
		tput setf 6
		echo "$HADOOP_LOCATION/hadoop/bin/hdfs namenode -format";
		tput sgr0
		if [ `cat /proc/sys/net/ipv6/etc/hadoop/all/disable_ipv6` -eq 0 ]; then
			tput setf 6
			echo "=> Backup of /etc/sysctl.conf has been created as /etc/sysctl.conf.$now)";
			tput setf 4
	    		echo "=> Restarting system is RECOMMENDED";
			tput sgr0
		fi;
	else
		print_error "Incorrect input"
	fi
	echo -e "\nPress a key. . ."
	read -n 1	
}

install_hadoop
    
