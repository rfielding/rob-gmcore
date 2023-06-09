# check_volume
# takes in <is_present | is_not_present> 
# cue_eval $2 is the output of a cue eval on this repo (assumes you are evaluating a target like k8s_manifests)
# resource_name is the name of the stateful set or deployment you want to asses
# volume_name is the name of the voulume
# return 0 for true accusation 1 for false accusation
_check_volume(){
  is_present=$1
  cue_eval=$2
  resource_name=$3
  volume_name=$4

  # will be 0 if exists
  # echo "Checking that volume [${volume_name}] ${is_present} in ${resource_name} deploy/sts"
  _check_volume_exists "${cue_eval}" ${resource_name} ${volume_name}
  result=$?
  # echo "check_volume result: $result"
  if [[ "${is_present}" == "is_present" ]];then
    if [[ ${result} -eq 0 ]]; then
      echo "    --Volume [${volume_name}] is present and should be in ${resource_name} deploy/sts"
      return 0
    else
      echo "    --ERROR: Volume [${volume_name}] is NOT PRESENT and should be in ${resource_name} deploy/sts"
    fi
  else
    # if we are checking that the value is not present and the function says it is not there (1)
    if [[ $result -ne 0 ]]; then
      echo "    --Volume [${volume_name}] is not present and should not be in ${resource_name} deploy/sts"
      return 0
    fi
    echo "    --ERROR: Volume [${volume_name}] IS PRESENT BUT SHOULD NOT BE in ${resource_name} deploy/sts"
  fi
  echo "    --ERROR: Volume [${volume_name}] IS NOT PRESENT BUT SHOULD BE in ${resource_name} deploy/sts"
  return 500
}

# cue_eval $1 is the output of a cue eval on this repo (assumes you are evaluating a target like k8s_manifests)
# resource_name is the name of the stateful set or deployment you want to asses
# volume_name is the name of the vulume
# return 0 for present
# return 1 for not present
_check_volume_exists(){
  cue_eval=$1
  resource_name=$2
  volume_name=$3

  # echo "Checking ${resource_name} for ${volume_name} volume"

  local problem=0
  local resource_json=$(echo ${cue_eval} | jq -r --arg NAME ${resource_name} '.[] | select((.kind=="StatefulSet") or (.kind=="Deployment")) | select(.metadata.name==$NAME)')
  local check_volume=$(echo ${resource_json} | jq -r --arg VOLUME_NAME ${volume_name} '.spec.template.spec.volumes[] | select(.name==$VOLUME_NAME) | .name' )
  if [[ ! "${check_volume}" == ${volume_name} ]]; then
    # echo -e "    ${volume_name} volume not found in ${resource_name} deploy/sts\n"
    problem=1
  fi
  return ${problem}
}


_check_volume_mount(){
  is_present=$1
  cue_eval=$2
  resource_name=$3
  container=$4
  volume_name=$5

    # echo "Checking that volume mount [${volume_name}] ${is_present} in ${container} container in the ${resource_name} deploy/sts"
  _check_volume_mount_exists "${cue_eval}" ${resource_name} ${container} ${volume_name}
  result=$?
  if [[ "${is_present}" == "is_present" ]];then
    if [[ ${result} -eq 0 ]]; then
      echo "    --Volume mount [${volume_name}] is present and should be in the ${container} container in the ${resource_name} deploy/sts"
      return 0
    else
      echo "    --ERROR: Volume mount [${volume_name}] IS NOT PRESENT and should be in the ${container} container in the ${resource_name} deploy/sts"
    fi
  else
    # if we are checking that the value is not present and the function says it is not there (1)
    if [[ $result -ne 0 ]]; then
      echo "    --Volume mount [${volume_name}] is not present and should not be in the ${container} container in the ${resource_name} deploy/sts"
      return 0
    fi
    echo "    --ERROR: Volume mount [${volume_name}] IS PRESENT BUT SHOULD NOT BE in the ${container} container in the ${resource_name} deploy/sts"
  fi
    echo "    --ERROR: Volume mount [${volume_name}] IS NOT PRESENT BUT SHOULD BE in the ${container} container in the ${resource_name} deploy/sts"
  return 500
}

