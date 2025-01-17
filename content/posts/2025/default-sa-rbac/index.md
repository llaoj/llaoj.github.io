---
title: "RBAC给默认服务账号default赋予namespace级别权限"
description: "给默认的服务账号service account: default赋予当前namespace的最高权限, 但是仅有这些权限.创建namespace之后, 里面会自带一个默认的service account, 名字是default.  它是没有任何权限的.Error from server (Forbidden): pods is forbidden: User system:serviceaccount:test-namespace:default cannot list resource pods in API group  in the namespace default Error from server (Forbidden): storageclasses.storage.k8s.io is forbidden: User system:serviceaccount:test-namespace:default cannot list resource storageclasses in API group storage.k8s.io at the cluster scope"
summary: "给默认的服务账号service account: default赋予当前namespace的最高权限, 但是仅有这些权限.创建namespace之后, 里面会自带一个默认的service account, 名字是default.  它是没有任何权限的.Error from server (Forbidden): pods is forbidden: User system:serviceaccount:test-namespace:default cannot list resource pods in API group  in the namespace default Error from server (Forbidden): storageclasses.storage.k8s.io is forbidden: User system:serviceaccount:test-namespace:default cannot list resource storageclasses in API group storage.k8s.io at the cluster scope"
date: "2025-01-15"
menu: "main"
tags:
- "kubernetes"
categories:
- "technology"
---

## 本文目的

给默认的服务账号service account: default赋予当前namespace的最高权限, 但是仅有这些权限.

## 检查default的权限

创建namespace之后, 里面会自带一个默认的service account, 名字是default.  
它是没有任何权限的.

```sh
kubectl describe secrets default-token-vfzkv
Name:         default-token-vfzkv
Namespace:    test-namespace
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: default
              kubernetes.io/service-account.uid: 9aec5c9d-12cc-44bb-b18d-70874ad6302b

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1099 bytes
namespace:  29 bytes
token:      <token密文>
```

然后我们将token字段复制出来, 加入制作kubeconfig来测试有没有权限.

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <集群证书Base64内容>
    server: https://10.193.40.2:6443
  name: cluster.local
contexts:
- context:
    cluster: cluster.local
    user: ns-admin
  name: ns-admin@cluster.local
current-context: ns-admin@cluster.local
kind: Config
preferences: {}
users:
- name: ns-admin
  user:
    token: <拷贝出来的token>
```

将上面的内容保存到`/tmp/kubeconfig`测试.

```sh
kubectl --kubeconfig=/tmp/kubeconfig -n test-namespace get pods
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:test-namespace:default" cannot list resource "pods" in API group "" in the namespace "test-namespace"
```

可以看到, 在没有给该sa赋予权限之前, 它是没有任何权限的.

## 赋予权限

下面我们使用rbac创建一个角色, 并给default这个服务账号赋予这个角色. 执行下面的命令:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: test-namespace
  name: ns-admin
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - pods/status
      - pods/log
      - pods/attach
      - pods/exec
      - pods/portforward
      - pods/proxy
      - services
      - configmaps
      - secrets
      - persistentvolumeclaims
      - events
      - endpoints
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
      - deletecollection
  - apiGroups: 
      - apps
    resources:
      - deployments
      - statefulsets
      - daemonsets
      - replicasets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
      - deletecollection
  - apiGroups:
      - batch
    resources:
      - jobs
      - cronjobs
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
      - deletecollection
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingresses 
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
      - deletecollection
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ns-admin
  namespace: test-namespace
subjects:
- kind: ServiceAccount
  name: default
  namespace: test-namespace
roleRef:
  kind: Role
  name: ns-admin
  apiGroup: rbac.authorization.k8s.io
```

权限赋予完毕, 我们进行测试:

```sh
# 先测试有没有当前namespace的权限: 有的, 符合预期
kubectl --kubeconfig=/tmp/kubeconfig -n test-namespace get all
No resources found in test-namespace namespace.

# 再测试有没有其他namespace的权限: 没有, 符合预期
kubectl --kubeconfig=/tmp/kubeconfig get all
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:test-namespace:default" cannot list resource "pods" in API group "" in the namespace "default"
Error from server (Forbidden): replicationcontrollers is forbidden: User "system:serviceaccount:test-namespace:default" cannot list resource "replicationcontrollers" in API group "" in the namespace "default"
Error from server (Forbidden): services is forbidden: User "system:serviceaccount:test-namespace:default" cannot list resource "services" in API group "" in the namespace "default"
Error from server (Forbidden): daemonsets.apps is forbidden: User "system:serviceaccount:test-namespace:default" cannot list resource "daemonsets" in API group "apps" in the namespace "default"
...

# 最后测试有没有集群资源权限: 没有, 符合预期
kubectl --kubeconfig=/tmp/kubeconfig get sc
Error from server (Forbidden): storageclasses.storage.k8s.io is forbidden: User "system:serviceaccount:test-namespace:default" cannot list resource "storageclasses" in API group "storage.k8s.io" at the cluster scope
```

## 总结

测试完毕, 这个kubeconfig就可以使用了, 他有test-namespace下的大部分权限, 但没有其他namesapce权限, 也没有集群资源权限. 还有, 因为这个kubeconfig是要分配给非集群管理员使用的, 他们仅能操作自己的namespace. 所以, 我们没有给role、rolebinding、resourcequota这些资源, 以防止其越权, 或者过度使用资源.