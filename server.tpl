#cloud-config
package_update: true
packages:
  - curl
  - jq

runcmd:
  - echo "=== Installation de K3s (server) ==="
  - curl -sfL https://get.k3s.io | K3S_TOKEN='${k3s_token}' sh -s - server --cluster-init

  - echo "=== Création du manifeste NGINX ==="
  - mkdir -p /etc/k3s/manifests
  - cat > /etc/k3s/manifests/nginx-daemonset.yaml << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-dynamic
  namespace: default
spec:
  selector:
    matchLabels:
      app: nginx-dynamic
  template:
    metadata:
      labels:
        app: nginx-dynamic
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 80
          hostPort: 8080
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        command:
        - sh
        - -c
        - |
          echo "<html><body>
          <h1>Bonjour depuis le cluster K3s</h1>
          <p>Hostname: ${NODE_NAME}</p>
          <p>IP privée: ${POD_IP}</p>
          </body></html>" > /usr/share/nginx/html/index.html
          exec nginx -g 'daemon off;'
EOF

  - echo "=== Redémarrage du service K3s ==="
  - systemctl restart k3s
