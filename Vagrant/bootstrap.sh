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
 apt://curl,apt-transport-https,lsb-release
 if [ ! -f /usr/bin/python ]; then ln -s /usr/bin/python3 /usr/bin/python; fi
 curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
 echo "deb https://packages.wazuh.com/3.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
 apt-get update
 apt-get install wazuh-manager
 systemctl status wazuh-manager
 service wazuh-manager status
 
 #Install Node.js
 curl -sL https://deb.nodesource.com/setup_8.x | bash -
 apt-get install nodejs
 apt-get install wazuh-api
 systemctl status wazuh-api
 service wazuh-api status
 
 #Install Filebeat
 curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
 echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-6.x.list
 apt-get update
 apt-get install filebeat=6.4.0
 curl -so /etc/filebeat/filebeat.yml https://github.com/m4g1cm4n/WazuhLab/Vagrant/filebeat.yml
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



  

main() {
  
  apt_install_prerequisites
  fix_eth1_static_ip
  install_python
}

main
exit 0
