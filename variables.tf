variable "bh_name" {
  type    = string
  default = "bastion-host"
}

variable "k8_master_count" {
  type    = number
  default = 2
}

variable "k8_master_names" {
  type    = list(string)
  default = ["k8-master-1", "k8-master-2"]
}

variable "k8_worker_count" {
  type    = number
  default = 3
}

variable "k8_worker_names" {
  type    = list(string)
  default = ["k8-worker-1", "k8-worker-2", "k8-worker-3"]
}

variable "key_pair_name" {
  type    = string
  default = "akarx"
}

variable "aws_instance_type_bastion" {
  type    = string
  default = "t2.micro"
}

variable "aws_instance_type_master" {
  type    = string
  default = "t3.large"
}

variable "aws_instance_type_worker" {
  type    = string
  default = "t3.large"
}

variable "vpc_name" {
  type    = string
  default = "akarx-vpc"
}

variable "public_subnet_name" {
  type    = string
  default = "akarx-public-subnet"
}

variable "private_subnet_name" {
  type    = string
  default = "akarx-private-subnet"
}

variable "internet_gateway_name" {
  type    = string
  default = "akarx-internet-gateway"
}

variable "ig_route_table_name" {
  type    = string
  default = "akarx-route-table"
}

variable "nat_gateway_name" {
  type    = string
  default = "akarx-nat-gateway"
}

variable "nat_route_table_name" {
  type    = string
  default = "akarx-nat-route-table"
}

variable "security_group_name" {
  type    = string
  default = "akarx-security-group"
}

variable "key_pair_file_path" {
  type    = string
  default = "/home/akarx/akarx.pem"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "ami_id" {
  type        = string
  description = "value of ami id"

  # Default is Ubuntu 20.04 LTS (HVM)
  default = "ami-0ef82eeba2c7a0eeb"
}
