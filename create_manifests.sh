#!/bin/bash

HOST_IP=$(hostname -I | awk '{print $1}')

sudo touch /etc/kubernetes/manifests/etcd.yaml
sudo touch /etc/kubernetes/manifests/kube-apiserver.yaml
sudo touch /etc/kubernetes/manifests/kube-scheduler.yaml
sudo touch /etc/kubernetes/manifests/kube-controller-manager.yaml

cat <<EOF | sudo tee /etc/kubernetes/manifests/etcd.yaml
apiVersion: v1
kind: Pod
metadata:
  name: etcd
  labels: { component: etcd }
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
  - name: etcd
    image: registry.k8s.io/etcd:3.5.13-0
    command: ["etcd"]
    args:
      - --name=default
      - --advertise-client-urls=http://$HOST_IP:2379
      - --listen-client-urls=http://0.0.0.0:2379
      - --data-dir=/var/lib/etcd
      - --listen-peer-urls=http://0.0.0.0:2380
      - --initial-cluster=default=http://$HOST_IP:2380
      - --initial-advertise-peer-urls=http://$HOST_IP:2380
      - --initial-cluster-state=new
      - --initial-cluster-token=test-token
    ports:
    - name: client
      containerPort: 2379
      hostPort: 2379
      protocol: TCP
    - name: peer
      containerPort: 2380
      hostPort: 2380
      protocol: TCP
    volumeMounts:
      - name: data
        mountPath: /var/lib/etcd
  volumes:
    - name: data
      hostPath:
        path: /var/lib/etcd
        type: DirectoryOrCreate
EOF

cat <<EOF | sudo tee /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  labels: { component: kube-apiserver }
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
  - name: kube-apiserver
    image: registry.k8s.io/kube-apiserver:v1.30.0
    command: ["kube-apiserver"]
    args:
      - --etcd-servers=http://$HOST_IP:2379
      - --service-cluster-ip-range=10.0.0.0/24
      - --bind-address=0.0.0.0
      - --secure-port=6443
      - --advertise-address=$HOST_IP
      - --authorization-mode=AlwaysAllow
      - --token-auth-file=/tmp/token.csv
      - --enable-priority-and-fairness=false
      - --allow-privileged=true
      - --profiling=false
      - --storage-backend=etcd3
      - --storage-media-type=application/json
      - --v=0
      - --cloud-provider=external
      - --service-account-issuer=https://kubernetes.default.svc.cluster.local
      - --service-account-key-file=/tmp/sa.pub
      - --service-account-signing-key-file=/tmp/sa.key
    ports:
    - name: client
      containerPort: 6443
      hostPort: 6443
    volumeMounts:
      - name: host-tmp
        mountPath: /tmp
  volumes:
    - name: host-tmp
      hostPath:
        path: /tmp
        type: Directory
EOF

cat <<EOF | sudo tee /etc/kubernetes/manifests/kube-scheduler.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  labels: { component: kube-scheduler }
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
  - name: kube-scheduler
    image: registry.k8s.io/kube-scheduler:v1.30.0
    command: ["kube-scheduler"]
    args:
      - --kubeconfig=/var/lib/kubelet/kubeconfig
      - --leader-elect=false
      - --v=2
      - --bind-address=0.0.0.0
    ports:
    - name: client
      containerPort: 10259
      hostPort: 10259
    volumeMounts:
      - name: kc
        mountPath: /var/lib/kubelet/kubeconfig
        readOnly: true
  volumes:
    - name: kc
      hostPath:
        path: /var/lib/kubelet/kubeconfig
        type: File
EOF

cat <<EOF | sudo tee /etc/kubernetes/manifests/kube-controller-manager.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  labels: { component: kube-controller-manager }
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
  - name: kube-controller-manager
    image: registry.k8s.io/kube-controller-manager:v1.30.0
    command: ["kube-controller-manager"]
    args:
      - --kubeconfig=/var/lib/kubelet/kubeconfig
      - --leader-elect=false
      - --cloud-provider=external
      - --service-cluster-ip-range=10.0.0.0/24
      - --cluster-name=kubernetes
      - --root-ca-file=/var/lib/kubelet/ca.crt
      - --service-account-private-key-file=/tmp/sa.key
      - --use-service-account-credentials=true
      - --v=2 
    ports:
    - name: secure
      containerPort: 10257
    volumeMounts:
      - name: kc
        mountPath: /var/lib/kubelet/kubeconfig
        readOnly: true
      - name: cacrt
        mountPath: /var/lib/kubelet/ca.crt
        readOnly: true
      - name: sakey
        mountPath: /tmp/sa.key
        readOnly: true
  volumes:
    - name: kc
      hostPath: { path: /var/lib/kubelet/kubeconfig, type: File }
    - name: cacrt
      hostPath: { path: /var/lib/kubelet/ca.crt, type: File }
    - name: sakey
      hostPath: { path: /tmp/sa.key, type: File }
EOF