# General

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

# Variables

variable "aws_region" {
    default = "eu-west-1"
}

variable "ec2_count" {
  default = "1"
}

variable "ami_id" {
    default = "ami-08bac620dc84221eb"
}

variable "instance_type" {
  default = "t2.medium"
}

# Network

resource "aws_vpc" "vpc" {
  cidr_block = "192.168.0.0/22"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "msk-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name =  "msk-vpc"
  }
}

resource "aws_route" "route-public" {
  route_table_id         = aws_vpc.vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "subnet_az1" {
  availability_zone = data.aws_availability_zones.azs.names[0]
  cidr_block        = "192.168.0.0/24"
  vpc_id            = aws_vpc.vpc.id

  tags = {
    Name =  "msk-subnet-az1"
  }
}

resource "aws_subnet" "subnet_az2" {
  availability_zone = data.aws_availability_zones.azs.names[1]
  cidr_block        = "192.168.1.0/24"
  vpc_id            = aws_vpc.vpc.id

  tags = {
    Name =  "msk-subnet-az2"
  }
}

resource "aws_subnet" "subnet_az3" {
  availability_zone = data.aws_availability_zones.azs.names[2]
  cidr_block        = "192.168.2.0/24"
  vpc_id            = aws_vpc.vpc.id

  tags = {
    Name =  "msk-subnet-az3"
  }
}

resource "aws_subnet" "subnet_public" {
  availability_zone = data.aws_availability_zones.azs.names[0]
  cidr_block        = "192.168.3.0/24"
  vpc_id            = aws_vpc.vpc.id

  tags = {
    Name =  "msk-subnet-public"
  }
}

resource "aws_security_group" "sg" {
  name        = "msk-security-group"
  description = "allow inbound access to prometheus"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "SSH for prometheus or clients"
    protocol    = "TCP"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    description = "KAFKA TLS"
    protocol    = "TCP"
    from_port   = 9094
    to_port     = 9094
    cidr_blocks = [ aws_vpc.vpc.cidr_block ]
  }

  ingress {
    description = "JMX Exporter"
    protocol    = "TCP"
    from_port   = 11001
    to_port     = 11001
    cidr_blocks = [ aws_vpc.vpc.cidr_block ]
  }

  ingress {
    description = "Node Exporter"
    protocol    = "TCP"
    from_port   = 11002
    to_port     = 11002
    cidr_blocks = [ aws_vpc.vpc.cidr_block ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name =  "msk-sg"
  }
}

resource "aws_eip" "gw" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name =  "msk-EIP"
  }
}

resource "aws_nat_gateway" "gw" {
  subnet_id     = aws_subnet.subnet_public.id
  allocation_id = aws_eip.gw.id

  tags = {
    Name =  "msk-NAT"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }

  tags = {
    Name =  "msk-rt-private"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_vpc.vpc.main_route_table_id
}

resource "aws_route_table_association" "az1_private" {
  subnet_id      = aws_subnet.subnet_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "az2_private" {
  subnet_id      = aws_subnet.subnet_az2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "az3_private" {
  subnet_id      = aws_subnet.subnet_az3.id
  route_table_id = aws_route_table.private.id
}

# MSK

resource "aws_kms_key" "kms" {
  description = "example"
}

resource "aws_cloudwatch_log_group" "test" {
  name = "msk_broker_logs"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "poc-msk-broker-logs-bucket"
  acl    = "private"
  force_destroy = true
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "firehose.amazonaws.com"
    },
    "Effect": "Allow",
    "Sid": ""
  }
  ]
}
EOF
}

resource "aws_kinesis_firehose_delivery_stream" "test_stream" {
  name        = "terraform-kinesis-firehose-msk-broker-logs-stream"
  destination = "s3"

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn
  }

  tags = {
    LogDeliveryEnabled = "placeholder"
  }

  lifecycle {
    ignore_changes = [
      tags["LogDeliveryEnabled"],
    ]
  }
}

resource "aws_msk_cluster" "example" {
  cluster_name           = "example"
  kafka_version          = "2.7.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    ebs_volume_size = 100
    client_subnets = [
      aws_subnet.subnet_az1.id,
      aws_subnet.subnet_az2.id,
      aws_subnet.subnet_az3.id,
    ]
    security_groups = [aws_security_group.sg.id]
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.kms.arn
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.test.name
      }
      firehose {
        enabled         = true
        delivery_stream = aws_kinesis_firehose_delivery_stream.test_stream.name
      }
      s3 {
        enabled = true
        bucket  = aws_s3_bucket.bucket.id
        prefix  = "logs/msk-"
      }
    }
  }

  tags = {
    Name = "msk"
  }
}

# Prometheus

resource "aws_key_pair" "test" {
  key_name   = "test"
  public_key = file("test-key.pub")
}

locals {
  server1 = element([for s in split(",", aws_msk_cluster.example.bootstrap_brokers_tls) : split(":", s)[0] if s != ""], 0)
  server2 = element([for s in split(",", aws_msk_cluster.example.bootstrap_brokers_tls) : split(":", s)[0] if s != ""], 0)
  server3 = element([for s in split(",", aws_msk_cluster.example.bootstrap_brokers_tls) : split(":", s)[0] if s != ""], 0)
}

resource "aws_instance" "public-ec2" {
    ami           = var.ami_id
    instance_type = var.instance_type
    subnet_id = aws_subnet.subnet_public.id
    key_name      = "test"
    vpc_security_group_ids = [ aws_security_group.sg.id ]
    associate_public_ip_address = true

    tags = {
        Name = "prometheus"
    }

    depends_on = [ aws_vpc.vpc ]

    provisioner "file" {
        source      = "prometheus.yml"
        destination = "prometheus.yml"
      }

    provisioner "file" {
        source      = "targets.json"
        destination = "targets.json"
    }

    provisioner "remote-exec" {
      inline = [
        "wget https://github.com/prometheus/prometheus/releases/download/v2.25.2/prometheus-2.25.2.linux-amd64.tar.gz",
        "tar -zxvf prometheus-2.25.2.linux-amd64.tar.gz",
        "mv prometheus.yml prometheus-2.25.2.linux-amd64",
        "mv targets.json prometheus-2.25.2.linux-amd64",
        "cd prometheus-2.25.2.linux-amd64",
        "sed -i 's/server1/${local.server1}/' targets.json",
        "sed -i 's/server2/${local.server2}/' targets.json",
        "sed -i 's/server3/${local.server3}/' targets.json",
        "nohup ./prometheus &"
      ]
    }

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("test-key.pem")
      host        = self.public_dns
    }
}

# Outputs

output "zookeeper_connect_string" {
  value = aws_msk_cluster.example.zookeeper_connect_string
}

output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.example.bootstrap_brokers_tls
}

output "ec2-public-dns" {
    value = aws_instance.public-ec2.public_dns
}

output "ec2-public-ip" {
    value = aws_instance.public-ec2.public_ip
}


output "ec2-public-private-dns" {
    value = aws_instance.public-ec2.private_dns
}

output "ec2-public-private-ip" {
    value = aws_instance.public-ec2.private_ip
}

