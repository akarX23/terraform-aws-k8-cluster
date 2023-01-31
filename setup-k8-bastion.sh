#!/bin/bash

# k ===> Key Pair Name
# m ===> Master IPs
# w ===> Worker IPs

# Extract arguments
while getopts ":k:m:w:" opt; do
    case $opt in
        k) key_name=$OPTARG
        ;;
        m)
            masters=$OPTARG
            master_ips=($(echo $OPTARG | tr "," " "))
        ;;
        w)
            workers=$OPTARG
            worker_ips=($(echo $OPTARG | tr "," " "))
        ;;
        \?) echo "Invalid option -$OPTARG" >&2
        ;;
    esac
done

all_ips=("${master_ips[@]}" "${worker_ips[@]}")
KEY_PATH=/home/ubuntu/.ssh/$key_name.pem

###### START SETTING UP OF K8 CLUSTER #######

# Generate RSA Key for key-less access
ssh-keygen -t rsa -b 4096 -f /home/ubuntu/.ssh/id_rsa -N ''

# Give right permission to pem file
sudo chmod 400 $KEY_PATH

# Copy public key to all nodes
for ip in "${all_ips[@]}"; do
    ssh-keyscan -H $ip >> ~/.ssh/known_hosts
    cat /home/ubuntu/.ssh/id_rsa.pub | ssh -i $KEY_PATH ubuntu@$ip 'cat >> /home/ubuntu/.ssh/authorized_keys'
done

# Install pip3
sudo apt update -y
sudo apt install python3-pip -y

# Setup Kubespray
cd /home/ubuntu
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
export PATH=/home/ubuntu/.local/bin:$PATH
echo 'export PATH=/home/ubuntu/.local/bin:$PATH' >> /home/ubuntu/.bashrc
pip3 install -r requirements.txt
cp -rfp inventory/sample inventory/mycluster

# Generate hosts.yaml file with our script
chmod +x /home/ubuntu/gen-hosts-yaml.sh
/home/ubuntu/gen-hosts-yaml.sh -f inventory/mycluster/hosts -m $masters -w $workers

# Generate ansible config
echo -e '[defaults]\nhost_key_checking = False' >> /home/ubuntu/.ansible.cfg

# Changing kube_read_only_port
sed -i 's/# kube_read_only_port: 10255/kube_read_only_port: 10255/g' inventory/mycluster/group_vars/all/all.yml

# Execute ansible playbook
/home/ubuntu/.local/bin/ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml

# Copy admin.conf from root directory in a master node to user directory in the same master node so we can get access to that file
ssh -i $KEY_PATH ${master_ips[0]} 'sudo cp /etc/kubernetes/admin.conf /home/ubuntu/admin.conf'

# Give ubuntu user in master node permission to access admin.conf
ssh -i $KEY_PATH ${master_ips[0]} 'sudo chown ubuntu:ubuntu /home/ubuntu/admin.conf'

# Copy admin.conf from master node to bastion host
mkdir $HOME/.kubernetes
scp -i $KEY_PATH ${master_ips[0]}:/home/ubuntu/admin.conf /home/ubuntu/.kubernetes

# Give user in bastion host access to the admin.conf
USERNAME=$(whoami)
sudo chown $USERNAME:$USERNAME /home/ubuntu/.kubernetes/admin.conf

# Set KUBECONFIG environment variable
echo 'export KUBECONFIG=$HOME/.kubernetes/admin.conf' >> /home/ubuntu/.bashrc
source /home/ubuntu/.bashrc

# Install kubectl
curl -LO "https://dl.k8s.io/release/v1.24.7/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install helm
cd /home/ubuntu
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Change the address in admin.conf to use the private ip of the master node or else bastion won't be able to connect to k8 cluster
sed -i "s/127.0.0.1/${master_ips[0]}/g" /home/ubuntu/.kubernetes/admin.conf

###### END SETTING UP OF K8 CLUSTER #######


