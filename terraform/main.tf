terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "./tf_key.json"
  folder_id                = "b1gudftn90gk7phlf79h" 
  zone                     = "ru-central1-b"
}

resource "yandex_vpc_network" "foo" {

}

resource "yandex_vpc_subnet" "foo" {
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.foo.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

resource "yandex_container_registry" "catgpt-myregistry" {
  name = "catgpt-myregistry"
}

locals {
  folder_id = "b1gudftn90gk7phlf79h"
  service-accounts = toset([
    "catgpt-sa",
    "catgpt-ig-sa",
  ])
  catgpt-sa-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
  catgpt-ig-sa-roles = toset([
    "compute.editor",
    "iam.serviceAccounts.user",
    "load-balancer.admin",
    "vpc.publicAdmin",
    "vpc.user"
  ])

}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = "${local.folder_id}-${each.key}"
}
resource "yandex_resourcemanager_folder_iam_member" "catgpt-roles" {
  for_each  = local.catgpt-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["catgpt-sa"].id}"
  role      = each.key
}
resource "yandex_resourcemanager_folder_iam_member" "catgpt-ig-roles" {
  for_each  = local.catgpt-ig-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["catgpt-ig-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}

resource "yandex_compute_instance_group" "catgpt" {
  name                = "catgpt-ig"
  folder_id           = local.folder_id
  service_account_id = yandex_iam_service_account.service-accounts["catgpt-ig-sa"].id
  ####adding
  depends_on = [ 
    yandex_resourcemanager_folder_iam_member.catgpt-ig-roles
   ]
 
  deletion_protection = false
  instance_template {
    platform_id = "standard-v2"
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    boot_disk {
      initialize_params {
        type = "network-hdd"
        size = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    network_interface {
      network_id = yandex_vpc_network.foo.id
      subnet_ids = ["${yandex_vpc_subnet.foo.id}"]
      nat = true
    }
   
    metadata = {
      docker-compose = file(
        "${path.module}/docker-compose.yaml",
        # {
        #   folder_id   = "${local.folder_id}",
        #   registry_id = "${yandex_container_registry.catgpt-myregistry.id}",
        # }
      )
      
      ssh-keys = "ubuntu:${file("~/.ssh/devops_training.pub")}"
    }
    # временно коммент
    network_settings {
      type = "STANDARD"
    }
    
  }

 
  load_balancer {
    target_group_name = "catgpt"

  }

  # health_check {
  #   http_options {
  #     port = 8080
  #     path = "/ping"
  #   }
  # }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-b"]
  }

  deploy_policy {
    max_unavailable = 2
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
}

resource "yandex_lb_network_load_balancer" "lb-catgpt" {
  name = "catgpt"

  listener {
    name        = "cat-listener"
    port        = 80
    target_port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.catgpt.load_balancer[0].target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}

