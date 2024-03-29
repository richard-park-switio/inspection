#!/bin/bash

LIST="
debian-cloud,debian-10
debian-cloud,debian-11
debian-cloud,debian-12
rocky-linux-cloud,rocky-linux-8
rocky-linux-cloud,rocky-linux-8-optimized-gcp
rocky-linux-cloud,rocky-linux-9
rocky-linux-cloud,rocky-linux-9-optimized-gcp
ubuntu-os-cloud,ubuntu-2004-lts
ubuntu-os-cloud,ubuntu-2204-lts
"

for ITEM in $LIST ; do
  IMAGE_PROJECT=$(echo "$ITEM" | cut -f 1 -d ',')
  IMAGE_FAMILY=$(echo "$ITEM" | cut -f 2 -d ',')
  gcloud compute instances create "richard-$IMAGE_FAMILY" \
    --project=swit-alpha --zone=us-west1-c --machine-type=e2-highcpu-2 \
    --network-interface=stack-type=IPV4_ONLY,subnet=default,no-address \
    --maintenance-policy=MIGRATE --provisioning-model=STANDARD \
    --service-account=instance@swit-alpha.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --image-project="$IMAGE_PROJECT" --image-family="$IMAGE_FAMILY" \
    --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring \
    --labels=user=richard &
done
wait
