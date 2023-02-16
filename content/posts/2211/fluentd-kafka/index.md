---
title: "使用fluentd收集kubernetes日志并推送给kafka"
description: ""
summary: ""
date: "2022-10-03"
bookToC: false
draft: true
tags:
- fluentd
categories:
- "technology"
---

这篇文章使用fluentd官方提供的kubernetes部署方案daemonset来部署日志收集, 参考项目地址:

- https://github.com/fluent/fluentd-kubernetes-daemonset


本文使用的kubernetes版本为: `1.22.8`

使用fluentd镜像为: `fluent/fluentd-kubernetes-daemonset:v1.15.2-debian-kafka2-1.0`

请注意下文配置中`<var>`标记, 需要根据需求自行替换.

## 创建命名空间

本项目所有的资源创建在logging下, 先创建它:

```sh
NAMESPACE=logging-kafka
kubectl create ns $NAMESPACE
```

## 先创建服务账号

创建服务账号并赋予集群查看的权限, 使用下面的命令:

```sh
kubectl -n $NAMESPACE create -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
EOF
```

创建绑定关系:

```sh
kubectl create -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: ${NAMESPACE}
EOF
```

## 创建配置文件

配置文件内容如下, 它只收集容器日志:

```sh
@include "#{ENV['FLUENTD_PROMETHEUS_CONF'] || 'prometheus'}.conf"

<label @FLUENT_LOG>
  <match fluent.**>
    @type null
    @id ignore_fluent_logs
  </match>
</label>

<source>
  @type tail
  @id in_tail_container_logs
  path "#{ENV['FLUENT_CONTAINER_TAIL_PATH'] || '/var/log/containers/*.log'}"
  pos_file /var/log/fluentd-containers.log.pos
  tag "#{ENV['FLUENT_CONTAINER_TAIL_TAG'] || 'kubernetes.*'}"
  exclude_path "#{ENV['FLUENT_CONTAINER_TAIL_EXCLUDE_PATH'] || use_default}"
  read_from_head true
  follow_inodes true
  @include ./tail_container_parse.conf
</source>

<filter kubernetes.**>
  @type kubernetes_metadata
  @id filter_kube_metadata
  kubernetes_url "#{ENV['FLUENT_FILTER_KUBERNETES_URL'] || 'https://' + ENV.fetch('KUBERNETES_SERVICE_HOST') + ':' + ENV.fetch('KUBERNETES_SERVICE_PORT') + '/api'}"
  verify_ssl "#{ENV['KUBERNETES_VERIFY_SSL'] || true}"
  ca_file "#{ENV['KUBERNETES_CA_FILE']}"
  skip_labels "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_LABELS'] || 'false'}"
  skip_container_metadata "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_CONTAINER_METADATA'] || 'false'}"
  skip_master_url "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_MASTER_URL'] || 'false'}"
  skip_namespace_metadata "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_NAMESPACE_METADATA'] || 'false'}"
  watch "#{ENV['FLUENT_KUBERNETES_WATCH'] || 'true'}"
</filter>

<match **>
  @type kafka2
  @id out_kafka2
  
  brokers "#{ENV['FLUENT_KAFKA2_BROKERS']}"
  # username "#{ENV['FLUENT_KAFKA2_USERNAME'] || nil}"
  # password "#{ENV['FLUENT_KAFKA2_PASSWORD'] || nil}"
  # scram_mechanism 'sha256'
  # sasl_over_ssl false

  use_event_time true
  get_kafka_client_log "#{ENV['FLUENT_KAFKA2_GET_KAFKA_CLIENT_LOG'] || false}"

  default_topic "#{ENV['FLUENT_KAFKA2_DEFAULT_TOPIC'] || nil}"
  partition_key_key "#{ENV['FLUENT_KAFKA2_PARTITION_KEY_KEY'] || nil}"

  <buffer>
    @type file
    path /var/log/fluentd/kafka-buffers
    flush_thread_count "#{ENV['FLUENT_BUFFER_FLUSH_THREAD_COUNT'] || '8'}"
    flush_interval "#{ENV['FLUENT_BUFFER_FLUSH_INTERVAL'] || '5s'}"
    chunk_limit_size "#{ENV['FLUENT_BUFFER_CHUNK_LIMIT_SIZE'] || '2M'}"
    retry_max_interval "#{ENV['FLUENT_BUFFER_RETRY_MAX_INTERVAL'] || '30'}"
    retry_forever true
    overflow_action "#{ENV['FLUENT_BUFFER_OVERFLOW_ACTION'] || 'block'}"
  </buffer>

  <format>
    @type "#{ENV['FLUENT_KAFKA2_OUTPUT_FORMAT_TYPE'] || 'json'}"
  </format>
  
  <inject>
    tag_key "#{ENV['FLUENT_KAFKA2_OUTPUT_TAG_KEY'] || 'fluentd_tag'}"
    time_key "#{ENV['FLUENT_KAFKA2_OUTPUT_TIME_KEY'] || 'fluentd_time'}"
  </inject>

  # ruby-kafka producer options
  max_send_retries "#{ENV['FLUENT_KAFKA2_MAX_SEND_RETRIES'] || 2}"
  required_acks "#{ENV['FLUENT_KAFKA2_REQUIRED_ACKS'] || -1}"
  ack_timeout "#{ENV['FLUENT_KAFKA2_ACK_TIMEOUT'] || 10}"
  compression_codec "#{ENV['FLUENT_KAFKA2_COMPRESSION_CODEC'] || 'gzip'}"
  discard_kafka_delivery_failed "#{ENV['FLUENT_KAFKA2_DISCARD_KAFKA_DELIVERY_FAILED'] || false}"
</match>
```

