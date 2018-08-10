#!/bin/bash

# Quick script to generate a CA, intermediate, and end certificate

if [ -z "${1}" ] ; then
    echo "No openssl provided"
    exit 1
fi

if [ -z "${2}" ] ; then
    echo "No target directory provided"
    exit 2
fi

OPENSSL="${1}"
certpath="${2}"

# Configure the CA
mkdir -p $certpath/ca.db.certs
touch $certpath/ca.db.index
echo 01 > $certpath/ca.db.serial

cat > $certpath/ca.conf <<'EOF'
default_ca = ca_default

[ca_default]
dir = REPLACE_WITH_CERTPATH
certs = $dir
new_certs_dir = $dir/ca.db.certs
database = $dir/ca.db.index
serial = $dir/ca.db.serial
RANDFILE = $dir/ca.db.rand
certificate = $dir/ca.crt
private_key = $dir/ca.key
default_days = 1
default_crl_days = 1
default_md = md5
preserve = no
policy = generic_policy
x509_extensions = usr_cert

[generic_policy]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[usr_cert]
authorityInfoAccess = OCSP;URI:http://localhost:8080
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer

[v3_ocsp]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = OCSPSigning

[v3_ca]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = CA:TRUE

[req]
distinguished_name = req_distinguished_name

[req_distinguished_name]

EOF

sed -i "s|REPLACE_WITH_CERTPATH|${certpath}|" $certpath/ca.conf

# Generate the CA
$OPENSSL genrsa -out $certpath/ca.key 2048 > /dev/null 2>&1
$OPENSSL req -x509 -new -nodes -key $certpath/ca.key -sha256 -days 1 -out $certpath/ca.crt -subj "/CN=managedssh.amazonaws.com" > /dev/null 2>&1
$OPENSSL x509 -in $certpath/ca.crt -outform PEM -out $certpath/ca.pem
subject=$($OPENSSL x509 -noout -subject -in $certpath/ca.pem | sed -n -e 's/^.*CN=//p')
# Add "# subject" to start
sed -i '1s;^;# '"$subject"'\n;' $certpath/ca.crt

# Configure the intermediary
mkdir -p $certpath/intermediate.db.certs
touch $certpath/intermediate.db.index
echo 01 > $certpath/intermediate.db.serial

cat > $certpath/intermediate.conf <<'EOF'
default_ca = ca_default

[ca_default]
dir = REPLACE_WITH_CERTPATH
certs = $dir
new_certs_dir = $dir/intermediate.db.certs
database = $dir/intermediate.db.index
serial = $dir/intermediate.db.serial
RANDFILE = $dir/intermediate.db.rand
certificate = $dir/intermediate.crt
private_key = $dir/intermediate.key
default_days = 1
default_crl_days = 1
default_md = md5
preserve = no
policy = generic_policy
x509_extensions = usr_cert

[generic_policy]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[usr_cert]
authorityInfoAccess = OCSP;URI:http://localhost:8080
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer

[v3_ocsp]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = OCSPSigning

[req]
distinguished_name = req_distinguished_name

[req_distinguished_name]

EOF

sed -i "s|REPLACE_WITH_CERTPATH|${certpath}|" $certpath/intermediate.conf

# Generate & sign the intermediary
$OPENSSL genrsa -out $certpath/intermediate.key 2048 > /dev/null 2>&1
$OPENSSL req -new -nodes -config $certpath/ca.conf -key $certpath/intermediate.key -out $certpath/intermediate.csr -extensions v3_ocsp -subj "/CN=intermediate.managedssh.amazonaws.com" > /dev/null 2>&1
yes | $OPENSSL ca -config $certpath/ca.conf -in $certpath/intermediate.csr -cert $certpath/ca.crt -keyfile $certpath/ca.key -out $certpath/intermediate.crt -extensions v3_ocsp -extensions v3_ca > /dev/null 2>&1
$OPENSSL x509 -in $certpath/intermediate.crt -outform PEM -out $certpath/intermediate.pem

# Generate and sign the test cert
$OPENSSL genrsa -out $certpath/unittest.key 2048 > /dev/null 2>&1
$OPENSSL req -new -nodes -config $certpath/intermediate.conf -key $certpath/unittest.key -out $certpath/unittest.csr -subj "/CN=unittest.managedssh.amazonaws.com" > /dev/null 2>&1
yes | $OPENSSL ca -config $certpath/intermediate.conf -in $certpath/unittest.csr -cert $certpath/intermediate.crt -keyfile $certpath/intermediate.key -out $certpath/unittest.crt > /dev/null 2>&1
$OPENSSL x509 -in $certpath/unittest.crt -outform PEM -out $certpath/unittest.pem
