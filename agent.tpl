#cloud-config
package_update: true
packages:
  - curl

runcmd:
  - echo "=== Installation de K3s (agent) ==="
  - curl -sfL https://get.k3s.io | K3S_URL='https://${server_private_ip}:6443' K3S_TOKEN='${k3s_token}' sh -s - agent
