# AUTO-GENERATED FILE FROM ANSIBLE

variable "manager_ips" {
  description = "List of manager node IPs"
  type        = list(string)
  default     = ["192.168.1.103"]
}

variable "worker_ips" {
  description = "List of worker node IPs"
  type        = list(string)
  default     = ["192.168.1.104"]
}

resource "null_resource" "kubeadm_init" {
  provisioner "remote-exec" {
    inline = [
      # Initialize Kubernetes with a network CIDR suitable for Calico
      "sudo kubeadm init --config=init-config.yaml",
      
      # Set up kubeconfig for the vagrant user
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      
      # To solve some security warning from https://www.cisecurity.org/benchmark/kubernetes
      "sudo chmod 600 /var/lib/kubelet/config.yaml",
      "sudo chmod 600 /lib/systemd/system/kubelet.service",
      "sudo chmod 600 /etc/kubernetes/pki/ca.crt",

      # Install Calico with custom-resource changes
      "kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml",
      "curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml -O",
      "sed -i '/cidr:/s|cidr:.*|cidr: 172.22.0.0/16 |' custom-resources.yaml",
      "sudo sleep 15", # to have all calico CR installed
      "kubectl create -f custom-resources.yaml",

      "alias k=kubectl",
    ]
    connection {
      type          = "ssh"
      host          = "192.168.1.103"
      user          = "vagrant"
      private_key   = file("~/.ssh/vagrant_machines")
    }
  }

  provisioner "local-exec" {
    command = <<EOT
    scp -o StrictHostKeyChecking=no -i ~/.ssh/vagrant_machines vagrant@192.168.1.103:/home/vagrant/.kube/config ~/.kube/config
    EOT
  }
}

# TODO find a better way
# Ensure the .kube directory exists on worker nodes
resource "null_resource" "create_kube_directory" {
  for_each = toset(var.worker_ips)

  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/.kube"
    ]
    
    connection {
      type        = "ssh"
      host        = each.value
      user        = "vagrant"
      private_key = file("~/.ssh/vagrant_machines")
    }
  }

  depends_on = [null_resource.kubeadm_init]  
}

# Copy kubeconfig to all worker nodes
resource "null_resource" "copy_kubeconfig_to_workers" {
  for_each = toset(var.worker_ips)

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ~/.ssh/vagrant_machines ~/.kube/config vagrant@${each.value}:~/.kube/config"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
    ]
    
    connection {
      type        = "ssh"
      host        = each.value
      user        = "vagrant"
      private_key = file("~/.ssh/vagrant_machines")
    }
  }

  depends_on = [null_resource.create_kube_directory]  # Ensure the directory is created first
}


# kubeadm join for all workers
resource "null_resource" "kubeadm_join" {
  for_each = toset(var.worker_ips)

  provisioner "remote-exec" {
    inline = [
      "sudo kubeadm join --config=join-config.yaml",
      "sudo chmod 600 /var/lib/kubelet/config.yaml",
      "sudo chmod 600 /lib/systemd/system/kubelet.service",
      "sudo chmod 600 /etc/kubernetes/pki/ca.crt",
    ]
    
    connection {
      type        = "ssh"
      host        = each.value
      user        = "vagrant"
      private_key = file("~/.ssh/vagrant_machines")
    }
  }

  depends_on = [null_resource.copy_kubeconfig_to_workers]
}
