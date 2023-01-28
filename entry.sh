#!/usr/bin/env bash

set -e


_downwgcf() {
  echo
  echo "clean up"
  if ! wg-quick down wgcf; then
    echo "error down"
  fi
  echo "clean up done"
  exit 0
}



#-4|-6
runwgcf() {
  trap '_downwgcf' ERR TERM INT

  _enableV4="1"
  if [ "$1" = "-6" ]; then
    _enableV4=""
  fi


  if [ ! -e "wgcf-account.toml" ]; then
    wgcf register --accept-tos
  fi

  if [ ! -e "wgcf-profile.conf" ]; then
    wgcf generate
  fi
  
  cp wgcf-profile.conf /etc/wireguard/wgcf.conf

  DEFAULT_GATEWAY_NETWORK_CARD_NAME=`route  | grep default  | awk '{print $8}' | head -1`
  DEFAULT_ROUTE_IP=`ifconfig $DEFAULT_GATEWAY_NETWORK_CARD_NAME | grep "inet " | awk '{print $2}' | sed "s/addr://"`
  
  echo ${DEFAULT_GATEWAY_NETWORK_CARD_NAME}
  echo ${DEFAULT_ROUTE_IP}
  
  sed -i "/\[Interface\]/a PostDown = ip rule delete from $DEFAULT_ROUTE_IP  lookup main" /etc/wireguard/wgcf.conf
  sed -i "/\[Interface\]/a PostUp = ip rule add from $DEFAULT_ROUTE_IP lookup main" /etc/wireguard/wgcf.conf

  if [ "$1" = "-6" ]; then
    sed -i 's/AllowedIPs = 0.0.0.0/#AllowedIPs = 0.0.0.0/' /etc/wireguard/wgcf.conf
  elif [ "$1" = "-4" ]; then
    sed -i 's/AllowedIPs = ::/#AllowedIPs = ::/' /etc/wireguard/wgcf.conf
  elif [ "$1" = "-google" ]; then
    sed -i 's/AllowedIPs = 0.0.0.0\/0/AllowedIPs = 8.34.208.0\/20, 8.35.192.0\/20, 23.236.48.0\/20, 23.251.128.0\/19, 34.128.0.0\/10, 34.64.0.0\/10, 35.184.0.0\/13, 35.192.0.0\/14, 35.196.0.0\/15, 35.198.0.0\/16, 35.199.0.0\/17, 35.199.128.0\/18, 35.200.0.0\/13, 35.208.0.0\/12, 35.224.0.0\/12, 35.240.0.0\/13, 64.15.112.0\/20, 64.233.160.0\/19, 66.102.0.0\/20, 66.249.64.0\/19, 70.32.128.0\/19, 72.14.192.0\/18, 74.114.24.0\/21, 74.125.0.0\/16, 104.154.0.0\/15, 104.196.0.0\/14, 104.237.160.0\/19, 107.167.160.0\/19, 107.178.192.0\/18, 108.170.192.0\/18, 108.177.0.0\/17, 108.59.80.0\/20, 130.211.0.0\/16, 136.112.0.0\/12, 142.250.0.0\/15, 146.148.0.0\/17, 162.216.148.0\/22, 162.222.176.0\/21, 172.110.32.0\/21, 172.217.0.0\/16, 172.253.0.0\/16, 173.194.0.0\/16, 173.255.112.0\/20, 192.158.28.0\/22, 192.178.0.0\/15, 193.186.4.0\/24, 199.192.112.0\/22, 199.223.232.0\/21, 199.36.154.0\/23, 199.36.156.0\/24, 207.223.160.0\/20, 208.117.224.0\/19, 208.65.152.0\/22, 208.68.108.0\/22, 208.81.188.0\/22, 209.85.128.0\/17, 216.239.32.0\/19, 216.58.192.0\/19, 216.73.80.0\/20/' /etc/wireguard/wgcf.conf
  fi

  modprobe ip6table_raw
  
  wg-quick up wgcf
  
  if [ "$_enableV4" ]; then
    _checkV4
  else
    _checkV6
  fi

  echo 
  echo "OK, wgcf is up."
  

  sleep infinity & wait
  
  
}

_checkV4() {
  echo "Checking network status, please wait...."
  while ! curl --max-time 2  ipinfo.io; do
    wg-quick down wgcf
    echo "Sleep 2 and retry again."
    sleep 2
    wg-quick up wgcf
  done


}

_checkV6() {
  echo "Checking network status, please wait...."
  while ! curl --max-time 2 -6 ipv6.google.com; do
    wg-quick down wgcf
    echo "Sleep 2 and retry again."
    sleep 2
    wg-quick up wgcf
  done


}



if [ -z "$@" ] || [[ "$1" = -* ]]; then
  runwgcf "$@"
else
  exec "$@"
fi


