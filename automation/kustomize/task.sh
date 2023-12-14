#!/bin/bash
###########################################################
# Fetches all namespaces on the cluster
###########################################################
get_namespaces()
{
# TODO: Retrieve names via an appropriate label or annotation
# kubectl get ns -oname | cut -d'/' -f2
echo "default"
}

###########################################################
# Generates JSON output from YAML file
###########################################################
parse_yaml_file_to_json()
{
yq -p yaml -o json "${ML_PROPERTIES_FILE}" | jq -c '.properties | .[]'
}

###########################################################
# Sets properties for each ML category
###########################################################
initialize_ml_category_properties()
{
export service_cluster_instance_group=$(echo $row | jq -r '.service_cluster_instance_group');
export service_query_group=$(echo $row | jq -r '.service_query_group');
export service_cluster_instance_kind=$(echo $row | jq -r '.service_cluster_instance_kind');
export service_category=$(echo $row | jq -r '.service_category');
export service_link=$(echo $row | jq -r '.service_link');
export service_linkname=$(echo $row | jq -r '.service_linkname');
export service_linkdescription=$(echo $row | jq -r '.service_linkdescription');
export service_query_additional_label=$(echo $row | jq -r '.service_query_additional_label');
export service_cluster_instance_class=$(echo $row | jq -r '.service_cluster_instance_class');
export service_obj_prefix='bkstg';
}

###########################################################
# Generates object names
###########################################################
generate_ml_object_names()
{
export service_shortname=$(echo $service | cut -d'/' -f2);
export service_obj_name=${service_obj_prefix}-${service_namespace}-${service_shortname};
}

###########################################################
# Fetches services that will iterated through
# for potential labeling and use by the ML Backstage plugin
###########################################################
fetch_ml_services()
{
fetch_label="";
separator="";
export service_shortname=$(echo $service | cut -d'/' -f2);
if [ ! -z $service_query_group ]; then
  if [ "$service_query_group" = "secret" ] || [ ! -z $service_query_additional_label ]; then
    fetch_label="-l ";
  fi
  if [ "$service_query_group" = "secret" ] && [ ! -z $service_query_additional_label ]; then
    separator=",";
  fi
  if [ "$service_query_group" = "secret" ]; then
    fetch_label="${fetch_label}backstage-dashboard-name=${service_shortname}";
  fi
  if [ ! -z $service_query_additional_label ]; then
    fetch_label="${fetch_label}${separator}${service_query_additional_label}";
  fi
  kubectl get $service_query_group $fetch_label -o name -n $service_namespace;
fi
}

###########################################################
# Labels targeted ML service (database/API/dashboard/etc)
###########################################################
label_ml_service()
{
kubectl label $service backstage-dashboard-name=$service_shortname \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=service --overwrite \
-n $service_namespace;
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
cat <<EOF | kubectl apply -n $service_namespace -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: ${service_obj_name}
spec:
  description:
    short: Cluster Class for ${service_category} ${service_shortname}
  pool:
    group: ${service_cluster_instance_group}
    kind: ${service_cluster_instance_kind}
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
tanzu service class-claim create ${service_obj_name} --class ${service_cluster_instance_class:-${service_obj_name}};

# Labeling
kubectl label classclaim ${service_obj_name} backstage-dashboard-name=${service_shortname} \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=binding --overwrite \
-n $service_namespace;
}

###########################################################
# Creates the ConfigMap with supplemental info about the
# Service
###########################################################
create_ml_consolelink_data()
{
if [ ! -z ${service_link} ]
then
kubectl create configmap ${service_obj_prefix}-${service_namespace}-${service_linkname} \
--from-literal=link=${service_link} --from-literal=link_description="${service_linkdescription}" -oyaml --dry-run=client | kubectl apply -n $service_namespace -f -;
kubectl label configmap ${service_obj_prefix}-${service_namespace}-${service_linkname} backstage-dashboard-name=${service_linkname} \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=console --overwrite \
-n $service_namespace;
fi
}

add_servicebinding_to_jupyterhub()
{
for jupyter in `kubectl get deploy -l backstage-dashboard-category=servicebinding -o name -n $service_namespace`; do
export jupyter_shortname=$(echo $jupyter | cut -d'/' -f2);
cat <<EOF | kubectl create -n $service_namespace -f -
apiVersion: servicebinding.io/v1beta1
kind: ServiceBinding
metadata:
  name: ${service_obj_name}-jupyter-binding
spec:
  service:
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ClassClaim
    name: ${service_obj_name}
  workload:
    apiVersion: apps/v1
    kind: Deployment
    name: $jupyter_shortname
EOF
done;
}

###########################################################
# Main Driver
###########################################################
for service_namespace in `get_namespaces || []`; do
  echo -e "\n\n\n========================\nNamespace: $service_namespace\n========================\n\n\n";
  parse_yaml_file_to_json | while read -r row ; do
    initialize_ml_category_properties;
    echo -e "\n\n\nCreating and labeling ConfigMap for ${service_obj_prefix}-${service_namespace}-${service_linkname} console link (if it exists)...";
    create_ml_consolelink_data;
    for service in `fetch_ml_services || []`; do
      echo -e "\n"$service".....................................";
      generate_ml_object_names;

      echo -e "\nLabeling service $service_shortname...";
      label_ml_service;

      echo -e "\nCreating ${service_obj_name} ClusterInstanceClass (if applicable)...";
      create_ml_clusterinstanceclass;

      echo -e "\nCreating and labeling ${service_obj_name} ClassClaim...";
      create_ml_classclaim;

      echo -e "\nAdding ClassClaim ${service_obj_name} to Jupyter server's service bindings ...";
      add_servicebinding_to_jupyterhub;
    done;
  done;
done;