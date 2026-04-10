# Run locally this html and draw

```
python3 -m http.server 8000
```

- served on browser http://localhost:8000


# Setting Up a Kubernetes Cluster with Docker Compose on macOS

Quick note before we dive in: "Kubernetes on Docker Compose" isn't really a standard combo — Docker Compose orchestrates containers directly, while Kubernetes is its own orchestrator. What people usually mean by this is one of two things: running a local K8s cluster using Docker as the container runtime (via **kind** or **k3d**, which use Docker Compose-style container setups under the hood), or using Docker Desktop's built-in Kubernetes. I'll go with **kind** (Kubernetes in Docker) since it's the most common "K8s on Docker" path on Mac and gives you a real multi-node cluster. If you actually wanted plain Docker Compose (no K8s), let me know and I'll rewrite.

## Step 1: Prerequisites

Install Homebrew if you don't have it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install Docker Desktop for Mac (required — kind runs nodes as Docker containers):

```bash
brew install --cask docker
```

Launch Docker Desktop from Applications and wait until the whale icon in the menu bar is steady. Verify:

```bash
docker --version
docker ps
```

Install kind and kubectl:

```bash
brew install kind kubectl
```

Verify both:

```bash
kind --version
kubectl version --client
```

## Step 2: Create a Cluster Config

Create a working directory and a cluster config file that defines a control-plane node plus two workers, with port 80 on your Mac mapped into the cluster so you can hit the nginx page in a browser.

```bash
mkdir ~/k8s-demo && cd ~/k8s-demo
```

Create `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8080
        protocol: TCP
  - role: worker
  - role: worker
```

## Step 3: Create the Cluster

```bash
kind create cluster --name demo --config kind-config.yaml
```

This pulls the node image and spins up three Docker containers acting as your K8s nodes. Takes a minute or two. Verify:

```bash
kubectl cluster-info --context kind-demo
kubectl get nodes
```

You should see one control-plane and two worker nodes in `Ready` state.

## Step 4: Create Your Static HTML

Create `index.html` in the working directory:

```html
<!DOCTYPE html>
<html>
<head><title>Hello from K8s</title></head>
<body>
  <h1>Hello from Kubernetes on Mac!</h1>
  <p>Served by nginx in a kind cluster.</p>
</body>
</html>
```

## Step 5: Load the HTML into a ConfigMap

A ConfigMap is the cleanest way to get a small static file into a pod without building a custom image:

```bash
kubectl create configmap html-content --from-file=index.html
```

Verify:

```bash
kubectl get configmap html-content -o yaml
```

## Step 6: Create the Deployment and Service

Create `nginx-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-static
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-static
  template:
    metadata:
      labels:
        app: nginx-static
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          configMap:
            name: html-content
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-static
spec:
  type: NodePort
  selector:
    app: nginx-static
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

The `nodePort: 30080` matches the `containerPort` in the kind config, which is mapped to host port `8080`.

## Step 7: Apply It

```bash
kubectl apply -f nginx-deployment.yaml
```

Watch the pods come up:

```bash
kubectl get pods -w
```

Once both show `Running`, hit Ctrl+C. Check the service:

```bash
kubectl get svc nginx-static
```

## Step 8: View the Page

Open your browser to:

```
http://localhost:8080
```

You should see your "Hello from Kubernetes on Mac!" page. You can also curl it:

```bash
curl http://localhost:8080
```

## Step 9: Useful Follow-up Commands

```bash
kubectl logs -l app=nginx-static          # view nginx logs
kubectl scale deployment nginx-static --replicas=5   # scale up
kubectl describe svc nginx-static          # service details
```

## Step 10: Cleanup

When you're done:

```bash
kubectl delete -f nginx-deployment.yaml
kubectl delete configmap html-content
kind delete cluster --name demo
```

That's the full path from zero to a working multi-node K8s cluster serving a static page on your Mac. If you want me to redo this with **k3d** (which is even closer to a "docker compose for k8s" feel) or with plain Docker Compose and no Kubernetes at all, say the word.