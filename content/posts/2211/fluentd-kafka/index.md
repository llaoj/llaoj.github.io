---
title: "使用fluentd收集kubernetes日志并推送给kafka"
description: ""
summary: ""
date: "2022-10-03"
bookToC: false
draft: false
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
kubectl create ns fluentd-kafka
```

## 先创建服务账号

创建服务账号并赋予集群查看的权限, 使用下面的命令:

```sh
kubectl -n fluentd-kafka create -f - <<EOF
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
  name: fluentd-kafka
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: fluentd-kafka
EOF
```

## 创建配置文件

执行下面到命令创建configmap:

```sh
cat > /tmp/fluentd.conf <<EOF
# 粘贴下面的配置
EOF
kubectl -n fluentd-kafka create configmap fluentd-kafka-conf --from-file=fluent.conf=/tmp/fluentd.conf
```

配置文件内容如下, 它只收集容器日志:

```sh
@include 'prometheus.conf'

<label @FLUENT_LOG>
  <match fluent.**>
    @type null
    @id ignore_fluent_logs
  </match>
</label>

<source>
  @type tail
  @id in_tail_container_logs
  path '/var/log/containers/*.log'
  pos_file /var/log/fluentd-kafka-containers.log.pos
  tag 'kubernetes.*'
  exclude_path use_default
  read_from_head true
  follow_inodes true
  <parse>
    @type "json"
    time_key "read_time"
  </parse>
</source>

<filter kubernetes.**>
  @type kubernetes_metadata
  @id filter_kube_metadata
  kubernetes_url "#{'https://' + ENV.fetch('KUBERNETES_SERVICE_HOST') + ':' + ENV.fetch('KUBERNETES_SERVICE_PORT') + '/api'}"
  verify_ssl "#{ENV['KUBERNETES_VERIFY_SSL'] || true}"
  ca_file "#{ENV['KUBERNETES_CA_FILE']}"
  skip_labels false
  skip_container_metadata true
  skip_master_url true
  skip_namespace_metadata false
  watch true
</filter>

<filter kubernetes.**>
  @type record_transformer
  <record>
    cluster_id 'CLUSTER_ID'
  </record>
</filter>

<match **>
  @type kafka2
  @id out_kafka2
  
  brokers "#{ENV['FLUENT_KAFKA2_BROKERS']}"
  # username "#{ENV['FLUENT_KAFKA2_USERNAME'] || nil}"
  # password "#{ENV['FLUENT_KAFKA2_PASSWORD'] || nil}"
  # scram_mechanism 'sha256'
  # sasl_over_ssl false
  default_topic "#{ENV['FLUENT_KAFKA2_DEFAULT_TOPIC'] || nil}"
  partition_key_key 'kubernetes.host'

  use_event_time true
  get_kafka_client_log true

  <format>
    @type 'json'
  </format>

  <inject>
    time_key "read_time"
  </inject>

  <buffer>
    @type file
    path /var/log/fluentd/kafka-buffers
    flush_thread_count 8
    flush_interval '5s'
    chunk_limit_size '2M'
    retry_max_interval 30
    retry_forever true
    overflow_action 'block'
  </buffer>

  # ruby-kafka producer options
  max_send_retries 10000
  required_acks 1
  ack_timeout 20
  compression_codec 'gzip'
  discard_kafka_delivery_failed false
</match>
```

**注意:** 因为CPU调度原因, 日志在日志文件中的排列顺序和`time`的顺序不一致. 所以, 使用`read_time`作为日志的envent time, 表示日志的采集时间. 这样就能确保日志的顺序和日志源文件中保持一致. 源日志中的`time`字段保留, 作为日志生成时间.

## 创建daemonset部署

该镜像配置都是通过环境变量, 请根据自己实际情况修改环境变量配置.

先创建deployment部署文件:

```sh
kubectl -n logging-kafka apply -f - <<EOF
# 粘贴下面的内容
EOF
```

将下面的内容拷贝进去:

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
            value: "10.206.96.26:9092,10.206.96.27:9092,10.206.96.28:9092"
          - name: FLUENT_KAFKA2_DEFAULT_TOPIC
            value: "container-log"
          # when log formt is not json, unconmment
          - name: FLUENT_CONTAINER_TAIL_PARSER_TYPE
            value: "/^(?<time>.+) (?<stream>stdout|stderr) [^ ]* (?<log>.*)$/"
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