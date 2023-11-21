# Backstage Components for TAP ML Panel

## Deploy Service Binding Automation

1. Replace YOUR_IMAGE_REPO in the file <root of directory>/image_repo 
with the name of your target image repo for the automation job (example: myregistry/automationimg).

2. Replace YOUR_BACKSTAGE_NAMESPACE in the file <root of directory>/backstage_namespace
with the name of your target image repo for the automation job.

3. Copy the automation job's image to your local image registry:
```
imgpkg copy -i oawofolu/tanzu-cli-essentials --to-repo YOUR_IMAGE_REPO
```

OR - you can build the image locally:
```
docker build -t YOUR_IMAGE_REPO config/other
docker push YOUR_IMAGE_REPO
```

3. Label the JupyterHub server that will be used as the central point for service bindings:
```
kubectl label deployment YOUR_JUPYTER_DEPLOYMENT backstage-dashboard-category=servicebinding -n YOUR_BACKSTAGE_NAMESPACE
```
