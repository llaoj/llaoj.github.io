#!/bin/bash

mkdir auger
curl -o ./auger/auger_1.0.2_linux_amd64.tar.gz https://llaoj.oss-cn-beijing.aliyuncs.com/files/github.com/etcd-io/auger/releases/download/v1.0.2/auger_1.0.2_linux_amd64.tar.gz
tar -xvf ./auger/auger_1.0.2_linux_amd64.tar.gz -C ./auger
mv ./auger/auger /usr/local/bin/
rm -rf ./auger

ENDPOINTS=$(ps -ef | grep kube-apiserver | grep -P 'etcd-servers=(.*?)\s' -o | awk -F= '{print $2}')
CACERT=$(ps -ef | grep kube-apiserver | grep -P 'etcd-cafile=(.*?)\s' -o | awk -F= '{print $2}')
CERT=$(ps -ef | grep kube-apiserver | grep -P 'etcd-certfile=(.*?)\s' -o | awk -F= '{print $2}')
KEY=$(ps -ef | grep kube-apiserver | grep -P 'etcd-keyfile=(.*?)\s' -o | awk -F= '{print $2}')

ETCDCTL_API=3 etcdctl --endpoints="$ENDPOINTS" --cacert="$CACERT" --key="$KEY" --cert="$CERT" "$@"