#!/usr/bin/env bash
set -ex

EASY_RSA_LOC="/etc/openvpn/easyrsa"
SERVER_CERT="${EASY_RSA_LOC}/pki/issued/server.crt"

OVPN_SRV_NET=${OVPN_SERVER_NET:-10.8.0.0}
OVPN_SRV_MASK=${OVPN_SERVER_MASK:-255.255.255.0}

cd $EASY_RSA_LOC

if [ -e "$SERVER_CERT" ]; then
  echo "Found existing certs - reusing"
else
  if [ ${OVPN_ROLE:-"master"} = "slave" ]; then
    echo "Waiting for initial sync data from master"
    while [ $(wget -q localhost/api/sync/last/try -O - | wc -m) -lt 1 ]
    do
      sleep 5
    done
  else
    echo "Generating new certs"
    easyrsa --batch init-pki
    cp -R /usr/share/easy-rsa/* $EASY_RSA_LOC/pki
    echo "ca" | easyrsa build-ca nopass
    easyrsa --batch build-server-full server nopass
    easyrsa gen-dh
    openvpn --genkey --secret ./pki/ta.key
  fi
fi
easyrsa gen-crl

iptables -t nat -D POSTROUTING -s ${OVPN_SRV_NET}/${OVPN_SRV_MASK} ! -d ${OVPN_SRV_NET}/${OVPN_SRV_MASK} -j MASQUERADE || true
iptables -t nat -A POSTROUTING -s ${OVPN_SRV_NET}/${OVPN_SRV_MASK} ! -d ${OVPN_SRV_NET}/${OVPN_SRV_MASK} -j MASQUERADE

# Fixed: Use environment variables instead of hardcoded values
iptables -t nat -A POSTROUTING -s ${OVPN_SRV_NET}/${OVPN_SRV_MASK} -d ${DOCKER_NETWORK} -j MASQUERADE

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

cp -f /etc/openvpn/setup/openvpn.conf /etc/openvpn/openvpn.conf

# Add custom routes if specified
if [ ! -z "${OVPN_CUSTOM_ROUTES}" ]; then
  echo 'push "route '${OVPN_CUSTOM_ROUTES}'"' >> /etc/openvpn/openvpn.conf
fi

# Replace lines 23-27 in openvpn.conf with this dynamic generation:

# Always push topology subnet
echo 'push "topology subnet"' >> /etc/openvpn/openvpn.conf

# Split tunneling configuration based on environment variables
if [ "${OVPN_SPLIT_TUNNEL}" = "true" ]; then
  echo "# Split tunneling enabled - only route specific networks through VPN" >> /etc/openvpn/openvpn.conf
  
  # Add routes from OVPN_ROUTES environment variable
  if [ ! -z "${OVPN_ROUTES}" ]; then
    echo 'push "route '${OVPN_ROUTES}'"' >> /etc/openvpn/openvpn.conf
  fi
  
  # Add Docker network route from DOCKER_NETWORK
  if [ ! -z "${DOCKER_NETWORK}" ]; then
    DOCKER_NET=$(echo ${DOCKER_NETWORK} | cut -d'/' -f1)
    echo 'push "route '${DOCKER_NET}' 255.255.0.0"' >> /etc/openvpn/openvpn.conf
  fi
  
  # Don't push redirect-gateway for split tunneling
  echo "# redirect-gateway disabled for split tunneling" >> /etc/openvpn/openvpn.conf
else
  # Default behavior - route all traffic through VPN
  echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/openvpn.conf
fi

# Always add these
echo 'push "route-metric 9999"' >> /etc/openvpn/openvpn.conf
echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/openvpn.conf

if [ ${OVPN_PASSWD_AUTH} = "true" ]; then
  mkdir -p /etc/openvpn/scripts/
  cp -f /etc/openvpn/setup/auth.sh /etc/openvpn/scripts/auth.sh
  chmod +x /etc/openvpn/scripts/auth.sh
  echo "auth-user-pass-verify /etc/openvpn/scripts/auth.sh via-file" | tee -a /etc/openvpn/openvpn.conf
  echo "script-security 2" | tee -a /etc/openvpn/openvpn.conf
  echo "verify-client-cert require" | tee -a /etc/openvpn/openvpn.conf
  openvpn-user db-init --db.path=$EASY_RSA_LOC/pki/users.db && openvpn-user db-migrate --db.path=$EASY_RSA_LOC/pki/users.db
fi

[ -d $EASY_RSA_LOC/pki ] && chmod 755 $EASY_RSA_LOC/pki
[ -f $EASY_RSA_LOC/pki/crl.pem ] && chmod 644 $EASY_RSA_LOC/pki/crl.pem

mkdir -p /etc/openvpn/ccd

# Fixed: Changed to UDP and use environment variables
openvpn --config /etc/openvpn/openvpn.conf --client-config-dir /etc/openvpn/ccd --port 1194 --proto udp --management 127.0.0.1 8989 --dev tun0 --server ${OVPN_SRV_NET} ${OVPN_SRV_MASK}
