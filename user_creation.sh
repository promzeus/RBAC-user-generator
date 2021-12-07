#!/bin/bash
###
# bash ./user_creation.sh -u user -d 3600
### next use rbac-manager
# https://rbac-manager.docs.fairwinds.com/introduction/#an-example
###
#To take from the admin-cluster config (to modify)
certificate_data_dev="LS0tLStLQ345HBkRy9CVVJNaz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLSo="
server_dev="https://172.30.30.1:6443"
cluster_name_dev="dev"
certificate_data_prod="LS0tLS1HBkRy9CVVJNaz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
server_prod="https://172.30.31.1:6443"
cluster_name_prod="prod"

#The default path for Kubernetes CA
ca_path_dev="./pki/dev"
ca_path_prod="./pki/prod"

create_user() {
    
    mkdir -p $user_home_dev 
    mkdir -p $user_home_prod
    #Create private Key for the user
    printf "Private Key creation\n"
    openssl genrsa -out $filename_dev.key 2048
    openssl genrsa -out $filename_prod.key 2048
    #Create the CSR
    printf "\nCSR Creation\n"
    openssl req -new -key $filename_dev.key -out $filename_dev.csr -subj "/CN=$user"
    openssl req -new -key $filename_prod.key -out $filename_prod.csr -subj "/CN=$user"
    #Sign the CSR
    printf "\nCertificate Creation\n"
    openssl x509 -req -in $filename_dev.csr -CA $ca_path_dev/ca.crt -CAkey $ca_path_dev/ca.key -CAcreateserial -out $filename_dev.crt -days $days
    openssl x509 -req -in $filename_prod.csr -CA $ca_path_prod/ca.crt -CAkey $ca_path_prod/ca.key -CAcreateserial -out $filename_prod.crt -days $days
    #Create the .certs and mv the cert file in it
    printf "\nCreate .certs directory and move the certificates in it\n"
    mkdir $user_home_dev/.certs && mv $filename_dev.* $user_home_dev/.certs
    mkdir $user_home_prod/.certs && mv $filename_prod.* $user_home_prod/.certs
    
    #base64 data cert. Use macos gbase64 -w0 & linux base64 -w0
    CERT_DATA_DEV=$(cat $user_home_dev/.certs/$user.crt |gbase64 -w0)
    KEY_DATA_DEV=$(cat $user_home_dev/.certs/$user.key |gbase64 -w0)
    CERT_DATA_PROD=$(cat $user_home_prod/.certs/$user.crt |gbase64 -w0)
    KEY_DATA_PROD=$(cat $user_home_prod/.certs/$user.key |gbase64 -w0)
    
    #Edit the config file
    printf "\nConfig file edition\n"
    mkdir $user_home/.kube
    cat <<-EOF > $user_home/.kube/config
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: $certificate_data_dev
        server: $server_dev
      name: $cluster_name_dev
    - cluster:
        certificate-authority-data: $certificate_data_prod
        server: $server_prod
      name: $cluster_name_prod
    contexts:
    - context:
        cluster: $cluster_name_dev
        namespace: $cluster_name_dev
        user: $cluster_name_dev-$user
      name: $cluster_name_dev
    - context:
        cluster: $cluster_name_prod
        namespace: $cluster_name_prod
        user: $cluster_name_prod-$user
      name: $cluster_name_prod
    current-context: $cluster_name_dev
    kind: Config
    preferences: {}
    users:
    - name: $cluster_name_dev-$user
      user:
        client-certificate-data: $CERT_DATA_DEV
        client-key-data: $KEY_DATA_DEV
    - name: $cluster_name_prod-$user
      user:
        client-certificate-data: $CERT_DATA_PROD
        client-key-data: $KEY_DATA_PROD
EOF

}


usage() { printf "Usage: \n   Mandatory: User. \n   Optionals: Days (360 by default) and Group. \n   [-u user] [-d days]\n" 1>&2; exit 1; }

while getopts ":u:d:" o; do
    case "${o}" in
        u)
            user=${OPTARG}
            ;;
        d)
            days=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

#User is mandatory
if [ -z "${user}" ] ; then
    usage
fi

#VDefault Value for $days
if [ -z "${days}" ] ; then
	days=360
fi

#Set up variables
user_home="./users/$user"
user_home_dev="./users/$user/$cluster_name_dev"
filename_dev=$user_home_dev/$user
user_home_prod="./users/$user/$cluster_name_prod"
filename_prod=$user_home_prod/$user
#Execute the function
create_user
