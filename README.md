## BEFORE DEMO

1. SETUP CLIENT EKS CLUSTERS

    `cd eks_clusters/`
    `eksctl create cluster -f eks_us_west.yaml`
    `eksctl create cluster -f eks_eu_west.yaml`
    `eksctl create cluster -f eks_eu_central.yaml`
    `terraform init; terraform apply permissive_ingress_eks.tf`

3. Update kube contexts to more friendly names -> us-west, eu-west, eu-central


## FOR DEMO

1. Create HCP resources
    `cd hcp_consul/`
    `terraform init; terraform apply`

2. Goto [HCP UI](https://portal.cloud.hashicorp.com/):

    * Log into the Consul UI using the public URL of the primary + admin token that can be generated from HCP UI.
    * Download client config zip files for each cluster available on the HCP UI, into the root directory of the repo.

3. Install consul on us-west cluster:

    `./install_consul_us_west.sh`
    `kubectl apply -f mesh_gateway`
    `kubectl apply -f ingress_gateway`

4. [To workaround Consul 1.9.5 bugs]:

    * Workaround for [this](https://github.com/hashicorp/consul-k8s/issues/518) bug: On consul UI, update client token policy to be valid across datacenters.

    * Attach the client-token policy to the anonymous token. This token is used by the proxy side cars for cross-region service lookup.

5. Install consul on eu-west cluster:

    `./install_consul_eu_west.sh`
    `kubectl apply -f mesh_gateway`

5. Install consul on eu-central cluster:

    `./install_consul_eu_central.sh`
    `kubectl apply -f mesh_gateway`

6. Deploy service mesh:

    `cd hashicups/`

    * `kubectl apply -f frontend.yaml --context us-west`
    * `kubectl apply -f public-api.yaml --context eu-west`
    * `kubectl apply -f product-api.yaml --context eu-central`
    * `kubectl apply -f postgres.yaml --context eu-central`
    * `kubectl apply -f service_intentions.yaml --context us-west`

7. Access Hashicups UI:

    * Get the INGRESS GATEWAY url: `kubectl get svc/consul-ingress-gateway --context us-west -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
    * Run - `curl -H "Host: frontend.ingress.consul" "http://$INGRESS_GATEWAY:8080"`
    * To access `http://$INGRESS_GATEWAY:8080"` from a browser, use a browser extension to set the `Host` header to `frontend.ingress.consul`.