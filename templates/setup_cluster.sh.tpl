#!/bin/bash
set -e

%{ for node_num in range(1, node_count) }
curl -X POST -H "Content-Type: application/json" http://${admin_user_name}:${admin_user_password}@127.0.0.1:5984/_cluster_setup -d '{"action": "add_node", "host":"${node_ips[node_num]}", "port": 5984, "username": "${admin_user_name}", "password":"${admin_user_password}"}'
%{ endfor }

# Finally, finish cluster setup
curl -s http://${admin_user_name}:${admin_user_password}@127.0.0.1:5984/_cluster_setup -X POST -H "Content-Type: application/json" -d '{"action": "finish_cluster"}'
