#!/bin/bash
#
#
### Change daemon/library restart from interactive to auto to avoid needing user input
sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
#
#
echo -e "\nThis script will install and configure Telegraf, InfluxDB and Grafana from the official repos.\n"

prompt_for_input() {
    local prompt_text=$1
    local variable_name=$2
    while true; do
        read -p "$prompt_text: " input
        if [[ -n $input ]]; then
            eval "$variable_name=\"$input\""
            break
        else
            echo "Error: Input cannot be empty. Please provide a valid value."
        fi
    done
}

while true; do
    prompt_for_input "Enter the _full_ FQDN for this server (example: grafana01.acme-corp.com)" fqdn
    prompt_for_input "Create a new database for InfluxDB (example: jti)" db_name
    prompt_for_input "Create a new user for InfluxDB (example: admin)" db_user
    prompt_for_input "Enter the password for the InfluxDB user" db_pwd
    prompt_for_input "Enter the database retention period in days (example: 90d)" db_retention
    prompt_for_input "Enter the FQDN or IP of a Juniper device capable of Telemetry Streaming (you can add more after the installation)" juniper_device

    echo -e "\nCollected Information:"
    echo "FQDN: $fqdn"
    echo "InfluxDB Database: $db_name"
    echo "InfluxDB Username: $db_user"
    echo "Password: *** (hidden)"
    echo "Database Retention Period: $db_retention"
    echo "Juniper Device FQDN/IP: $juniper_device"
    echo ""
    read -p "Do you want to continue? (yes/no): " continue_input

    if [[ $continue_input != "no" ]]; then
        break
    fi
done
#
#
echo $'\n##############################\nUpdating Ubuntu...\n##############################\n'
sleep 4
apt-get update -y
apt-get dist-upgrade -y
#
#
echo $'\n##############################\nInstalling Telegraf...\n##############################\n'
sleep 4
curl -s https://repos.influxdata.com/influxdata-archive.key > influxdata-archive.key
echo '943666881a1b8d9b849b74caebf02d3465d6beb716510d86a39f6c8e8dac7515 influxdata-archive.key' | sha256sum -c && cat influxdata-archive.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdata-archive.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' | tee /etc/apt/sources.list.d/influxdata.list
apt-get update -y
apt-get install telegraf -y

outputs_influxdb=$(cat <<EOF
# # Configuration for sending metrics to InfluxDB
[[outputs.influxdb]]
#   ## The full HTTP or UDP URL for your InfluxDB instance.
#   ##
#   ## Multiple URLs can be specified for a single cluster, only ONE of the
#   ## urls will be written to each interval.
#   # urls = ["unix:///var/run/influxdb.sock"]
#   # urls = ["udp://127.0.0.1:8089"]
    urls = ["https://127.0.0.1:8086"]
#
#   ## The target database for metrics; will be created as needed.
#   ## For UDP url endpoint database needs to be configured on server side.
    database = "$db_name"
#
#   ## The value of this tag will be used to determine the database.  If this
#   ## tag is not set the 'database' option is used as the default.
#   # database_tag = ""
#
#   ## If true, the 'database_tag' will not be included in the written metric.
#   # exclude_database_tag = false
#
#   ## If true, no CREATE DATABASE queries will be sent.  Set to true when using
#   ## Telegraf with a user without permissions to create databases or when the
#   ## database already exists.
#   # skip_database_creation = false
#
#   ## Name of existing retention policy to write to.  Empty string writes to
#   ## the default retention policy.  Only takes effect when using HTTP.
#   # retention_policy = ""
#
#   ## The value of this tag will be used to determine the retention policy.  If this
#   ## tag is not set the 'retention_policy' option is used as the default.
#   # retention_policy_tag = ""
#
#   ## If true, the 'retention_policy_tag' will not be included in the written metric.
#   # exclude_retention_policy_tag = false
#
#   ## Write consistency (clusters only), can be: "any", "one", "quorum", "all".
#   ## Only takes effect when using HTTP.
#   # write_consistency = "any"
#
#   ## Timeout for HTTP messages.
#   # timeout = "5s"
#
#   ## HTTP Basic Auth
    username = "$db_user"
    password = "$db_pwd"
#
#   ## HTTP User-Agent
#   # user_agent = "telegraf"
#
#   ## UDP payload size is the maximum packet size to send.
#   # udp_payload = "512B"
#
#   ## Optional TLS Config for use on HTTP connections.
#   # tls_ca = "/etc/telegraf/ca.pem"
#   # tls_cert = "/etc/telegraf/cert.pem"
#   # tls_key = "/etc/telegraf/key.pem"
#   ## Use TLS but skip chain & host verification
    insecure_skip_verify = true
#
#   ## HTTP Proxy override, if unset values the standard proxy environment
#   ## variables are consulted to determine which proxy, if any, should be used.
#   # http_proxy = "http://corporate.proxy:3128"
#
#   ## Additional HTTP headers
#   # http_headers = {"X-Special-Header" = "Special-Value"}
#
#   ## HTTP Content-Encoding for write request body, can be set to "gzip" to
#   ## compress body or "identity" to apply no encoding.
#   # content_encoding = "gzip"
#
#   ## When true, Telegraf will output unsigned integers as unsigned values,
#   ## i.e.: "42u".  You will need a version of InfluxDB supporting unsigned
#   ## integer values.  Enabling this option will result in field type errors if
#   ## existing data has been written.
#   # influx_uint_support = false
EOF
)

