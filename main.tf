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
    name = "base-64-lts"
    version = "20.4.0"
}

resource "triton_machine" "couchdb" {
    count = var.config.vm.replicas
    name = "couchdb-${count.index}"
    package = var.config.vm.package

    image = data.triton_image.os.id

    cns {
        services = ["couchdb"]
    }

    networks = var.config.machine_networks

    tags = {
        couchdb-role = "server"
    }
    
    affinity = ["couchdb-role!=~server"]

    connection {
        host = self.primaryip
    }

    provisioner "remote-exec" {
        inline = [
            "pkgin -y update",
            "pkgin -y in couchdb",
            "pkgin -y in erlang",
        ]
    }

    provisioner "remote-exec" {
        inline = [
            # Set up cluster args
            "sed -i -e 's/^-name couchdb@127.0.0.1/-name couchdb@${self.primaryip}/g' /opt/local/etc/couchdb/vm.args",
            "sed -i -e 's/^-setcookie monster/-setcookie ${random_string.cluster_cookie_secret.result}/g' /opt/local/etc/couchdb/vm.args",

            "echo '-kernel inet_dist_listen_min 9100' >> /opt/local/etc/couchdb/vm.args",
            "echo '-kernel inet_dist_listen_max 9200' >> /opt/local/etc/couchdb/vm.args",

            "svcadm enable epmd",
            "svcadm enable couchdb",

            # Wait for couchdb to respond
            "until $(curl --output /dev/null --silent --fail http://localhost:5984); do sleep 5; done",

            # Create admin user
            "curl -X PUT http://localhost:5984/_node/_local/_config/admins/${var.config.admin_user.name} -d '\"${var.config.admin_user.password}\"'",

            # Set the bind address so it's accessable from the outside
            "curl -X PUT http://${var.config.admin_user.name}:${var.config.admin_user.password}@localhost:5984/_node/_local/_config/chttpd/bind_address -d '\"0.0.0.0\"'",

            # Set the cluster ID
            "curl -X PUT http://${var.config.admin_user.name}:${var.config.admin_user.password}@localhost:5984/_node/_local/_config/couchdb/uuid -d '\"${random_uuid.cluster_id.result}\"'",

            # Set the HTTP cookie secret
            "curl -X PUT http://${var.config.admin_user.name}:${var.config.admin_user.password}@localhost:5984/_node/_local/_config/couch_httpd_auth/secret -d '\"${random_uuid.http_cookie_secret.result}\"'",

            # Set up the cluster
#            "curl -X POST -H \"Content-Type: application/json\" http://${var.config.admin_user.name}:${var.config.admin_user.password}@127.0.0.1:5984/_cluster_setup -d '{\"action\": \"enable_cluster\", \"bind_address\":\"0.0.0.0\", \"username\": \"${var.config.admin_user.name}\", \"password\":\"${var.config.admin_user.password}\", \"node_count\":\"${var.config.vm.replicas}\"}'",
        ]
    }
}

#
# NOTE: This next step is a bit of a hack.  The helm chart above
#       doesn't finish setting up the cluster so we have to log
#       in to the first k8s node and run kubectl exec direction
#       and use CURL to tell couchdb to finish.
# SEE:  https://github.com/apache/couchdb-helm/blob/master/couchdb/templates/NOTES.txt#L10
#
resource "null_resource" "cluster_setup" {
    depends_on = [triton_machine.couchdb[0]]

    connection {
        host = triton_machine.couchdb[0].primaryip
    }

    triggers = {
        trigger_ids = triton_machine.couchdb[0].id
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/setup_cluster.sh.tpl", {
            admin_user_name = var.config.admin_user.name
            admin_user_password = var.config.admin_user.password
            node_count = var.config.vm.replicas
            node_ips = [for node_number in range(var.config.vm.replicas) : triton_machine.couchdb[node_number].primaryip]
        })
        destination = "/tmp/setup_cluster.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "bash /tmp/setup_cluster.sh"
        ]
    }
}
