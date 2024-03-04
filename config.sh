PROJ=demo
GIT_PROJ=infra
GIT_ADMIN=demo
GIT_PASSWORD=password
GIT_REPO=coolstore

AWS_SECRET_NAME=aws
CLUSTERSET_NAME=coolstore
CLUSTER_NAMES=(coolstore-a coolstore-b coolstore-c)
CLUSTER_REGIONS=(ap-southeast-1 ap-southeast-2 ap-northeast-1)
CLUSTER_NETWORKS=(10.128.0.0/14 10.132.0.0/14 10.136.0.0/14)
SERVICE_NETWORKS=(172.30.0.0/16 172.31.0.0/16 172.32.0.0/16)
CLUSTERIMAGESET=img4.15.0-multi-appsub
CONTROL_PLANE_TYPE=m5.xlarge
COMPUTE_TYPE=m5.xlarge
COMPUTE_COUNT=4         # At least 4 are needed for F5 ingres to run

INSTALLER_IMAGE=ghcr.io/rhsgsa/hybrid-cloud-installer
REMOTE_INSTALL_PROJ=infra

# variables required for the ArgoCD Sync Handler
ARGO_ACCOUNT=robot
TOKEN_ID=sync-token
TOKEN_FILE=/tmp/token.txt
ARGO_APP=coolstore
HANDLER_PROJ=infra