执行下面到命令创建configmap:

```sh
cat < /tmp/fluentd.conf <<EOF
# 粘贴上面的配置
EOF
kubectl -n $NAMESPACE create configmap fluentd-kafka-conf --from-file=fluent.conf=/tmp/fluentd.conf
```

## 创建daemonset部署

该镜像配置都是通过环境变量, 请根据自己实际情况修改环境变量配置.

先创建deployment部署文件:

```sh
vi /tmp/deployment.yaml
```

将下面的内容拷贝进去,之后`:wq`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  labels:
    k8s-app: fluentd-logging
    version: v1
spec:
  selector:
    matchLabels:
      k8s-app: fluentd-logging
      version: v1
  template:
    metadata:
      labels:
        k8s-app: fluentd-logging
        version: v1
    spec:
      serviceAccount: fluentd
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.15.2-debian-kafka2-1.0
        env:
          - name: K8S_NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: FLUENT_KAFKA2_BROKERS
            value: "10.206.1.1:9092,10.206.1.2:9092,10.206.1.3:9092"
          - name: FLUENT_KAFKA2_DEFAULT_TOPIC
            value: "container-log"
          - name: FLUENT_KAFKA2_PARTITION_KEY_KEY
            value: "kubernetes.host"
          # when log formt is not json, unconmment
          - name: FLUENT_CONTAINER_TAIL_PARSER_TYPE
            value: "/^(?<time>.+) (?<stream>stdout|stderr) [^ ]* (?<log>.*)$/"
          - name: FLUENT_CONTAINER_TAIL_PARSER_TIME_FORMAT
            value: "%Y-%m-%dT%H:%M:%S.%N%:z"
        resources:
          limits:
            memory: 600Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        # When actual pod logs in /var/lib/docker/containers, the following lines should be used.
        # - name: dockercontainerlogdirectory
        #   mountPath: /var/lib/docker/containers
        #   readOnly: true
        - name: config-volume
          mountPath: /fluentd/etc/fluent.conf
          subPath: fluent.conf
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      # When actual pod logs in /var/lib/docker/containers, the following lines should be used.
      # - name: dockercontainerlogdirectory
      #   hostPath:
      #     path: /var/lib/docker/containers
      - name: config-volume
        configMap:
          name: fluentd-kafka-conf
```

```sh
kubectl -n $NAMESPACE apply -f /tmp/deployment.yaml
```