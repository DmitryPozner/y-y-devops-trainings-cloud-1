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
    "test-acc-2",
  ])
  test-acc-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = each.key
}
resource "yandex_resourcemanager_folder_iam_member" "test-acc-roles" {
  for_each  = local.test-acc-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["test-acc-2"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}
resource "yandex_compute_instance" "catgpt-1" {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["test-acc-2"].id
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      subnet_id = "${yandex_vpc_subnet.foo.id}"
      nat = true
    }
    boot_disk {
      initialize_params {
        type = "network-hdd"
        size = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    metadata = {
      docker-compose = file("${path.module}/docker-compose.yaml")
      ssh-keys  = "ubuntu:${file("~/.ssh/devops_training.pub")}"
    }
}
# resource "yandex_compute_instance" "catgpt-2" {
#     # platform_id        = "standard-v2"
#     service_account_id = yandex_iam_service_account.service-accounts["test-acc-2"].id
#     resources {
#       cores         = 2
#       memory        = 1
#       core_fraction = 5
#     }
#     scheduling_policy {
#       preemptible = true
#     }
#     network_interface {
#       subnet_id = "${yandex_vpc_subnet.foo.id}"
#       nat = true
#     }
#     boot_disk {
#       initialize_params {
#         type = "network-hdd"
#         size = "30"
#         image_id = data.yandex_compute_image.coi.id
#       }
#     }
#     metadata = {
#       docker-compose = file("${path.module}/docker-compose.yaml")
#       ssh-keys  = "ubuntu:${file("~/.ssh/devops_training.pub")}"
#     }
# }

resource "yandex_lb_target_group" "target_group" {
  target {
    subnet_id = "${yandex_vpc_subnet.foo.id}"
    address = "${yandex_compute_instance.catgpt-1.instances[0].network_interface[0].ip_address}"
  }
  # target {
  #   subnet_id = "${yandex_vpc_subnet.foo.id}"
  #   address = "${yandex_compute_instance.catgpt-2.network_interface.0.ip_address}"
  # }
}

resource "yandex_lb_network_load_balancer" "load-balancer-1" {
    name         = "load-balancer1"
    type         = "internal"
    deletion_protection = "false"

    listener {
      name = "my-listener"
      port = 8080
      protocol    = "http"
     
    }
    

    
    attached_target_group {
      target_group_id = "${yandex_lb_target_group.target_group.id}"
      healthcheck {
        name = "http"
          http_options {
            port = 8080
            path = "/ping"
        }
      }
    }
}

    



# resource "yandex_lb_target_group_attachment" "attachment1" {
#   target_group_id = yandex_lb_target_group.target_group.id
#   target_id = yandex_compute_instance.catgpt-1.id
# }

# resource "yandex_lb_target_group_attachment" "attachment2" {
#   target_group_id = yandex_lb_target_group.target_group.id
#   target_id = yandex_compute_instance.catgpt-2.id
# }

#    

