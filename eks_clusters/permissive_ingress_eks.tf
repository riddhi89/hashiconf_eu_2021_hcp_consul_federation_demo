terraform {
    required_providers {
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

data "aws_eks_cluster" "eks-us-west" {
    name = "hcp-consul-fed-demo-us-west"
}
data "aws_security_group" "vpc-us-west-sg" {
    id       = data.aws_eks_cluster.eks-us-west.vpc_config.0.cluster_security_group_id
}
resource "aws_security_group_rule" "consul-ingress-sg-rules-us-west" {
    protocol          = "all"
    from_port         =  -1
    to_port           = -1
    cidr_blocks       = ["0.0.0.0/0"]
    security_group_id = data.aws_security_group.vpc-us-west-sg.id
    type              = "ingress"
}


data "aws_eks_cluster" "eks-eu-west" {
    provider = aws.eu-west-2
    name = "hcp-consul-fed-demo-eu-west"
}
data "aws_security_group" "vpc-eu-west-sg" {
    provider = aws.eu-west-2
    id       = data.aws_eks_cluster.eks-eu-west.vpc_config.0.cluster_security_group_id
}
resource "aws_security_group_rule" "consul-ingress-sg-rules-eu-west" {
    provider = aws.eu-west-2
    protocol          = "all"
    from_port         =  -1
    to_port           = -1
    cidr_blocks       = ["0.0.0.0/0"]
    security_group_id = data.aws_security_group.vpc-eu-west-sg.id
    type              = "ingress"
}



data "aws_eks_cluster" "eks-eu-central" {
    provider = aws.eu-central-1
    name = "hcp-consul-fed-demo-eu-central"
}
data "aws_security_group" "vpc-eu-central-sg" {
    provider = aws.eu-central-1
    id       = data.aws_eks_cluster.eks-eu-central.vpc_config.0.cluster_security_group_id
}
resource "aws_security_group_rule" "consul-ingress-sg-rules-eu-central" {
    provider = aws.eu-central-1
    protocol          = "all"
    from_port         =  -1
    to_port           = -1
    cidr_blocks       = ["0.0.0.0/0"]
    security_group_id = data.aws_security_group.vpc-eu-central-sg.id
    type              = "ingress"
}

