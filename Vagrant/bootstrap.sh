#! /bin/bash


apt_install_prerequisites() {
  # Install prerequisites and useful tools
  apt-get update
  apt-get install -y jq whois build-essential git unzip
}

fix_eth1_static_ip() {
  # There's a fun issue where dhclient keeps messing with eth1 despite the fact
  # that eth1 has a static IP set. We workaround this by setting a static DHCP lease.
  echo -e 'interface "eth1" {
  send host-name = gethostname();
  send dhcp-requested-address 192.168.38.5;
  }' >> /etc/dhcp/dhclient.conf
  service networking restart
  # Fix eth1 if the IP isn't set correctly
  ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
  if [ "$ETH1_IP" != "192.168.38.5" ]; then
  echo "Incorrect IP Address settings detected. Attempting to fix."
  ifdown eth1
  ip addr flush dev eth1
  ifup eth1
  ETH1_IP=$(ifconfig eth1 | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [ "$ETH1_IP" == "192.168.38.5" ]; then
  echo "The static IP has been fixed and set to 192.168.38.5"
    else
  echo "Failed to fix the broken static IP for eth1. Exiting because this will cause problems with other VMs."
      exit 1
    fi
  fi
}

install_Wazuh() {
 #Install Wazuh Server
 echo "Installing Wazuh Server"
 apt-get update
 apt-get install curl apt-transport-https lsb-release
 if [ ! -f /usr/bin/python ]; then ln -s /usr/bin/python3 /usr/bin/python; fi
 curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
 echo "deb https://packages.wazuh.com/3.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
 apt-get update
 apt-get install wazuh-manager
 systemctl status wazuh-manager
 
 #Install Node.js
 curl -sL https://deb.nodesource.com/setup_8.x | bash -
 apt-get install nodejs
 apt-get install wazuh-api
 systemctl status wazuh-api
 
 #Install Filebeat
 curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
 echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-6.x.list
 apt-get update
 apt-get install filebeat=6.4.0
 curl -so /etc/filebeat/filebeat.yml https://raw.githubusercontent.com/m4g1cm4n/WazuhLab/master/Vagrant/filebeat.yml
 systemctl daemon-reload
 systemctl enable filebeat.service
 systemctl start filebeat.service
}

install_python() {
  # Install Python 3.6.4
  if ! which /usr/local/bin/python3.6 > /dev/null; then
  echo "Installing Python v3.6.4..."
  wget https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tgz
  tar -xvf Python-3.6.4.tgz
  cd Python-3.6.4 || exit
  ./configure && make && make install
  cd /home/vagrant || exit
  else
  echo "Python seems to be downloaded already.. Skipping."
  fi
}

install_elastic() {
  #Install Java JRE 8
  add-apt-repository ppa:webupd8team/java
  apt-get update
  apt-get install oracle-java8-installer

  #Add Elastic Repo and GPG Key
  apt-get install curl apt-transport-https
  curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-6.x.list
  apt-get update
  
  #Install ElasticSearch
  apt-get install elasticsearch=6.4.0
  
  #Install & Start Service
  systemctl daemon-reload
  systemctl enable elasticsearch.service
  systemctl start elasticsearch.service

  #Install Wazuh Template for ElasticSerach
  curl https://raw.githubusercontent.com/wazuh/wazuh/3.6/extensions/elasticsearch/wazuh-elastic6-template-alerts.json | curl -XPUT 'http://localhost:9200/_template/wazuh' -H 'Content-Type: application/json' -d @-
  
  #Install Logstash
  apt-get install oracle-java8-installer #Hopefully will fix JAVA_HOME error
  apt-get install logstash=1:6.4.0-1

  #Add Wazuh config for Logstash
  curl -so /etc/logstash/conf.d/01-wazuh.conf https://raw.githubusercontent.com/wazuh/wazuh/3.6/extensions/logstash/01-wazuh-local.conf
  
  #Add user permissions to Ossec logs
  usermod -a -G ossec logstash
  
  #Install & Search Logstash Service
  systemctl daemon-reload
  systemctl enable logstash.service
  systemctl start logstash.service

  #Install Kibana
  apt-get install kibana=6.4.0
  
  #Install Wazuh app Plugin for Kibana
  export NODE_OPTIONS="--max-old-space-size=3072"
  sudo -u kibana /usr/share/kibana/bin/kibana-plugin install https://packages.wazuh.com/wazuhapp/wazuhapp-3.6.1_6.4.0.zip

  #Install & Start Kibana Service
  systemctl daemon-reload
  systemctl enable kibana.service
  systemctl start kibana.service
  
  #Disable Elasticsearch repo to prevent updates breaking app
  sed -i "s/^deb/#deb/" /etc/apt/sources.list.d/elastic-6.x.list
  apt-get update
  
}

main() {
  
  apt_install_prerequisites
  fix_eth1_static_ip
  #install_python - not needed?
  install_Wazuh
  install_elastic
}

main
exit 0
