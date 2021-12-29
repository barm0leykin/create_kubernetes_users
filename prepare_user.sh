#!/bin/sh

# Prepare kubernetes config for new user
#
# USING:   ./prepare_user.sh $USER_NAME $USER_DEPARTAMENT
# EXAMPLE: ./prepare_user.sh geytsbills management

export $(grep -v '^#' templates/k.env | xargs -d '\n')
export USER_NAME=$1
export USER_DEPARTAMENT=$2

mkdir -p ${USER_NAME}

# gen key
echo "Generating user key..."
openssl genrsa -out ${USER_NAME}/${USER_NAME}.key 2048

echo "\n Generating CSR..."
# gen csr config
# j2 -f env templates/username_csr.cnf.j2 templates/k.env > ${USER_NAME}/${USER_NAME}_csr.cnf
j2 templates/username_csr.cnf.j2 > ${USER_NAME}/${USER_NAME}_csr.cnf

# gen csr
openssl req -new -key ${USER_NAME}/${USER_NAME}.key -subj "/CN=system:node:${USER_NAME} /OU="system:nodes" /O=system:nodes" -config ${USER_NAME}/${USER_NAME}_csr.cnf -out ${USER_NAME}/${USER_NAME}.csr

# convert csr to base64
export BASE64_CSR=$(cat ${USER_NAME}/${USER_NAME}.csr | base64 | tr -d '\n')

# create csr yaml manifest
j2 templates/username_csr.yaml.j2 > ${USER_NAME}/${USER_NAME}_csr.yaml

# apply csr yaml manifest to kubernetes
echo "\n apply csr yaml manifest to kubernetes..."
cat ${USER_NAME}/${USER_NAME}_csr.yaml | kubectl apply -f -

# show csr
echo "\n Kubernetes CSR status: "
kubectl get csr | grep ${USER_NAME}_csr

# sign certificate
echo "Sign.."
kubectl certificate approve ${USER_NAME}_csr

# get ca certificate
export CERTIFICATE_AUTHORITY_DATA=$(kubectl config view --raw -o json | jq -r '.clusters[0].cluster."certificate-authority-data"' | tr -d '"')
# way 2:
# scp 10.7.6.188:/etc/kubernetes/pki/ca.crt
# export CERTIFICATE-AUTHORITY-DATA=$(cat ca.crt | base64 | tr -d '\n')

# get signed client certificate
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr ${USER_NAME}_csr -o jsonpath={.status.certificate})

# get client key
export CLIENT_KEY_DATA=$(cat ${USER_NAME}/${USER_NAME}.key | base64 | tr -d '\n')

echo "\n Generating user config..."
j2 templates/config.j2 > ${USER_NAME}/config

echo ".OK!"
