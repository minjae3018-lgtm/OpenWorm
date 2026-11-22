#!/bin/bash

version=$(<VERSION) # Read version of Dockerfile from file VERSION
container_name="openworm_${version}_local"

docker stop "$container_name" 2>/dev/null || true
docker rm "$container_name"
