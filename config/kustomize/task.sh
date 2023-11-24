#! /bin/bash
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
export service_group=$(echo $row | jq -r '.service_group');
export service_apigroup=$(echo $row | jq -r '.service_apigroup');
export service_kind=$(echo $row | jq -r '.service_kind');
export service_category=$(echo $row | jq -r '.service_category');
export service_link=$(echo $row | jq -r '.service_link');
export service_linkname=$(echo $row | jq -r '.service_linkname');
export service_linkdescription=$(echo $row | jq -r '.service_linkdescription');
export service_additional_label=$(echo $row | jq -r '.service_additional_label');
export service_cluster_instance_class=$(echo $row | jq -r '.service_cluster_instance_class');
export service_namespace=$(echo $ML_BACKSTAGE_TARGET_NAMESPACE || 'default');
}

###########################################################
# Generates object names
###########################################################
generate_ml_object_names()
{
export service_shortname=$(echo $service | cut -d'/' -f2);
export service_obj_prefix='bkstg';
export service_obj_name=${service_obj_prefix}-${service_category}-${service_shortname};
}

###########################################################
# Fetches services that will iterated through
# for potential labeling and use by the ML Backstage plugin
###########################################################
fetch_ml_services()
{
fetch_label="";
separator="";
if [ ! -z $service_apigroup ]; then
  if [ $service_apigroup == "secret" ] || [ ! -z $service_additional_label ]; then
    fetch_label="-l "
  fi
  if [ $service_apigroup == "secret" ]; then
    fetch_label="${fetch_label}backstage-dashboard-name=$service_shortname";
    separator=",";
  fi
  if [ ! -z $service_additional_label ]; then
    fetch_label="${fetch_label}${separator}${service_additional_label}"
  fi
  kubectl get $service_apigroup $fetch_label -o name -n $service_namespace;
fi
}

###########################################################
# Labels targeted ML service (database/API/dashboard/etc)
###########################################################
label_ml_service()
{
kubectl label $service backstage-dashboard-name=$service_shortname \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=service --overwrite -n $service_namespace;
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
  namespace: ${service_namespace}
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
tanzu service class-claim create ${service_obj_name} --class ${service_cluster_instance_class:-${service_obj_name}} \
--namespace $service_namespace;

# Labeling
kubectl label classclaim ${service_obj_name} backstage-dashboard-name=${service_shortname} \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=binding --overwrite -n $service_namespace;
}

###########################################################
# Creates the ConfigMap with supplemental info about the
# Service
###########################################################
create_ml_consolelink_data()
{
if [ ! -z ${service_link} ]
then
kubectl create configmap ${service_obj_prefix}-${service_category}-${service_linkname} -n $service_namespace \
--from-literal=link=${service_link} --from-literal=link_description="${service_linkdescription}" -oyaml --dry-run=client | kubectl apply -f -;
kubectl label configmap ${service_obj_prefix}-${service_category}-${service_linkname} backstage-dashboard-name=${service_linkname} \
backstage-dashboard-category=${service_category} \
backstage-dashboard-type=console --overwrite -n $service_namespace;
fi
}

add_servicebinding_to_jupyterhub()
{
for jupyter in `kubectl get deployment -l backstage-dashboard-category=servicebinding -o name -n $service_namespace`; do
export jupyter_shortname=$(echo $jupyter | cut -d'/' -f2);
cat <<EOF | kubectl apply -n $service_namespace -f -
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
parse_yaml_file_to_json | while read -r row ; do
  initialize_ml_category_properties;
  echo -e "\n\n\nCreating and labeling ConfigMap for ${service_obj_prefix}-${service_category}-${service_linkname} console link (if it exists)...";
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