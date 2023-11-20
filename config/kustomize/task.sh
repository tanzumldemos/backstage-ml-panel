
###########################################################
# Sets properties for each ML category
###########################################################
fetch_ml_category_properties()
{
#  export service_group=sql.tanzu.vmware.com;
#  export service_apigroup=postgres.sql.tanzu.vmware.com;
#  export service_kind=Postgres;
#  export service_category=postgres;
#  export service_link="";
#  export service_linkname=""
#  export service_additional_label=""
#  export service_cluster_instance_class=""

#  export service_group="";
#  export service_apigroup="secret";
#  export service_kind=Secret;
#  export service_category=greenplum;
#  export service_link="ec2-44-201-91-88.compute-1.amazonaws.com:28080";
#  export service_linkname="greenplum-training"
#  export service_additional_label=""
#  export service_cluster_instance_class=""

  export service_group=""
  export service_apigroup="statefulset"
  export service_kind="StatefulSet"
  export service_category="postgres"
  export service_link=""
  export service_linkname=""
  export service_additional_label="app.kubernetes.io/name=postgresql,app.kubernetes.io/managed-by=Helm"
  export service_cluster_instance_class="postgresql-unmanaged"
}

###########################################################
# Fetches services that will iterated through
# for potential labeling and use by the ML Backstage plugin
###########################################################
fetch_ml_services()
{
  fetch_labels="";
  separator="";
  if [ $service_apigroup == "secret" ] || [ ! -z $service_additional_label ]; then
    fetch_label="-l "
  fi
  if [ $service_apigroup == "secret" ]; then
    fetch_label="${fetch_label}backstage-dashboard-name=$service_linkname";
    separator=",";
  fi
  if [ ! -z $service_additional_label ]; then
    fetch_label="${fetch_label}${separator}${service_additional_label}"
  fi
  kubectl get $service_apigroup $fetch_label -o name;
}

###########################################################
# Labels targeted ML service (database/API/dashboard/etc)
###########################################################
label_ml_service()
{
kubectl label $service backstage-dashboard-name=$service_shortname \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=service --overwrite;
}

###########################################################
# Creates the ClusterInstanceClasses that will be
# referenced by the ClassClaims used for Service binding
# (if necessary; for instance
# Bitnami services do not need new classes)
###########################################################
create_ml_clusterinstanceclass()
{
if [ -z $service_cluster_instance_class ]
then
cat <<EOF | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: ${service_category}-${service_shortname}
spec:
  description:
    short: Cluster Class for ${service_category} ${service_shortname}
  pool:
    group: ${service_group}
    kind: ${service_kind}
    labelSelector:
      matchLabels:
        backstage-dashboard-name: $service_shortname
EOF
fi
}

###########################################################
# Creates the ClassClaims used for Service binding
###########################################################
create_ml_classclaim()
{
# Creating
tanzu service class-claim create ${service_category}-${service_shortname} --class ${service_cluster_instance_class:-${service_category}-${service_shortname}};

# Labeling
kubectl label classclaim ${service_category}-${service_shortname} backstage-dashboard-name=${service_shortname} \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=binding --overwrite;
}

create_ml_consolelink_data()
{
if [ ! -z ${service_link} ]
then
kubectl delete configmap ${service_category}-${service_linkname} || true;
kubectl create configmap ${service_category}-${service_linkname} --from-literal=link=${service_link};
kubectl label configmap ${service_category}-${service_linkname} backstage-dashboard-name=${service_linkname} \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=console --overwrite;
fi
}

# for ml_namespace in `kubectl get ns`; do
  fetch_ml_category_properties;
  echo -e "\nCreating and labeling ConfigMap for ${service_category}-${service_linkname} console link (if it exists)...";
  create_ml_consolelink_data;
  for service in `fetch_ml_services`; do
    echo -e "\n\n\n"$service".....................................";
    export service_shortname=$(echo $service | cut -d'/' -f2);

    echo -e "\nLabeling service $service_shortname...";
    label_ml_service;

    echo -e "\nCreating ${service_category}-${service_shortname} ClusterInstanceClass (if applicable)...";
    create_ml_clusterinstanceclass;

    echo -e "\nCreating and labeling ${service_category}-${service_shortname} ClassClaim...";
    create_ml_classclaim;
  done;
# done;