#!/bin/bash

echo "Deploying VDT Student Management Stack với ArgoCD Multiple Sources..."

# 1. Deploy Database (Single Source)
echo "1. Deploying Database Application..."
kubectl apply -f vdt-database-application.yaml

# 2. Deploy Backend (Multiple Sources)
echo "2. Deploying Backend Application..."
kubectl apply -f vdt-backend-application.yaml

# 3. Deploy Frontend (Multiple Sources) 
echo "3. Deploying Frontend Application..."
kubectl apply -f vdt-frontend-application.yaml

echo "Checking ArgoCD Applications status..."
kubectl get applications -n argocd

echo "Waiting for applications to sync..."
sleep 30

echo "Checking deployed pods..."
kubectl get pods -n default

echo "Checking services..."
kubectl get svc -n default

echo "Access URLs:"
echo "Frontend: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30001"
echo "Backend API: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30002"
echo "ArgoCD: https://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30000"