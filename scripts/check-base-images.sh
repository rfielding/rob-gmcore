#!/bin/bash


# image_block=$(cue eval -c inputs.cue --out json | jq '.mesh.spec.images')
images_block=$(cue eval inputs.cue --out json | jq ".mesh.spec.images")

for i in $(echo ${images_block} | jq -r '. | keys[]'); do
    # echo ${i}
    image=$(echo ${images_block} | jq '.' | jq -r --arg comp ${i} '.[$comp]' )
    repo=$(echo ${image} | awk -F/ '{print $1}')
    # echo $repo
    
    if [[ $repo == "greymatter.jfrog.io" ]]; then
        echo $image
        docker pull -q $image
        docker inspect $image | jq '"\(.[].Config.Labels."org.opencontainers.image.title"):\(.[].Config.Labels."org.opencontainers.image.version")"'
    fi
done


images_block=$(cue eval inputs.cue --out json | jq ".defaults.images")

for i in $(echo ${images_block} | jq -r '. | keys[]'); do
    # echo ${i}
    image=$(echo ${images_block} | jq '.' | jq -r --arg comp ${i} '.[$comp]' )
    repo=$(echo ${image} | awk -F/ '{print $1}')
    # echo $repo
    
    if [[ $repo == "greymatter.jfrog.io" ]]; then
        echo $image
        docker pull -q $image
        docker inspect $image | jq '"\(.[].Config.Labels."org.opencontainers.image.title"):\(.[].Config.Labels."org.opencontainers.image.version")"'
    fi
done