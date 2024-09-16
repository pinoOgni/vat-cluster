# This file is not auto-generated. DO NOT DELETE IT. 
# It is used to install the online boutique using helm.

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "onlineboutique" {
  name       = "onlineboutique"
  repository = "oci://us-docker.pkg.dev/online-boutique-ci/charts"
  chart      = "onlineboutique"
  namespace  = "kiratech-test"

  values = [
    <<-EOF
      frontend:
        externalService: false  # In this way the frontend load balancer is not used.
    EOF
  ]
}

