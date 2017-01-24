#!/bin/bash
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"

while getopts i:p:e:d:a:f:c:w:x: option
do	case "$option" in
     i) ipAddress=$OPTARG;;
     p) port=$OPTARG;;
     e) entityId=$OPTARG;;
     d) authFqdn=$OPTARG;;
     a) authIp=$OPTARG;;
     f) domainFqdn=$OPTARG;;
     c) sslCert=$OPTARG;;
     w) sslPswd=$OPTARG;;
     x) passwd=$OPTARG;;
    esac 
done

user="admin"

# download and install Certificate
echo "Starting Certificate download"
certificate_location=$sslCert
curl -k -s -f --retry 5 --retry-delay 10 --retry-max-time 10 -o /config/o365FedCert.pfx $certificate_location
 
response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/crypto/pkcs12 -d '{"command": "install","name": "o365FedCert","options": [ { "from-local-file": "/config/o365FedCert.pfx" }, { "passphrase": "'"$sslPswd"'" } ] }' -o /dev/null)

if [[ $response_code != 200  ]]; then
     echo "Failed to install SSL cert; exiting with response code '"$response_code"'"
     exit
else 
     echo "Certificate download complete."
fi

# download iApp templates
template_location="http://cdn.f5.com/product/blackbox/staging/azure"

for template in f5.microsoft_office_365_idp.v1.1.0.tmpl
do
     curl -k -s -f --retry 5 --retry-delay 10 --retry-max-time 10 -o /config/$template $template_location/$template
     response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/config -d '{"command": "load","name": "merge","options": [ { "file": "/config/'"$template"'" } ] }' -o /dev/null)
     if [[ $response_code != 200  ]]; then
          echo "Failed to install iApp template; exiting with response code '"$response_code"'"
          exit
     else
          echo "iApp template installation complete."
     fi
     sleep 10
done

# deploy application
response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"o365","partition":"Common","deviceGroup":"none","strictUpdates":"disabled","template":"/Common/f5.microsoft_office_365_idp.v1.1.0","trafficGroup":"traffic-group-local-only","tables":[{"name":"apm__active_directory_servers","columnNames":["fqdn","addr"],"rows":[{"row":["'"$authFqdn"'","'"$authIp"'"]}]}],"variables":[{"name":"apm__aaa_profile","encrypted":"no","value":"/#create_new#"},{"name":"apm__ad_monitor","encrypted":"no","value":"ad_icmp"},{"name":"apm__credentials","encrypted":"no","value":"no"},{"name":"apm__log_settings","encrypted":"no","value":"/Common/default-log-setting"},{"name":"apm__login_domain","encrypted":"no","value":"'"$domainFqdn"'"},{"name":"apm__saml_entity_id","encrypted":"no","value":"'"$entityId"'"},{"name":"apm__saml_entity_id_format","encrypted":"no","value":"URL"},{"name":"general__assistance_options","encrypted":"no","value":"full"},{"name":"general__config_mode","encrypted":"no","value":"basic"},{"name":"idp_encryption__cert","encrypted":"no","value":"/Common/o365FedCert.crt"},{"name":"idp_encryption__key","encrypted":"no","value":"/Common/o365FedCert.key"},{"name":"webui_virtual__addr","encrypted":"no","value":"'"$ipAddress"'"},{"name":"webui_virtual__cert","encrypted":"no","value":"/Common/o365FedCert.crt"},{"name":"webui_virtual__key","encrypted":"no","value":"/Common/o365FedCert.key"},{"name":"webui_virtual__port","encrypted":"no","value":"'"$port"'"}]}' -o /dev/null)

if [[ $response_code != 200  ]]; then
     echo "Failed to install iApp template; exiting with response code '"$response_code"'"
     exit
else 
     echo "Deployment complete."
fi
exit
