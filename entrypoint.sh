#!/bin/bash
# encoding: utf-8

C_ICAP_USER=c-icap
C_ICAP_DIR=/usr/local/c-icap

mkdir -p $C_ICAP_DIR/share/c_icap/templates
mkdir -p $C_ICAP_DIR/var/log
mkdir -p $C_ICAP_DIR/var/run/c-icap
useradd $C_ICAP_USER -U -b $C_ICAP_DIR
chown -R ${C_ICAP_USER}:${C_ICAP_USER} $C_ICAP_DIR
echo "#===added config===" >> $C_ICAP_DIR/etc/c-icap.conf
echo "User $C_ICAP_USER" >> $C_ICAP_DIR/etc/c-icap.conf
echo "Group $C_ICAP_USER" >> $C_ICAP_DIR/etc/c-icap.conf
echo "PidFile $C_ICAP_DIR/var/run/c-icap/c-icap.pid" >> $C_ICAP_DIR/etc/c-icap.conf
echo "CommandsSocket $C_ICAP_DIR/var/run/c-icap/c-icap.ctl" >> $C_ICAP_DIR/etc/c-icap.conf
#echo "Service xss srv_xss.so" >> $C_ICAP_DIR/etc/c-icap.conf
cat $C_ICAP_DIR/etc/c-icap.conf | grep added\ config -A1000 #fflush()
echo "#===added config==="
$C_ICAP_DIR/bin/c-icap -D -d 10 -f $C_ICAP_DIR/etc/c-icap.conf


SQUID_USER=squid
SQUID_DIR=/usr/local/squid

FILE=/usr/local/squid/myCA.der
size=$(wc -c <"$FILE")
if [ $size -ne 0 ]; then
	echo " "
	echo "$FILE exists."
	echo " "
else
	openssl req -new -newkey rsa:2048 -nodes -days 3650 -x509 -keyout $SQUID_DIR/myCA.pem -out $SQUID_DIR/myCA.crt \
 -subj "/C=US/ST=Oklahoma/L=Jenks/O=GMG/OU=GMG/CN=squid.local"
	openssl x509 -in $SQUID_DIR/myCA.crt -outform DER -out $SQUID_DIR/myCA.der
	openssl pkcs12 -legacy -passout pass:pass -export -in $SQUID_DIR/myCA.crt -inkey $SQUID_DIR/myCA.pem -out cert.p12
 
 	#openssl req -new -sha256 -key $SQUID_DIR/myCA.pem -out csr2.csr -subj "/C=US/ST=Oklahoma/L=Jenks/O=GMG/OU=GMG/CN=squid.local"
  	#openssl req x509 -sha256 -days 365 -key $SQUID_DIR/myCA.pem -in csr2.csr -out $SQUID_DIR/certificate3.pem
   	#openssl pkcs12 -export -out $SQUID_DIR/keyStore2.p12 -inkey $SQUID_DIR/myCA.pem -in $SQUID_DIR/certificate2.pem
fi

mkdir -p $SQUID_DIR/var/lib
$SQUID_DIR/libexec/security_file_certgen -c -s $SQUID_DIR/var/lib/ssl_db -M 4MB
mkdir -p $SQUID_DIR/var/cache
useradd $SQUID_USER -U -b $SQUID_DIR
chown 700 $SQUID_DIR/myCA.pem
chown -R ${SQUID_USER}:${SQUID_USER} $SQUID_DIR

echo " "
echo "checking if squid.conf exists"
echo " "
cp $SQUID_DIR/etc/squid.conf $SQUID_DIR/etc/squid-bk.conf 
FILEE=$SQUID_DIR/etc/squid-bk.conf

if grep -q "#====added config===" $SQUID_DIR/etc/squid.conf; then
	echo "===================conf exists======================="
else
	echo " "
	echo "Adding special sauce"
	echo " "

	echo "#====added config===" >> $SQUID_DIR/etc/squid.conf
	echo "cache_effective_user $SQUID_USER" >> $SQUID_DIR/etc/squid.conf
	echo "cache_effective_group $SQUID_USER" >> $SQUID_DIR/etc/squid.conf
	echo "always_direct allow all" >> $SQUID_DIR/etc/squid.conf
	echo "icap_service_failure_limit -1" >> $SQUID_DIR/etc/squid.conf
	echo "ssl_bump bump all" >> $SQUID_DIR/etc/squid.conf
	echo "sslproxy_cert_error allow all" >> $SQUID_DIR/etc/squid.conf
	sed "/^http_port 3128$/d" -i $SQUID_DIR/etc/squid.conf
	sed "s/^http_access allow localhost$/http_access allow all/" -i $SQUID_DIR/etc/squid.conf
	echo "http_port 3128 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=4MB cert=$SQUID_DIR/myCA.crt key=$SQUID_DIR/myCA.pem" >> $SQUID_DIR/etc/squid.conf
	echo "sslcrtd_program $SQUID_DIR/libexec/security_file_certgen -s $SQUID_DIR/var/lib/ssl_db -M 4MB" >> $SQUID_DIR/etc/squid.conf
	echo "icap_enable on" >> $SQUID_DIR/etc/squid.conf
	echo "icap_preview_enable on" >> $SQUID_DIR/etc/squid.conf
	echo "icap_preview_size 1024" >> $SQUID_DIR/etc/squid.conf
	echo "icap_206_enable on" >> $SQUID_DIR/etc/squid.conf
	echo "icap_persistent_connections on" >> $SQUID_DIR/etc/squid.conf
	echo "adaptation_send_client_ip off" >> $SQUID_DIR/etc/squid.conf
	echo "adaptation_send_username off" >> $SQUID_DIR/etc/squid.conf
	echo "icap_service srv_echo_req reqmod_precache icap://127.0.0.1:1344/echo"  >> $SQUID_DIR/etc/squid.conf
	echo "icap_service srv_echo_resp respmod_precache icap://127.0.0.1:1344/echo" >> $SQUID_DIR/etc/squid.conf
	echo "adaptation_service_chain svc_echo_req_chain srv_echo_req" >> $SQUID_DIR/etc/squid.conf
	echo "adaptation_service_chain svc_echo_resp_chain srv_echo_resp">> $SQUID_DIR/etc/squid.conf
	echo "adaptation_access svc_echo_req_chain allow all">> $SQUID_DIR/etc/squid.conf
	echo "adaptation_access svc_echo_resp_chain allow all">> $SQUID_DIR/etc/squid.conf
fi
echo "done checking....and or modifying."
$SQUID_DIR/sbin/squid -d 10 -f $SQUID_DIR/etc/squid.conf
echo "entering bash"
bash
