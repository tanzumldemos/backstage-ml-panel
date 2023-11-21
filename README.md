# Backstage Components for TAP ML Panel

## Deploy Service Binding Automation

1. Replace YOUR_IMAGE_REPO in the file <root of directory>/image_repo 
with the name of your target image repo for the automation job (example: myregistry/automationimg).

2. Copy the automation job's image to your local image registry:
```
imgpkg copy -i oawofolu/tanzu-cli-essentials --to-repo YOUR_IMAGE_REPO
```

OR - you can build the image locally:
```
docker build -t YOUR_IMAGE_REPO config/other
docker push YOUR_IMAGE_REPO
```

3. 
