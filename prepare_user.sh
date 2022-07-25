#!/bin/sh -e

# Prepare kubernetes config for new user
#
# USING:   ./prepare_user.sh $USER_NAME $USER_DEPARTAMENT [$KEY_PATH]
# EXAMPLE: ./prepare_user.sh geytsbills management

if [ -z "$1" ] || [ -z "$2" ]
then
    echo "Parameters needed!"
    echo "USING:   ./prepare_user.sh USER_NAME USER_DEPARTAMENT [CLUSTER_ENV_FILE] [KEY_PATH]"
    exit 1
fi

export USER_NAME=$1
export USER_DEPARTAMENT=$2
# export CLUSTER_NAME=$3
export KEY_PATH=$4

if [ -z "$3" ]
then
    export $( grep -v '^#' cluster.env | xargs -d '\n' )
else
    export $(grep -v '^#' $3 | xargs -d '\n')
fi
echo CLUSTER_NAME: $CLUSTER_NAME

export USER_DIR="${CLUSTER_NAME}/${USER_NAME}"

mkdir -p "${USER_DIR}"

# gen key
if [ -z "$4" ]
then
    echo "KEY_PATH not set. Generating new user key..."
    openssl genrsa -out "${USER_DIR}/${USER_NAME}".key 2048
    export KEY_PATH="${USER_DIR}/${USER_NAME}.key"
fi
# gen csr config
echo "\nGenerating CSR..."
j2 templates/username_csr.cnf.j2 > "${USER_DIR}/${USER_NAME}_csr.cnf"

# gen csr
openssl req -new -key ${KEY_PATH} -subj "/CN=${USER_NAME}/OU=${USER_DEPARTAMENT}" -config ${USER_DIR}/${USER_NAME}_csr.cnf -out ${USER_DIR}/${USER_NAME}.csr 

# convert csr to base64
export BASE64_CSR=$(cat ${USER_DIR}/${USER_NAME}.csr | base64 | tr -d '\n')

# create csr yaml manifest
j2 templates/username_csr.yaml.j2 > "${USER_DIR}/${USER_NAME}_csr.yaml"

# apply csr yaml manifest to kubernetes
echo "\nApply csr yaml manifest to kubernetes..."
cat "${USER_DIR}/${USER_NAME}_csr.yaml" | kubectl apply -f -

# show csr
echo "\nKubernetes CSR status: "
kubectl get csr | grep "${USER_NAME}_csr"

# signing certificate
echo "\nSigning.."
kubectl certificate approve "${USER_NAME}_csr"

echo "\nKubernetes CSR status: "
kubectl get csr | grep "${USER_NAME}_csr"

# get ca certificate
echo "get ca certificate.."
export CERTIFICATE_AUTHORITY_DATA=$(kubectl config view --raw -o json | jq -r '.clusters[0].cluster."certificate-authority-data"' | tr -d '"')
# way 2:
# scp k8s-host:/etc/kubernetes/pki/ca.crt
# export CERTIFICATE-AUTHORITY-DATA=$(cat ca.crt | base64 | tr -d '\n')

# get signed client certificate
echo "get signed client certificate.."
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr ${USER_NAME}_csr -o jsonpath={.status.certificate})

# get client key
echo "get client key.."
export CLIENT_KEY_DATA=$(cat ${KEY_PATH} | base64 | tr -d '\n')

# show client cert
# echo $CLIENT_CERTIFICATE_DATA | base64 -d > ${USER_NAME}/${USER_NAME}.crt
# openssl x509 -noout -text -in ${USER_NAME}/${USER_NAME}.crt

echo "\nGenerating user config..."
j2 templates/config.j2 > "${USER_DIR}/config"

# create personal namespace
j2 templates/personal_namespace.yaml.j2 > "${USER_DIR}/personal_namespace.yaml"
kubectl apply -f ${USER_DIR}/personal_namespace.yaml

# bind default roles
echo "\nBind view roles..."
j2 templates/bind_default_roles.yaml.j2 > "${USER_DIR}/bind_default_roles.yaml"
kubectl apply -f ${USER_DIR}/bind_default_roles.yaml

echo "\nComplete! User config file: ${USER_DIR}/config"
