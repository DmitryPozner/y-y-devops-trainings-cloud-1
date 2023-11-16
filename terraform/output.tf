# output "container_registry_id" {
#     value = yandex_container_registry.catgpt.id
  
# }


#terraform apply -target yandex_container_registry.registry1
#terraform apply -target yandex_container_registry.catgpt-myregistry
#container_registry_id = "crpfls0aj9kujeneeqrb"
#export REGISTRY_ID=crpfls0aj9kujeneeqrb; docker build -t "cr.yandex/$REGISTRY_ID/catgpt:1" . && docker push "cr.yandex/$REGISTRY_ID/catgpt:1"