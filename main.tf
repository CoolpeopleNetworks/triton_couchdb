data "triton_account" "main" {}

resource "random_uuid" "cluster_id" {
}

resource "random_uuid" "http_cookie_secret" {
}

resource "random_string" "cluster_cookie_secret" {
  length = 16
  special = false
}

data "triton_image" "os" {
    name = "debian-9-cloudinit"
    version = "1.0.0"
}

resource "triton_machine" "couchdb" {
    count = var.server_replicas
    name = "couchdb-${count.index}"
    package = var.server_package

    image = data.triton_image.os.id

    cns {
        services = ["couchdb"]
    }

    networks = [
        data.triton_network.public.id,
        data.triton_network.private.id
    ]

    cloud_config = templatefile("${path.module}/cloud-config.yml.tpl", {
        dns_suffix = var.dns_suffix,
        server_replicas = var.server_replicas
        cluster_id = random_uuid.cluster_id.result
        http_cookie_secret = random_uuid.http_cookie_secret
        cluster_cookie_secret = random_uuid.cluster_cookie_secret
    })
}
