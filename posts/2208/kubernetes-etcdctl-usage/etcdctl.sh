#!/bin/bash

ENDPOINTS=$(pgrep kube-apiserver | grep -P 'etcd-servers=(.*?)\s' -o | awk -F= '{print $2}')
CACERT=$(pgrep kube-apiserver | grep -P 'etcd-cafile=(.*?)\s' -o | awk -F= '{print $2}')
CERT=$(pgrep kube-apiserver | grep -P 'etcd-certfile=(.*?)\s' -o | awk -F= '{print $2}')
KEY=$(pgrep kube-apiserver | grep -P 'etcd-keyfile=(.*?)\s' -o | awk -F= '{print $2}')

ETCDCTL_API=3 etcdctl --endpoints="$ENDPOINTS" --cacert="$CACERT" --key="$KEY" --cert="$CERT" "$@"