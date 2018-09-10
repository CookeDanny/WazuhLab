#! /bin/bash


apt_install_prerequisites() {
  # Install prerequisites and useful tools
  sudo apt-get update
  sudo apt-get install -y jq whois build-essential git unzip
}

fix_eth1_static_ip() {
  # There's a fun issue where dhclient keeps messing with eth1 despite the fact
  # that eth1 has a static IP set. We workaround this by setting a static DHCP lease.
  sudo echo -e 'interface "eth1" {
  sudo send host-name = gethostname();
  sudo send dhcp-requested-address 192.168.38.5;
  }' >> /etc/dhcp/dhclient.conf
  sudo service networking restart
  # Fix eth1 if the IP isn't set correctly
  ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
  if [ "$ETH1_IP" != "192.168.38.5" ]; then
  sudo echo "Incorrect IP Address settings detected. Attempting to fix."
  sudo ifdown eth1
  sudo ip addr flush dev eth1
  sudo ifup eth1
  sudo ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [ "$ETH1_IP" == "192.168.38.5" ]; then
  sudo echo "The static IP has been fixed and set to 192.168.38.5"
    else
  sudo echo "Failed to fix the broken static IP for eth1. Exiting because this will cause problems with other VMs."
      exit 1
    fi
  fi
}

install_Wazuh() {
 #Install Wazuh Server
 sudo echo "Installing Wazuh Server"
 sudo apt://curl,apt-transport-https,lsb-release
 if [ ! -f /usr/bin/python ]; then ln -s /usr/bin/python3 /usr/bin/python; fi
 sudo curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
 sudo echo "deb https://packages.wazuh.com/3.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
 sudo apt-get update
 sudo apt-get install wazuh-manager
 sudo systemctl status wazuh-manager
 sudo service wazuh-manager status
 
 #Install Node.js
 sudo curl -sL https://deb.nodesource.com/setup_8.x | bash -
 sudo apt-get install nodejs
 sudo apt-get install wazuh-api
 sudo systemctl status wazuh-api
 sudo service wazuh-api status
 
 #Install Filebeat
 sudo curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
 sudo echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-6.x.list
 sudo apt-get update
 sudo apt-get install filebeat=6.4.0
 sudo curl -so /etc/filebeat/filebeat.yml https://github.com/m4g1cm4n/WazuhLab/Vagrant/filebeat.yml
 sudo systemctl daemon-reload
 sudo systemctl enable filebeat.service
 sudo systemctl start filebeat.service
}

install_python() {
  # Install Python 3.6.4
  if ! which /usr/local/bin/python3.6 > /dev/null; then
  sudo echo "Installing Python v3.6.4..."
  sudo wget https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tgz
  sudo tar -xvf Python-3.6.4.tgz
  cd Python-3.6.4 || exit
  sudo ./configure && make && make install
  cd /home/vagrant || exit
  else
  sudo echo "Python seems to be downloaded already.. Skipping."
  fi
}

install_elastic() {
  #Install Java JRE 8
  sudo add-apt-repository ppa:webupd8team/java
  sudo apt-get update
  sudo apt-get install oracle-java8-installer

  #Add Elastic Repo and GPG Key
  sudo apt-get install curl apt-transport-https
  sudo curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  sudo echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-6.x.list
  sudo apt-get update
  
  #Install ElasticSearch
  sudo apt-get install elasticsearch=6.4.0
  
  #Install & Start Service
  sudo systemctl daemon-reload
  sudo systemctl enable elasticsearch.service
  sudo systemctl start elasticsearch.service

  #Install Wazuh Template for ElasticSerach
  sudo curl https://raw.githubusercontent.com/wazuh/wazuh/3.6/extensions/elasticsearch/wazuh-elastic6-template-alerts.json | curl -XPUT 'http://localhost:9200/_template/wazuh' -H 'Content-Type: application/json' -d @-
  
  #Install Logstash
  sudo apt-get install logstash=1:6.4.0-1

  #Add Wazuh config for Logstash
  sudo curl -so /etc/logstash/conf.d/01-wazuh.conf https://raw.githubusercontent.com/wazuh/wazuh/3.6/extensions/logstash/01-wazuh-local.conf
  
  #Add user permissions to Ossec logs
  sudo usermod -a -G ossec logstash
  
  #Install & Search Logstash Service
  sudo systemctl daemon-reload
  sudo systemctl enable logstash.service
  sudo systemctl start logstash.service

  #Install Kibana
  sudo apt-get install kibana=6.4.0
  
  #Install Wazuh app Plugin for Kibana
  sudo export NODE_OPTIONS="--max-old-space-size=3072"
  sudo -u kibana /usr/share/kibana/bin/kibana-plugin install https://packages.wazuh.com/wazuhapp/wazuhapp-3.6.1_6.4.0.zip

  #Install & Start Kibana Service
  sudo systemctl daemon-reload
  sudo systemctl enable kibana.service
  sudo systemctl start kibana.service
  
  #Disable Elasticsearch repo to prevent updates breaking app
  sudo sed -i "s/^deb/#deb/" /etc/apt/sources.list.d/elastic-6.x.list
  sudo apt-get update
  
}

main() {
  
  apt_install_prerequisites
  fix_eth1_static_ip
  install_python
  install_Wazuh
  install_elastic
}

main
exit 0
