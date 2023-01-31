resource "aws_instance" "k8-worker" {
  depends_on = [
    aws_subnet.private_sn,
    aws_security_group.security-group,
  ]

  count         = var.k8_worker_count
  ami           = var.ami_id
  instance_type = var.aws_instance_type_worker
  subnet_id     = aws_subnet.private_sn.id

  key_name = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.security-group.id]

  tags = {
    Name = element(var.k8_worker_names, count.index)
  }
}

resource "aws_instance" "k8-master" {
  depends_on = [
    aws_subnet.public_sn,
    aws_security_group.security-group,
  ]

  count         = var.k8_master_count
  ami           = var.ami_id
  instance_type = var.aws_instance_type_master
  subnet_id     = aws_subnet.private_sn.id

  key_name = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.security-group.id]

  tags = {
    Name = element(var.k8_master_names, count.index)
  }
}

resource "aws_instance" "bastion-host" {
  depends_on = [
    aws_vpc.vpc,
    aws_subnet.public_sn,
    aws_internet_gateway.IG,
    aws_route_table.ig-route-table,
    aws_route_table_association.IG-RT-association,
    aws_route_table_association.NAT-Gateway-RT-Association,
    aws_instance.k8-master,
    aws_security_group.security-group,
    aws_instance.k8-worker
  ]

  ami           = var.ami_id
  instance_type = var.aws_instance_type_bastion
  subnet_id     = aws_subnet.public_sn.id

  key_name = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.security-group.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.key_pair_file_path)
    host        = self.public_dns
  }

  provisioner "file" {
    source      = var.key_pair_file_path
    destination = "/home/ubuntu/.ssh/${var.key_pair_name}.pem"
  }

  provisioner "file" {
    source      = "${path.cwd}/gen-hosts-yaml.sh"
    destination = "/home/ubuntu/gen-hosts-yaml.sh"
  }

  provisioner "file" {
    source      = "${path.cwd}/setup-k8-bastion.sh"
    destination = "/home/ubuntu/setup-k8-bastion.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/setup-k8-bastion.sh",
      "/home/ubuntu/setup-k8-bastion.sh -k ${var.key_pair_name} -m ${join(",", [for i in aws_instance.k8-master : i.private_ip])} -w ${join(",", [for i in aws_instance.k8-worker : i.private_ip])}",
    ]
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "ssh-keygen -t rsa -b 4096 -f /home/ubuntu/.ssh/id_rsa -N ''",
  #     "ssh-keyscan -H ${aws_instance.k8-master.private_ip} >> /home/ubuntu/.ssh/known_hosts",
  #     "ssh-keyscan -H ${aws_instance.k8-worker1.private_ip} >> /home/ubuntu/.ssh/known_hosts",
  #     "ssh-keyscan -H ${aws_instance.k8-worker2.private_ip} >> /home/ubuntu/.ssh/known_hosts",
  #     "sudo chmod 400 /home/ubuntu/.ssh/akarx.pem",
  #     "cat /home/ubuntu/.ssh/id_rsa.pub | ssh -i /home/ubuntu/.ssh/akarx.pem ubuntu@${aws_instance.k8-master.private_ip} 'cat >> /home/ubuntu/.ssh/authorized_keys'",
  #     "cat /home/ubuntu/.ssh/id_rsa.pub | ssh -i /home/ubuntu/.ssh/akarx.pem ubuntu@${aws_instance.k8-worker1.private_ip} 'cat >> /home/ubuntu/.ssh/authorized_keys'",
  #     "cat /home/ubuntu/.ssh/id_rsa.pub | ssh -i /home/ubuntu/.ssh/akarx.pem ubuntu@${aws_instance.k8-worker2.private_ip} 'cat >> /home/ubuntu/.ssh/authorized_keys'",
  #     "sudo apt update -y",
  #     "sudo apt install python3-pip -y",
  #     "cd /home/ubuntu",
  #     "git clone https://github.com/kubernetes-sigs/kubespray.git",
  #     "cd kubespray",
  #     "export PATH=/home/ubuntu/.local/bin:$PATH",
  #     "echo 'export PATH=/home/ubuntu/.local/bin:$PATH' >> /home/ubuntu/.bashrc",
  #     "source /home/ubuntu/.bashrc",
  #     "pip3 install -r requirements.txt",
  #     "cp -rfp inventory/sample inventory/mycluster",
  #     "cp /home/ubuntu/hosts.yaml inventory/mycluster/hosts.yaml",
  #     "sed -i 's/master-ip/${aws_instance.k8-master.private_ip}/g ; s/worker1-ip/${aws_instance.k8-worker1.private_ip}/g ; s/worker2-ip/${aws_instance.k8-worker2.private_ip}/g' inventory/mycluster/hosts.yaml",
  #     "echo -e '[defaults]\nhost_key_checking = False' >> /home/ubuntu/.ansible.cfg",
  #     "sed -i 's/# kube_read_only_port: 10255/kube_read_only_port: 10255/g' inventory/mycluster/group_vars/all/all.yml",
  #     "/home/ubuntu/.local/bin/ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml",
  #     "ssh -i /home/ubuntu/.ssh/akarx.pem ${aws_instance.k8-master.private_ip} 'sudo cp /etc/kubernetes/admin.conf /home/ubuntu/admin.conf'",
  #     "ssh -i /home/ubuntu/.ssh/akarx.pem ${aws_instance.k8-master.private_ip} 'sudo chown ubuntu:ubuntu /home/ubuntu/admin.conf'",
  #     "mkdir $HOME/.kubernetes",
  #     "scp -i /home/ubuntu/.ssh/akarx.pem ${aws_instance.k8-master.private_ip}:/home/ubuntu/admin.conf /home/ubuntu/.kubernetes",
  #     "USERNAME=$(whoami)",
  #     "sudo chown -R $USERNAME:$USERNAME $HOME/.kubernetes/admin.conf",
  #     "echo 'export KUBECONFIG=$HOME/.kubernetes/admin.conf' >> /home/ubuntu/.bashrc",
  #     "source /home/ubuntu/.bashrc",
  #     "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl'",
  #     "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
  #     "sed -i 's/127.0.0.1/${aws_instance.k8-master.private_ip}/g' /home/ubuntu/.kubernetes/admin.conf",
  #     "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3",
  #     "chmod 700 get_helm.sh",
  #     "./get_helm.sh",
  #     "helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator",
  #     "helm repo update",
  #     "kubectl create ns spark-operator",
  #     "helm install spark-operator spark-operator/spark-operator --namespace spark-operator --set enableWebhook=true --set sparkJobNamespace=default",
  #   ]
  # }

  tags = {
    Name = var.bh_name
  }
}

output "connect_to_bastion" {

  depends_on = [
    aws_instance.bastion-host
  ]

  value = "ssh -i ${var.key_pair_file_path} ubuntu@${aws_instance.bastion-host.public_ip}"
}

output "master_node_ips" {
  depends_on = [
    aws_instance.k8-master
  ]

  value = {
    for instance in aws_instance.k8-master : instance.id => instance.private_ip
  }
}

output "worker_node_ips" {
  depends_on = [
    aws_instance.k8-worker
  ]

  value = {
    for instance in aws_instance.k8-worker : instance.id => instance.private_ip
  }
}

