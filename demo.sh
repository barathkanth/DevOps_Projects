#!/bin/bash

# Demo script to deploy and test

echo "Initializing Terraform..."
cd infra
terraform init

echo "Applying infrastructure..."
terraform apply -auto-approve

echo "Building Lambda..."
cd ../src/lambdas/order_processor
mkdir -p build
pip install -r requirements.txt -t build/
cp handler.py build/
cd build && zip -r ../order_processor.zip .

# Assume Terraform handles the zip, or upload to S3


echo "Sending test event..."
cd ../../../producer
npm install
node send_order.js

echo "Demo complete. Check AWS console for results."
