# This file is not auto-generated. DO NOT DELETE IT. 
provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "kiratech_test" {
  metadata {
    name = "kiratech-test"
  }
}