echo "$outputs_influxdb" > /etc/telegraf/telegraf.d/outputs.influxdb.conf

inputs_jti=$(cat <<EOF
# # Subscribe and receive OpenConfig Telemetry data using JTI
[[inputs.jti_openconfig_telemetry]]
#   ## List of device addresses to collect telemetry from
    servers = ["$juniper_device:32767"]
#
#   ## Authentication details. Username and password are must if device expects
#   ## authentication. Client ID must be unique when connecting from multiple instances
#   ## of telegraf to the same device
#   username = "user"
#   password = "pass"
#   client_id = "telegraf"
#
#   ## Frequency to get data
    sample_frequency = "10000ms"
#
#   ## Sensors to subscribe for
#   ## A identifier for each sensor can be provided in path by separating with space
#   ## Else sensor path will be used as identifier
#   ## When identifier is used, we can provide a list of space separated sensors.
#   ## A single subscription will be created with all these sensors and data will
#   ## be saved to measurement with this identifier name
    sensors = [
    "/interfaces/",
    "/components/",
    "/network-instances/",
    "system_alarms /system/alarms/alarm/",
   ]
#
#   ## We allow specifying sensor group level reporting rate. To do this, specify the
#   ## reporting rate in Duration at the beginning of sensor paths / collection
#   ## name. For entries without reporting rate, we use configured sample frequency
#   sensors = [
#    "1000ms customReporting /interfaces /lldp",
#    "2000ms collection /components",
#    "/interfaces",
#   ]
#
#   ## Timestamp Source
#   ## Set to 'collection' for time of collection, and 'data' for using the time
#   ## provided by the _timestamp field.
#   # timestamp_source = "collection"
#
#   ## Optional TLS Config
#   # enable_tls = false
#   # tls_ca = "/etc/telegraf/ca.pem"
#   # tls_cert = "/etc/telegraf/cert.pem"
#   # tls_key = "/etc/telegraf/key.pem"
#   ## Minimal TLS version to accept by the client
#   # tls_min_version = "TLS12"
#   ## Use TLS but skip chain & host verification
#   # insecure_skip_verify = false
#
#   ## Delay between retry attempts of failed RPC calls or streams. Defaults to 1000ms.
#   ## Failed streams/calls will not be retried if 0 is provided
#   retry_delay = "1000ms"
#
#   ## Period for sending keep-alive packets on idle connections
#   ## This is helpful to identify broken connections to the server
#   # keep_alive_period = "10s"
#
#   ## To treat all string values as tags, set this to true
#   str_as_tags = false
fielddrop = [ "/interfaces/interface/subinterfaces/*","/interfaces/interface/aggregation/*" ]
EOF
)

echo "$inputs_jti" > /etc/telegraf/telegraf.d/$juniper_device-inputs.jti.conf

processors_jti=$(cat <<EOF
#
# Convert various measurements from string to float for easier manipulation in Grafana
[[processors.rename]]
  [processors.rename.tagpass]
    "/components/component/properties/property/@name" = ["cpu-utilization-idle","memory-utilization-buffer","temperature","uptime"]
  [[processors.rename.replace]]
    field = "/components/component/properties/property/state/value"
    dest = "/components/component/properties/property/state/value_float"
[[processors.converter]]
  [processors.converter.fields]
    float = ["/components/component/properties/property/state/value_float"]
#
# Normalize loopback-mode from string to boolean
[[processors.converter]]
  [processors.converter.fields]
    boolean = ["/interfaces/interface/state/loopback-mode"]
#
# Normalize Junos EVO to match Junos
[[processors.converter]]
  [processors.converter.fields]
    integer = ["/network-instances/network-instance/protocols/protocol/bgp/neighbors/neighbor/timers/*","/network-instances/network-instance/protocols/protocol/bgp/peer-groups/peer-group/timers/*","/network-instances/network-instance/protocols/protocol/bgp/neighbors/neighbor/graceful-restart/state/stale-routes-time","/network-instances/network-instance/protocols/protocol/bgp/global/graceful-restart/state/stale-routes-time","/network-instances/network-instance/protocols/protocol/bgp/peer-groups/peer-group/graceful-restart/state/stale-routes-time"]
EOF
)

echo "$processors_jti" > /etc/telegraf/telegraf.d/processors.conf

