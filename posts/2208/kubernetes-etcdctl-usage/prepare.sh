#!/bin/bash

ENDPOINTS=$(ps -ef | grep kube-apiserver | grep -P 'etcd-servers=(.*?)\s' -o | awk -F= '{print $2}')
CACERT=$(ps -ef | grep kube-apiserver | grep -P 'etcd-cafile=(.*?)\s' -o | awk -F= '{print $2}')
CERT=$(ps -ef | grep kube-apiserver | grep -P 'etcd-certfile=(.*?)\s' -o | awk -F= '{print $2}')
KEY=$(ps -ef | grep kube-apiserver | grep -P 'etcd-keyfile=(.*?)\s' -o | awk -F= '{print $2}')

alias etcdctl='ETCDCTL_API=3 etcdctl --endpoints=${ENDPOINTS} --cacert=${CACERT} --key=${KEY} --cert=${CERT} -w=json'