#!/bin/bash

set -eu

get_config_value() {
    local key="$1"
    local config_file="$2"
    grep "^${key}=" "$config_file" | awk -F'=' '{print $2}'
}

config_file=""
input_file=""
output_dir=""

while getopts "c:i:o:" opt; do
    case ${opt} in
    c)  config_file=$OPTARG ;;
    i)  input_file=$OPTARG  ;;
    o)  output_dir=$OPTARG  ;;
    \?)echo "Invalid option: -$OPTARG" >&2; exit 1
    esac
done

if [[ -z "$config_file" || -z "$input_file" || -z "$output_dir" ]]; then
    echo "Error: Missing required arguments."
    exit 1
fi

#read config values
project_clone_path=$(get_config_value "project_clone_path" "$config_file")
conda_source_path=$(get_config_value "conda_source_path" "$config_file")
conda_env_name=$(get_config_value "conda_env_name" "$config_file")

#activate conda environment
source "$conda_source_path"
conda activate "$conda_env_name"

#run PPanGGOLiN
ppanggolin all \
    --fasta "$input_file" \
    --output "$output_dir" \
    --cpu "${SLURM_CPUS_PER_TASK:-1}" \
    --config "$project_clone_path/scripts/ppanggolin_config.yaml"
