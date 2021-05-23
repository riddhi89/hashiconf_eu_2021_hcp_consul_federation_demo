terraform {
    required_providers {
        hcp = {
            source  = "hashicorp/hcp"
            version = "~> 0.5.0"
        }
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region = "us-west-2"
}

provider "aws" {
    alias = "eu-west-2"
    region = "eu-west-2"
}

provider "aws" {
    alias = "eu-central-1"
    region = "eu-central-1"
}



// CREATE HVNs

// Create HVN in us-west
resource "hcp_hvn" "hvn-us-west" {
    hvn_id         = "hvn-us-west-demo"
    cloud_provider = "aws"
    region         = "us-west-2"
    cidr_block     = "172.25.16.0/20"
}

// Create HVN in eu-west
resource "hcp_hvn" "hvn-eu-west" {
    hvn_id         = "hvn-eu-west-demo"
    cloud_provider = "aws"
    region         = "eu-west-2"
    cidr_block     = "172.26.16.0/20"
}

// Create HVN in eu-central
resource "hcp_hvn" "hvn-eu-central" {
    hvn_id         = "hvn-eu-central-demo"
    cloud_provider = "aws"
    region         = "eu-central-1"
    cidr_block     = "172.27.16.0/20"
}



// CREATE FEDERATED CONSUL CLUSTERS

// Create federation primary Consul cluster within HVN in us-west
resource "hcp_consul_cluster" "primary-us-west" {
    cluster_id      = "primary-us-west-demo"
    hvn_id          = hcp_hvn.hvn-us-west.hvn_id
    tier            = "development"
    public_endpoint = "true"
}

// Create federation secondary Consul cluster within HVN in eu-west
resource "hcp_consul_cluster" "secondary-eu-west" {
    cluster_id      = "secondary-eu-west-2-demo"
    hvn_id          = hcp_hvn.hvn-eu-west.hvn_id
    tier            = "development"
    public_endpoint = "true"
    primary_link    = hcp_consul_cluster.primary-us-west.self_link
    datacenter      = "secondary-eu-west"
}

// Create federation secondary Consul cluster within HVN in eu-central
resource "hcp_consul_cluster" "secondary-eu-central" {
    cluster_id      = "secondary-eu-central-1-demo"
    hvn_id          = hcp_hvn.hvn-eu-central.hvn_id
    tier            = "development"
    public_endpoint = "true"
    primary_link    = hcp_consul_cluster.primary-us-west.self_link
    datacenter      = "secondary-eu-central"
}

// OUTPUT CLUSTER IDs of each cluster for client configuration later
output "us_west_cluster" {
    value = hcp_consul_cluster.primary-us-west.cluster_id
}
output "eu_west_cluster" {
    value = hcp_consul_cluster.secondary-eu-west.cluster_id
}
output "eu_central_cluster" {
    value = hcp_consul_cluster.secondary-eu-central.cluster_id
}

// GENERATE & OUTPUT ADMIN TOKENS FOR EACH CONSUL CLUSTER as k8s secret templates

resource "hcp_consul_cluster_root_token" "us-west-root-token" {
    cluster_id = hcp_consul_cluster.primary-us-west.cluster_id
}
output "us_west_bootstrap_secret" {
    value = hcp_consul_cluster_root_token.us-west-root-token.kubernetes_secret
}

resource "hcp_consul_cluster_root_token" "eu-west-root-token" {
    cluster_id = hcp_consul_cluster.secondary-eu-west.cluster_id
}
output "eu_west_bootstrap_secret" {
    value = hcp_consul_cluster_root_token.eu-west-root-token.kubernetes_secret
}

resource "hcp_consul_cluster_root_token" "eu-central-root-token" {
    cluster_id = hcp_consul_cluster.secondary-eu-central.cluster_id
}
output "eu_central_bootstrap_secret" {
    value = hcp_consul_cluster_root_token.eu-central-root-token.kubernetes_secret
}


// CREATE SERVER-CLIENT NETWORK PEERINGS

// Create a network peering between the HVN and the AWS VPC in us-west
data "aws_eks_cluster" "eks-us-west" {
    name = "hcp-consul-fed-demo-us-west"
}
data "aws_vpc" "vpc-us-west" {
    id = data.aws_eks_cluster.eks-us-west.vpc_config.0.vpc_id
}
resource "hcp_aws_network_peering" "us-west-peering" {
    hvn_id              = hcp_hvn.hvn-us-west.hvn_id
    peer_vpc_id         = data.aws_vpc.vpc-us-west.id
    peer_account_id     = data.aws_vpc.vpc-us-west.owner_id
    peer_vpc_region     = hcp_hvn.hvn-us-west.region
    peer_vpc_cidr_block = data.aws_vpc.vpc-us-west.cidr_block
}
resource "aws_vpc_peering_connection_accepter" "us-west-peering-accepter" {
    vpc_peering_connection_id = hcp_aws_network_peering.us-west-peering.provider_peering_id
    auto_accept               = true
}
output "eks_us_west_api_endpoint" {
    value = data.aws_eks_cluster.eks-us-west.endpoint
}


// Create a network peering between the HVN and the AWS VPC in eu-west
data "aws_eks_cluster" "eks-eu-west" {
    provider = aws.eu-west-2
    name = "hcp-consul-fed-demo-eu-west"
}
data "aws_vpc" "vpc-eu-west" {
    provider = aws.eu-west-2
    id = data.aws_eks_cluster.eks-eu-west.vpc_config.0.vpc_id
}
resource "hcp_aws_network_peering" "eu-west-peering" {
    hvn_id              = hcp_hvn.hvn-eu-west.hvn_id
    peer_vpc_id         = data.aws_vpc.vpc-eu-west.id
    peer_account_id     = data.aws_vpc.vpc-eu-west.owner_id
    peer_vpc_region     = hcp_hvn.hvn-eu-west.region
    peer_vpc_cidr_block = data.aws_vpc.vpc-eu-west.cidr_block
}
resource "aws_vpc_peering_connection_accepter" "eu-west-peering-accepter" {
    provider = aws.eu-west-2
    vpc_peering_connection_id = hcp_aws_network_peering.eu-west-peering.provider_peering_id
    auto_accept               = true
}
output "eks_eu_west_api_endpoint" {
    value = data.aws_eks_cluster.eks-eu-west.endpoint
}


// Create a network peering between the HVN and the AWS VPC in eu-central
data "aws_eks_cluster" "eks-eu-central" {
    provider = aws.eu-central-1
    name = "hcp-consul-fed-demo-eu-central"
}
data "aws_vpc" "vpc-eu-central" {
    provider = aws.eu-central-1
    id = data.aws_eks_cluster.eks-eu-central.vpc_config.0.vpc_id
}
resource "hcp_aws_network_peering" "eu-central-peering" {
    hvn_id              = hcp_hvn.hvn-eu-central.hvn_id
    peer_vpc_id         = data.aws_vpc.vpc-eu-central.id
    peer_account_id     = data.aws_vpc.vpc-eu-central.owner_id
    peer_vpc_region     = hcp_hvn.hvn-eu-central.region
    peer_vpc_cidr_block = data.aws_vpc.vpc-eu-central.cidr_block
}
resource "aws_vpc_peering_connection_accepter" "eu-central-peering-accepter" {
    provider = aws.eu-central-1
    vpc_peering_connection_id = hcp_aws_network_peering.eu-central-peering.provider_peering_id
    auto_accept               = true
}
output "eks_eu_central_api_endpoint" {
    value = data.aws_eks_cluster.eks-eu-central.endpoint
}


// UPDATE NETWORKING ON CLIENT VPCs to ALLOW HVN/CONSUL TRAFFIC

// Update public route table on vpc in us-west to include a route for HVN via the peering connection.
data "aws_route_table" "vpc-us-west-rtb-public"{
    tags = {
        Name = "eksctl-hcp-consul-fed-demo-us-west-cluster/PublicRouteTable"
    }
}
resource "aws_route" "hvn-us-west" {
    route_table_id            = data.aws_route_table.vpc-us-west-rtb-public.id
    destination_cidr_block    = hcp_hvn.hvn-us-west.cidr_block
    vpc_peering_connection_id = hcp_aws_network_peering.us-west-peering.provider_peering_id
}

// Update public route table on vpc in eu-west to include a route for HVN via the peering connection.
data "aws_route_table" "vpc-eu-west-rtb-public"{
    provider = aws.eu-west-2
    tags = {
        Name = "eksctl-hcp-consul-fed-demo-eu-west-cluster/PublicRouteTable"
    }
}
resource "aws_route" "hvn-eu-west" {
    provider                  = aws.eu-west-2
    route_table_id            = data.aws_route_table.vpc-eu-west-rtb-public.id
    destination_cidr_block    = hcp_hvn.hvn-eu-west.cidr_block
    vpc_peering_connection_id = hcp_aws_network_peering.eu-west-peering.provider_peering_id
}

// Update public route table on vpc in eu-central to include a route for HVN via the peering connection.
data "aws_route_table" "vpc-eu-central-rtb-public"{
    provider = aws.eu-central-1
    tags = {
        Name = "eksctl-hcp-consul-fed-demo-eu-central-cluster/PublicRouteTable"
    }
}
resource "aws_route" "hvn-eu-central" {
    provider                  = aws.eu-central-1
    route_table_id            = data.aws_route_table.vpc-eu-central-rtb-public.id
    destination_cidr_block    = hcp_hvn.hvn-eu-central.cidr_block
    vpc_peering_connection_id = hcp_aws_network_peering.eu-central-peering.provider_peering_id
}
