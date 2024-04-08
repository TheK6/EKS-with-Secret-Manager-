#!/bin/sh

if [ "$1" != "" ]; then
  output=$(aws secretsmanager get-secret-value --secret-id "$1")

  secretString=$(echo "$output" | jq -r '.SecretString')

  echo "  secretObjects:" > secret.yaml
  echo "  - secretName: $1" >> secret.yaml
  echo "    type: Opaque" >> secret.yaml
  echo "    data:" >> secret.yaml

  echo "        env:" > deployment.yaml

  IFS=','
  for secret in $secretString; do 
    key=$(echo $secret | awk -F':' '{print $1}' | tr -d ' " {}')
   
    echo $key 
    echo "      - objectName: $key" >> secret.yaml 
    echo "        key: $key" >> secret.yaml

  done 
  
  echo "  parameters:" >> secret.yaml
  echo "    objects: |" >> secret.yaml
  
  echo "      - objectName: '$1'" >> secret.yaml
  echo "        objectType: 'secretsmanager'" >> secret.yaml
  echo "        jmesPath:" >> secret.yaml 

  IFS=','
  for secret in $secretString; do 
    key=$(echo $secret | awk -F':' '{print $1}' | tr -d ' " {}') 

    echo "          - path: '$key'" >> secret.yaml
    echo "            objectAlias: '$key'" >> secret.yaml

    echo "        - name: $key" >> deployment.yaml
    echo "          valueFrom:" >> deployment.yaml
    echo "            secretKeyRef:" >> deployment.yaml
    echo "              name: $1" >> deployment.yaml 
    echo "              key: $key" >> deployment.yaml

  done

else
  echo "Please provide the secret manager name"
fi 
