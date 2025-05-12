#!/bin/bash

# Function to print status
print_status() {
    echo "========> $1"
}

# Exit on any error
set -e

# Variables
jira_app_url_env="jira_deloitte.com"
JIRA_VERSION="9.12.8"
INSTALL_DIR="/App/JIRA"
DATA_DIR="/App/JIRA_DATA"
SHARED_DIR="/efs/JIRA_SHARED"
JIRA_USER="jira"
JIRA_GROUP="jira"
JIRA_PACKAGE="atlassian-jira-software-${JIRA_VERSION}.tar.gz"
DOWNLOAD_URL="https://product-downloads.atlassian.com/software/jira/downloads/${JIRA_PACKAGE}"
DB_URL_POSTGRESQL="database-1.cxuamg0kc9bx.us-west-2.rds.amazonaws.com"
DB_USERNAME="postgres"
DB_PASSWORD="Login%12345"

# Update packages and install required tools
sudo apt update -y
sudo apt install wget unzip openjdk-17-jdk -y

# Create user and group if not exist
if id -u "$JIRA_USER" >/dev/null 2>&1; then
    print_status "User $JIRA_USER already exists"
else
    print_status "Creating user $JIRA_USER"
    sudo groupadd $JIRA_GROUP
    sudo useradd -m -d /home/$JIRA_USER -g $JIRA_GROUP $JIRA_USER
fi

# Create directories
for dir in "$INSTALL_DIR" "$DATA_DIR" "$SHARED_DIR"; do
    if [ ! -d "$dir" ]; then
        print_status "Creating $dir"
        sudo mkdir -p $dir
    fi
done

# Download Jira package
print_status "Downloading Jira $JIRA_VERSION"
wget $DOWNLOAD_URL

# Extract Jira package
print_status "Extracting Jira to $INSTALL_DIR"
sudo tar -zxvf $JIRA_PACKAGE -C $INSTALL_DIR --strip-components=1

# Download and extract JDK
print_status "Downloading and extracting JDK 17"
wget https://download.java.net/openjdk/jdk17/ri/openjdk-17+35_linux-x64_bin.tar.gz
sudo tar -zxvf openjdk-17+35_linux-x64_bin.tar.gz -C $INSTALL_DIR
sudo mv $INSTALL_DIR/jdk-17 $INSTALL_DIR/jre

# Set JAVA_HOME in setenv.sh
print_status "Updating JAVA_HOME in Jira setenv.sh"
echo 'JAVA_HOME="/App/JIRA/jre"' | sudo tee -a $INSTALL_DIR/bin/setenv.sh
echo 'export JAVA_HOME' | sudo tee -a $INSTALL_DIR/bin/setenv.sh

# Set permissions
print_status "Setting directory permissions"
sudo chown -R $JIRA_USER:$JIRA_GROUP $INSTALL_DIR $DATA_DIR $SHARED_DIR

# Configure Jira home directory
print_status "Configuring Jira home directory"
echo "jira.home = $DATA_DIR" | sudo tee $INSTALL_DIR/atlassian-jira/WEB-INF/classes/jira-application.properties

# Create dbconfig.xml
print_status "Creating dbconfig.xml"
sudo tee $DATA_DIR/dbconfig.xml <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<jira-database-config>
  <name>defaultDS</name>
  <delegator-name>default</delegator-name>
  <database-type>postgres72</database-type>
  <schema-name>public</schema-name>
  <jdbc-datasource>
    <url>jdbc:postgresql://$DB_URL_POSTGRESQL:5432/jiradb</url>
    <driver-class>org.postgresql.Driver</driver-class>
    <username>$DB_USERNAME</username>
    <password>$DB_PASSWORD</password>
    <pool-min-size>40</pool-min-size>
    <pool-max-size>40</pool-max-size>
    <pool-max-wait>30000</pool-max-wait>
    <validation-query>select 1</validation-query>
    <min-evictable-idle-time-millis>60000</min-evictable-idle-time-millis>
    <time-between-eviction-runs-millis>300000</time-between-eviction-runs-millis>
    <pool-max-idle>40</pool-max-idle>
    <pool-remove-abandoned>true</pool-remove-abandoned>
    <pool-remove-abandoned-timeout>300</pool-remove-abandoned-timeout>
    <pool-test-on-borrow>false</pool-test-on-borrow>
    <pool-test-while-idle>true</pool-test-while-idle>
    <connection-properties>tcpKeepAlive=true</connection-properties>
  </jdbc-datasource>
</jira-database-config>
EOL

# Update server.xml
print_status "Updating server.xml"
sudo tee $INSTALL_DIR/conf/server.xml > /dev/null <<EOF
<?xml version="1.0" encoding="utf-8"?>
<!-- server.xml content here with placeholder -->
EOF
sudo sed -i "s/jira_app_url/$jira_app_url_env/g" $INSTALL_DIR/conf/server.xml

# Create jira-config.properties
print_status "Creating jira-config.properties"
sudo tee $DATA_DIR/jira-config.properties > /dev/null <<EOL
jira.websudo.is.disabled = true
jira.autoexport=false
EOL

# Write setenv.sh (use content from original script or reuse existing file)

# Create systemd service
print_status "Creating Jira systemd service"
sudo tee /etc/systemd/system/jira.service > /dev/null <<EOL
[Unit]
Description=Atlassian Jira
After=network.target

[Service]
Type=forking
User=$JIRA_USER
LimitNOFILE=20000
PIDFile=$INSTALL_DIR/work/catalina.pid
ExecStart=$INSTALL_DIR/bin/start-jira.sh
ExecStop=$INSTALL_DIR/bin/stop-jira.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Final permissions
sudo chmod 664 /etc/systemd/system/jira.service
sudo chown -R $JIRA_USER:$JIRA_GROUP $INSTALL_DIR $DATA_DIR $SHARED_DIR

# Reload and start Jira
print_status "Reloading systemd"
sudo systemctl daemon-reload

print_status "Enabling Jira service"
sudo systemctl enable jira.service

print_status "Starting Jira service"
#sudo systemctl start jira.service

print_status "Jira installation and service setup complete on Ubuntu 24.04!"
