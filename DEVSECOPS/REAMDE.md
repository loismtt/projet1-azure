# 🚀 Projet DevSecOps avec Kustomize, Trivy et ArgoCD

Ce dépôt contient la configuration de déploiement Kubernetes pour l'application `nginx-test`, structurée pour supporter les environnements **Dev** et **Prod** en utilisant **Kustomize**.

---

## 🏗️ Structure du Dépôt (Kustomize)

Le déploiement est organisé en une **Base** (configuration générique) et deux **Overlays** (adaptations spécifiques à l'environnement). 

| Dossier | Rôle | Contenu Typique |
| :--- | :--- | :--- |
| **`/base`** | **Configuration de base** | Contient la définition complète et générique de l'application : `kustomization.yaml`, `service.yaml`, `configmap.yaml`, `deployment.yaml`. Ces fichiers sont identiques pour tous les environnements. |
| **`/overlays/dev`** | **Environnement de Développement** | Adapte la base pour DEV : `kustomization.yaml`, `patch-configmap.yaml`, `namespace.yaml`, `service-patch.yaml`. Applique des modifications légères et des configurations spécifiques (ex: couleur DEV, NodePort de test). |
| **`/overlays/prod`** | **Environnement de Production** | Adapte la base pour PROD : `kustomization.yaml`, `patch-configmap.yaml`, `namespace.yaml`, `service-patch.yaml`. Applique des configurations strictes (ex: couleur PROD, nombre de réplicas supérieur, type de Service LoadBalancer). |

### Rôle des Fichiers

| Fichier | Description |
| :--- | :--- |
| **`kustomization.yaml`** | Le manifeste principal de Kustomize. Il **agrège** les ressources de base (`resources: ../../base`) et liste les **patches** à appliquer. |
| **`deployment.yaml`** | Définit le déploiement de l'application (l'image Docker, les ressources, les réplicas). |
| **`service.yaml`** | Définit la manière d'accéder à l'application dans le cluster (ClusterIP, NodePort, LoadBalancer). |
| **`configmap.yaml`** | Contient des données de configuration non sensibles (comme le contenu HTML, les variables d'environnement). |
| **`patch-configmap.yaml`** | Modifie le contenu du `configmap.yaml` de la base (ex: change la couleur d'arrière-plan ou le titre pour l'environnement). |
| **`service-patch.yaml`** | Modifie le `Service` de la base (ex: passe de `ClusterIP` à `NodePort` pour DEV, ou à `LoadBalancer` pour PROD). |
| **`namespace.yaml` (souvent remplacé)** | **ATTENTION:** Ce fichier définit la ressource `Namespace`. Pour éviter les erreurs, il est préférable de définir le Namespace directement dans le `kustomization.yaml` de l'overlay via le champ **`namespace: <nom>`**. |

---

## 💡 Principes et Outils

### 1. Kustomize (Configuration Management)

Kustomize est un outil natif de Kubernetes utilisé pour la **personnalisation des configurations YAML**.

* **Fonctionnement :** Il utilise un ensemble de manifestes de **Base** (qui sont la vérité unique) et des fichiers d'**Overlay** qui appliquent des **patches** pour modifier ou ajouter des champs (comme le nombre de réplicas ou un préfixe de nom) sans jamais modifier la Base.
* **Commande Clé :** `kustomize build overlays/<env>` génère le manifeste final prêt à être appliqué à Kubernetes.

### 2. Trivy (Security Scanning - DevSecOps)

Trivy est un scanner de vulnérabilités polyvalent. Il est intégré dans le pipeline CI/CD pour renforcer l'aspect **SecOps**.

* **Rôle :**
    * **Scan d'Images :** Vérifie les vulnérabilités dans les images Docker utilisées par votre application (ex: votre image `nginx`).
    * **Scan de Configuration :** Peut scanner les fichiers YAML de Kustomize (ou Kubernetes) pour détecter les mauvaises pratiques de sécurité (ex: utilisation de l'utilisateur `root`, privilèges excessifs).

### 3. Argo CD (Continuous Delivery)

Argo CD est un outil de **GitOps** qui assure la **livraison continue** des applications vers Kubernetes.

* **Rôle :** Argo CD surveille ce dépôt Git.
    * Il est configuré pour pointer vers un des chemins Kustomize (ex: `DEVSECOPS/kustomize/overlays/prod`).
    * Lorsque le `kustomization.yaml` ou un fichier de patch est modifié et poussé vers Git, Argo CD détecte la différence, exécute un `kustomize build` en interne, et **synchronise** automatiquement l'état du cluster Kubernetes avec l'état souhaité dans Git.
* **Principe GitOps :** La vérité unique de l'état du cluster réside dans Git, non pas dans le cluster lui-même.