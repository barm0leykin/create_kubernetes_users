#!/bin/sh

# Prepare kubernetes config for new user
#
# USING:   ./prepare_user.sh $USER_NAME $USER_DEPARTAMENT
# EXAMPLE: ./prepare_user.sh geytsbills management

if [ -z "$1" ] || [ -z "$2" ]
then
    echo "Parameters needed!"
    echo "USING:   ./prepare_user.sh USER_NAME USER_DEPARTAMENT [KEY_PATH]"
    exit 1
fi

export $(grep -v '^#' cluster.env | xargs -d '\n')
export USER_NAME=$1
export USER_DEPARTAMENT=$2
export KEY_PATH=$3

mkdir -p ${USER_NAME}

# gen key
if [ -z "$3" ]
then
    echo "KEY_PATH not set. Generating user key for CURRENT user..."
    openssl genrsa -out ${USER_NAME}/${USER_NAME}.key 2048
    export KEY_PATH=${USER_NAME}/${USER_NAME}.key
fi
# gen csr config
echo "\nGenerating CSR..."
j2 templates/username_csr.cnf.j2 > ${USER_NAME}/${USER_NAME}_csr.cnf

# gen csr
# openssl req -new -key ${USER_NAME}/${USER_NAME}.key -subj "/CN=system:node:${USER_NAME} /OU="system:nodes" /O=system:nodes" -config ${USER_NAME}/${USER_NAME}_csr.cnf -out ${USER_NAME}/${USER_NAME}.csr
# openssl req -new -key ${KEY_PATH} -subj "/CN=system:node:${USER_NAME}/OU="system:nodes"/O=system:nodes" -config ${USER_NAME}/${USER_NAME}_csr.cnf -out ${USER_NAME}/${USER_NAME}.csr
# openssl req -new -key ${KEY_PATH} -subj "/CN=system:node:${USER_NAME}/OU=system:nodes/O=system:nodes" -config ${USER_NAME}/${USER_NAME}_csr.cnf -nodes -out ${USER_NAME}/${USER_NAME}.csr

openssl req -new -key ${KEY_PATH} -subj "/CN=${USER_NAME}" -config ${USER_NAME}/${USER_NAME}_csr.cnf -out ${USER_NAME}/${USER_NAME}.csr 


# convert csr to base64
export BASE64_CSR=$(cat ${USER_NAME}/${USER_NAME}.csr | base64 | tr -d '\n')

# create csr yaml manifest
j2 templates/username_csr.yaml.j2 > ${USER_NAME}/${USER_NAME}_csr.yaml

# apply csr yaml manifest to kubernetes
echo "\nApply csr yaml manifest to kubernetes..."
cat ${USER_NAME}/${USER_NAME}_csr.yaml | kubectl apply -f -

# show csr
echo "\nKubernetes CSR status: "
kubectl get csr | grep ${USER_NAME}_csr

# sign certificate
echo "Sign.."
kubectl certificate approve ${USER_NAME}_csr
echo "\nKubernetes CSR status: "
kubectl get csr | grep ${USER_NAME}_csr

# get ca certificate
export CERTIFICATE_AUTHORITY_DATA=$(kubectl config view --raw -o json | jq -r '.clusters[0].cluster."certificate-authority-data"' | tr -d '"')
# way 2:
# scp k8s-host:/etc/kubernetes/pki/ca.crt
# export CERTIFICATE-AUTHORITY-DATA=$(cat ca.crt | base64 | tr -d '\n')

# get signed client certificate
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr ${USER_NAME}_csr -o jsonpath={.status.certificate})

# get client key
export CLIENT_KEY_DATA=$(cat ${KEY_PATH} | base64 | tr -d '\n')

# show client cert
# echo $CLIENT_CERTIFICATE_DATA | base64 -d > tmp.crt
# openssl x509 -noout -text -in tmp.crt 

echo "\nGenerating user config..."
j2 templates/config.j2 > ${USER_NAME}/config

echo "OK!"