chown telegraf:telegraf /etc/telegraf/telegraf.d/*
chmod 640 /etc/telegraf/telegraf.d/*

systemctl start telegraf
#
#
echo $'\n##############################\nInstalling InfluxDB...\n##############################\n'
sleep 4
wget -q https://repos.influxdata.com/influxdata-archive_compat.key
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | tee /etc/apt/sources.list.d/influxdata.list
apt-get update -y
apt-get install -y influxdb

openssl req -nodes -x509 -sha256 -newkey rsa:2048 \
  -keyout /etc/ssl/influxdb-selfsigned.key \
  -out /etc/ssl/influxdb-selfsigned.crt \
  -days 3560 \
  -subj "/C=US/ST=California/L=Toontown/O=Acme inc./OU=IT/CN=$fqdn"  \
  -addext "subjectAltName = DNS:$fqdn"

chown influxdb:influxdb  /etc/ssl/influxdb-selfsigned.*

systemctl unmask influxdb.service
systemctl start influxdb

influx -execute "CREATE USER $db_user WITH PASSWORD '$db_pwd' WITH ALL PRIVILEGES"
influx -execute "CREATE DATABASE $db_name WITH DURATION $db_retention"

sed -i 's/# auth-enabled = false/auth-enabled = true/g' /etc/influxdb/influxdb.conf
sed -i 's/# https-enabled = false/https-enabled = true/g' /etc/influxdb/influxdb.conf
sed -i 's/# https-certificate = "\/etc\/ssl\/influxdb.pem"/https-certificate = "\/etc\/ssl\/influxdb-selfsigned.crt"/g' /etc/influxdb/influxdb.conf
sed -i 's/# https-private-key = ""/https-private-key = "\/etc\/ssl\/influxdb-selfsigned.key"/g' /etc/influxdb/influxdb.conf

sudo systemctl restart influxdb
#
#
echo $'\n##############################\nInstalling Grafana...\n##############################\n'
sleep 4
apt-get install -y apt-transport-https software-properties-common wget
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get update -y
apt-get install -y grafana-enterprise

openssl req -nodes -x509 -sha256 -newkey rsa:2048 \
  -keyout /etc/ssl/grafana-selfsigned.key \
  -out /etc/ssl/grafana-selfsigned.crt \
  -days 3560 \
  -subj "/C=US/ST=California/L=Toontown/O=Acme inc./OU=IT/CN=$fqdn"  \
  -addext "subjectAltName = DNS:$fqdn"

chown grafana:grafana /etc/ssl/grafana-selfsigned.*

sed -i "s/;protocol = http/protocol = https/" /etc/grafana/grafana.ini
sed -i "s/;http_port = 3000/http_port = 443/" /etc/grafana/grafana.ini
sed -i "s/;domain = localhost/domain = $fqdn/" /etc/grafana/grafana.ini
sed -i "s/;cert_file =/cert_file = \/etc\/ssl\/grafana-selfsigned.crt/" /etc/grafana/grafana.ini
sed -i "s/;cert_key =/cert_key = \/etc\/ssl\/grafana-selfsigned.key/" /etc/grafana/grafana.ini

mkdir -p /etc/systemd/system/grafana-server.service.d

grafana_override=$(cat <<EOF
[Service]
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
PrivateUsers=false
EOF
)

echo "$grafana_override" > /etc/systemd/system/grafana-server.service.d/override.conf

grafana_datasource=$(cat <<EOF
apiVersion: 1
datasources:
 - name: InfluxDB
   type: influxdb
   access: proxy
   url: https://localhost:8086
   user: $db_user
   isDefault: false
   jsonData:
     dbName: "$db_name"
     tlsSkipVerify: true
     version: InfluxQL
   secureJsonData:
     password: "$db_pwd"
   editable: true
EOF
)

echo "$grafana_datasource" > /etc/grafana/provisioning/datasources/jti_influxdb.yaml
chown root:grafana /etc/grafana/provisioning/datasources/jti_influxdb.yaml
chmod 640 /etc/grafana/provisioning/datasources/jti_influxdb.yaml

#below is kept for reference
#grafana_dashboard=$(cat <<EOF
#apiVersion: 1
#
#providers:
# - name: 'default'
#   orgId: 1
#   folder: ''
#   folderUid: ''
#   type: file
#   options:
#     path: /var/lib/grafana/dashboards
#EOF
#)
#
#echo "$grafana_dashboard" > /etc/grafana/provisioning/dashboards/jti_dashboard.yaml
#chown root:grafana /etc/grafana/provisioning/dashboards/jti_dashboard.yaml
#chmod 640 /etc/grafana/provisioning/dashboards/jti_dashboard.yaml

#wget -P /var/lib/grafana/dashboards/ https://raw.githubusercontent.com/rogerwiklund/jti-tig/main/jti_dashboard.json
#chown -R grafana:grafana /var/lib/grafana/dashboards/

systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
#
#
echo ""
echo "####################"
echo "Installation completed"
echo ""
echo "Go to https://fqdn:443 with default credentials admin/admin to access Grafana"
echo "Download jti_dashboard.json from Github and import it to Grafana"
echo ""
echo ""
echo "Telegraf config files - /etc/telegraf/telegraf.d/"
echo "InfluxDB config file - /etc/influxdb/influxdb.conf"
echo "Grafana config file - /etc/grafana/grafana.ini"
echo ""
echo "systemctl start/stop/restart telegraf"
echo "systemctl start/stop/restart influxdb"
echo "systemctl start/stop/restart grafana-server"
echo "####################"
echo ""
