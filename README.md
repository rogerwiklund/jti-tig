## Juniper Telemetry Interface & Telegraf, InfluxDB and Grafana
This repo contains a bash script that will install and configure Telegraf, InfluxDB and Grafana for the official repos.  
A pre-build Grafan Dashboard is provided to monitor Streaming Telemetry from Juniper devices.

- Telegraf-latest
- InfluxDB 1.8x-latest
- Grafana Enterprise-latest

InfluxDB 1.8 is used because 2.x uses the Flux query language which Grafana has no suppport for when using the query builder.  
When InfluxDB 3.0 community edition is released I will update this script to use 3.0 instead which uses SQL.

## Requirements
- Ubuntu Server 22.04.4 LTS
- Juniper devices capable of Telemetry Streaming using gNMI/gRPC/Openconfig

## Installation
```
git clone https://github.com/rogerwiklund/jti-tig.git
cd jti-tig
chmod +x install.sh
sudo ./install.sh
```

Example:
```
This script will install and configure Telegraf, InfluxDB and Grafana from the official repos.

Enter the _full_ FQDN for this server (example: grafana01.acme-corp.com): grafana01.acme-corp.com
Create a new database for InfluxDB (example: jti): jti
Create a new user for InfluxDB (example: admin): admin
Enter the password for the InfluxDB user: secret
Enter the database retention period in days (example: 90d): 30d
Enter the FQDN or IP of a Juniper device capable of Telemetry Streaming (you can add more after the installation): qfx01.acme-corp.com

Collected Information:
FQDN: grafana01.acme-corp.com
InfluxDB Database: jti
InfluxDB Username: admin
Password: *** (hidden)
Database Retention Period: 30d
Juniper Device FQDN/IP: qfx01.acme-corp.com

Do you want to continue? (yes/no): yes
```

- Self-signed certificates will be generated for Grafana and InfluxDB with the hostname given in the first prompt.  
- After the installation go to https://fqdn and login to Grafana with default admin/admin credentials.
- Download the jti_dashboard.json from this repo and import it to Grafana.
- Done!

## Junos configuration
```
set system services extension-service request-response grpc clear-text port 32767
set system services extension-service request-response grpc routing-instance mgmt_junos
set system services extension-service request-response grpc skip-authentication
```
- todo, info about mgmt_junos, config for tls, username/password
- make sure your re-filter allow traffic to TCP/32767

## Add more Juniper devices
Juniper devices are stored in /etc/telegraf/telegraf.d/device-inputs.jti.conf  
You can group multiple devices in a single inputs file, like QFX, EX, MX, SRX etc.
```
servers = ["leaf01.acme-corp.com:32767","leaf02.acme-corp.com:32767"]
```
You can also have one file per devices. This give you the most flexibility over what sensors and interval to pick.  

After you have added more input files, run:
```
sudo chown telegraf:telegraf /etc/telegraf/telegraf.d/*
sudo systemctl restart telegraf
sudo systemctl status telegraf <- check for errors
```
## Sensors for SRX Firewalls
```
"security_spu /junos/security/spu/cpu/usage",
"security_flows /junos/security/spu/flow/usage",
```

### Telegraf processors
Todo

## Juniper Telemetry Explorer
https://apps.juniper.net/telemetry-explorer/

## Juniper YANG Data Model Explorer
https://apps.juniper.net/ydm-explorer/

## Screenshots
![Image Alt text](/screenshots/screenshot1.png)
![Image Alt text](/screenshots/screenshot2.png)
![Image Alt text](/screenshots/screenshot3.png)