# return 0 for present
# return 1 for not present
_check_volume_mount_exists(){
  cue_eval=$1
  resource_name=$2
  container=$3
  volume_mount_name=$4

  # echo "Checking ${resource_name} in ${container} container for ${volume_mount_name} volume_mount"

  local problem=0
  local resource_json=$(echo ${cue_eval} | jq -r --arg NAME ${resource_name} '.[] | select((.kind=="StatefulSet") or (.kind=="Deployment")) | select(.metadata.name==$NAME)')
  local container_json=$(echo ${resource_json} | jq -r --arg CONTAINER ${container} '.spec.template.spec.containers[] | select(.name==$CONTAINER)')
  local check_volume_mount=$(echo ${container_json} | jq -r --arg VOLUME_MOUNT_NAME ${volume_mount_name} '.volumeMounts[] | select(.name==$VOLUME_MOUNT_NAME) | .name ')
  if [[ ! "${check_volume_mount}" == ${volume_mount_name} ]]; then
    # echo -e "    ${volume_mount_name} volume not found in ${resource_name} deploy/sts\n"
    problem=1
  fi
  return ${problem}
}


_check_environment_variable(){
  is_present=$1
  cue_eval=$2
  resource_name=$3
  container=$4
  environment_variable_name=$5

    # echo "Checking that volume mount [${volume_name}] ${is_present} in ${container} container in the ${resource_name} deploy/sts"
  _check_environment_variable_exists "${cue_eval}" ${resource_name} ${container} ${environment_variable_name}
  result=$?
  if [[ "${is_present}" == "is_present" ]];then
    if [[ ${result} -eq 0 ]]; then
      echo "    --Environment Variable [${environment_variable_name}] is present and should be in the ${container} container in the ${resource_name} deploy/sts"
      return 0
    else
      echo "    --ERROR: Environment Variable [${environment_variable_name}] is NOT PRESENT AND SHOULD BE in the ${container} container in the ${resource_name} deploy/sts"
      return 1
    fi
  else
    # if we are checking that the value is not present and the function says it is not there (1)
    if [[ $result -ne 0 ]]; then
      echo "    --Environment Variable [${environment_variable_name}] is not present and should not be in the ${container} container in the ${resource_name} deploy/sts"
      return 0
    fi
    echo "    --ERROR: Environment Variable [${environment_variable_name}] IS PRESENT BUT SHOULD NOT BE in the ${container} container in the ${resource_name} deploy/sts"
  fi
    echo "    --ERROR: Environment Variable [${environment_variable_name}] IS NOT PRESENT BUT SHOULD BE in the ${container} container in the ${resource_name} deploy/sts"
  return 500
}

# return 0 for present
# return 1 for not present
_check_environment_variable_exists(){
  cue_eval=$1
  resource_name=$2
  container=$3
  environment_variable_name=$4

  # echo "Checking ${resource_name} in ${container} container for ${environment_variable_name} volume_mount"

  local problem=0
  local resource_json=$(echo ${cue_eval} | jq -r --arg NAME ${resource_name} '.[] | select((.kind=="StatefulSet") or (.kind=="Deployment")) | select(.metadata.name==$NAME)')
  local container_json=$(echo ${resource_json} | jq -r --arg CONTAINER ${container} '.spec.template.spec.containers[] | select(.name==$CONTAINER)')
  local environment_json=$(echo ${container_json} | jq -r '.env')
  local check_envar=$(echo ${environment_json} | jq -r --arg ENVIRONMENT_VARIABLE_NAME ${environment_variable_name} '.[] | select(.name==$ENVIRONMENT_VARIABLE_NAME) | .name' )
  if [[ ! "${check_envar}" == ${environment_variable_name} ]]; then
    # echo -e "    ${environment_variable_name} envar not found in ${resource_name} deploy/sts\n"
    problem=1
  fi
  return ${problem}
}
