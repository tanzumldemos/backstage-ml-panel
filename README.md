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

3. Add the images referenced by **yaml/static/tools.yaml** to the **images** folder.

## Deploy Service Binding Automation

1. Replace YOUR_IMAGE_REPO in the file <root of directory>/image_repo 
with the name of your **target image repo** for the automation job (example: myregistry/automationimg).

2. Replace YOUR_BACKSTAGE_NAMESPACE in the file <root of directory>/backstage_namespace
with the **target Kubernetes namespace** for the automation job.

3. Copy the automation job's image to your local image registry:
```
imgpkg copy -i oawofolu/tanzu-cli-essentials --to-repo YOUR_IMAGE_REPO
```

OR you can build the image locally:
```
docker build -t YOUR_IMAGE_REPO automation/other
docker push YOUR_IMAGE_REPO
```

3. Label the IDE tools that will be used as the central point for service bindings - JupyterHub deployments, database IDEs (ex. pgadmin), etc:
```
kubectl label deployment YOUR_JUPYTER_DEPLOYMENT backstage-dashboard-category=servicebinding -n YOUR_BACKSTAGE_NAMESPACE
```

4. Set up **Direct Secrets** for **non-Service Binding compatible** service instances (external services, non-database deployments, etc)
that you want to set up for connectivity via Service Bindings - use **automation/other/directsecret.yaml** as a template.

**NOTE**: You must set up a Kubernetes secret for the service instance as a pre-requisite. 
Currently, the secret must live in YOUR_BACKSTAGE_NAMESPACE.

5. Set up the automation job:
```
cp yaml/automation/data.yaml automation/kustomize
kubectl apply -k automation/kustomize
```
