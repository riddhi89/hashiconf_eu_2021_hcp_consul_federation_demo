#!/usr/bin/env bash

cd hcp_consul/
CLUSTERID=$(terraform output -raw us_west_cluster)
cd ../
kubectl config use-context us-west
DIR="client_config_bundle_consul_${CLUSTERID}"
unzip ${DIR}.zip -d $DIR
cd $DIR
kubectl create secret generic "consul-ca-cert" --from-file='tls.crt=./ca.pem'
kubectl create secret generic "consul-gossip-key" --from-literal="key=$(jq -r .encrypt client_config.json)"
cd ../hcp_consul/
terraform output -raw us_west_bootstrap_secret > ../${DIR}/consul_bootstrap_secret.yaml
CONSUL_HTTP_ADDR=$(terraform output eks_us_west_api_endpoint)
cd ../$DIR
kubectl apply -f consul_bootstrap_secret.yaml
DATACENTER=$(jq -r .datacenter client_config.json)
RETRY_JOIN=$(jq -r --compact-output .retry_join client_config.json)

cat > config.yaml << EOF
global:
  name: consul
  enabled: false
  image: hashicorp/consul-enterprise:1.9.5-ent
  datacenter: ${DATACENTER}
  acls:
    manageSystemACLs: true
    bootstrapToken:
      secretName: ${CLUSTERID}-bootstrap-token
      secretKey: token
  gossipEncryption:
    secretName: consul-gossip-key
    secretKey: key
  tls:
    enabled: true
    enableAutoEncrypt: true
    caCert:
      secretName: consul-ca-cert
      secretKey: tls.crt
externalServers:
  enabled: true
  hosts: ${RETRY_JOIN}
  httpsPort: 443
  useSystemRoots: true
  k8sAuthMethodHost: ${CONSUL_HTTP_ADDR}
client:
  enabled: true
  join: ${RETRY_JOIN}
connectInject:
  enabled: true
controller:
  enabled: true
meshGateway:
  enabled: true
  replicas: 1
ingressGateways:
  enabled: true
  defaults:
    replicas: 1
  gateways:
    - name: ingress-gateway
      service:
        type: LoadBalancer
EOF

helm install consul -f config.yaml hashicorp/consul --version "0.31.1"

