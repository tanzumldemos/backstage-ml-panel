# Backstage Components for TAP ML Panel
--------------------------
![](mlbackstage-automation.jpg?raw=true)
## Store metadata dependencies in GitHub

1. Update **yaml/static/tools.yaml** as appropriate.
   This will be the source metadata file used to render the **static** portion of the plugin's GUI
   (i.e. **generic** tool information - tool category, description, image, etc).

2. Update **yaml/automation/data.yaml** as appropriate.
   This will be the source metadata file used to render the **dynamic** portion of the plugin's GUI which will come from the environment
   (i.e. **instances** of the tools - helm instances, Kubernetes deployments, etc).

3. Add the images referenced by **yaml/static/tools.yaml** to the **images/public** folder.

## Deploy Service Binding Automation

1. Replace YOUR_IMAGE_REPO in the file <root of directory>/image_repo
   with the name of your **target image repo** for the automation job (example: myregistry/automationimg).

2. Copy the automation job's image to your local image registry:
```
imgpkg copy -i oawofolu/tanzu-cli-essentials --to-repo YOUR_IMAGE_REPO
```

OR you can build the image locally:
```
docker build -t YOUR_IMAGE_REPO automation/other
docker push YOUR_IMAGE_REPO
```

3. Set up the **ServiceAccount** that will be used for the automation:
```
kubectl apply -f automation/other/serviceaccount.yaml
```

4. Set up **Direct Secrets** for any **non-Service Binding compatible** service instances (external services, non-database deployments, etc)
   that you want to set up for connectivity via Service Bindings - use **automation/other/directsecret.yaml** as a template.

**NOTE**: You must set up a Kubernetes secret for the service instance as a pre-requisite.

If you need more guidance on this, see the section entitled **Deploy Custom Service Bindings** (below).

5. Set up the automation job:
```
cp yaml/automation/data.yaml automation/kustomize
kubectl apply -k automation/kustomize
```

### Deploy Custom Service Bindings
Custom Service Bindings are based on services that do not have out-of-the-box integration with Service Bindings on the Tanzu platform.
They are configured based on the Service Binding's <a href="https://redhat-developer.github.io/service-binding-operator/userguide/exposing-binding-data/direct-secret-reference.html" target="_blank">Direct Secret</a> spec.

1. Make a copy of **automation/other/values_template.yaml** called **automation/other/values.yaml**, and update it with the following values:
   * YOUR_SECRET_NAME : The name of the secret that will encapsulate the credentials for your custom service
   * YOUR_SECRET_SOURCE_NAMESPACE: The namespace of the secret that will encapsulate the credentials for your custom service
   * YOUR_SECRET_TARGET_NAMESPACE: The namespace that the secret will be copied to for the Backstage Automation to access (could be the same as the source namespace)
   * YOUR_TOOL_CATEGORY: Shortname of the service that will be deployed (ex. greenplum, spark, etc)
   * YOUR_SERVICE_NAME: Shortname of the specific instance of the service (ex. greenplum-dev, spark-prod, etc)
   * YOUR_CLUSTER_CLASS_DESCRIPTION: Description of the service (ex. Dev Instance for Greenplum)

2. (If the secret exists in a separate namespace) Import the secret:
```
ytt -f automation/other/values.yaml -f automation/other/customsvcsecretimport.yaml | kubectl apply -n YOUR_SECRET_SOURCE_NAMESPACE -f -
```

3. (If the secret does not already exist) Add updates to these fields in the **automation/other/values.yaml** file above:
   * YOUR_SECRET_DATABASE_VALUE: The "database" associated with your custom service credential (or "" if no database value exists)
   * YOUR_SECRET_USERNAME_VALUE: The "username" associated with your custom service credential (or "" if no username value exists)
   * YOUR_SECRET_PASSWORD_VALUE: The "password" associated with your custom service credential (or "" if no password value exists)
   * YOUR_SECRET_HOST_VALUE: The "host" associated with your custom service credential (or "" if no host value exists)
   * YOUR_SECRET_PORT_VALUE: The "port" associated with your custom service credential (or "" if no port value exists)
   * YOUR_SECRET_TYPE_VALUE: The "type" associated with your custom service credential (or "" if no type value exists)
   * YOUR_SECRET_SCHEMA_VALUE: The "schema" associated with your custom service credential (or "" if no schema value exists)
   * YOUR_SECRET_URL_VALUE: The "url" associated with your custom service credential (or "" if no url value exists)
   
4. (If the secret does not already exist) Generate the secret (replace the placeholders below with the values provided in Step 1):
```
ytt -f automation/other/values.yaml -f automation/other/customsvcsecret.yaml | kubectl apply -n YOUR_SECRET_SOURCE_NAMESPACE -f -
```

5. Generate the ClassClaims that will be used by automation job to create the ServiceBinding (replace the placeholders below with the values provided in Step 1):
```
ytt -f automation/other/values.yaml -f automation/other/customsvcbinding.yaml | kapp deploy -a bkstg-YOUR_SERVICE_NAME -n YOUR_SECRET_SOURCE_NAMESPACE -y -f -
```

6. Ensure that the automation job is running (under **Deploy Service Binding Automation**):
```

```

A new service binding should be generated for the custom service momentarily.