#!/usr/bin/env bash

terraform init

for i in {1..3}
do
  terraform apply -state ./tfstate -auto-approve
  if [ $? -eq 0 ]; then
    echo ">>> Done!"
    break
  fi
  echo ">>> Repeat $i"
done