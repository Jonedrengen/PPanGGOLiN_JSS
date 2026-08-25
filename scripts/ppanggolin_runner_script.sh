#!/bin/bash

# author: Jon Sztuk Slotved (JOSS@ssi.dk)

# this is a wrapper script for running PPanGGOLiN, using annotated gff3 files, from bakta, as input.

######### utility functions ###########
help() {
    echo "Usage: $0"
}

######### functions ###########
validate_input_options_exist() {
    local input_annotations="$1"
    local output_dir="$2"
    local config_file="$3"

    if [ ! -f "$input_annotations" ]; then
        echo "Error: Input annotations does not exist."
        echo "provide the annotations generated with bakta. The file should be a line-separated list of paths to gff3 files."
        exit 1
    fi
    if [ ! -d "$output_dir" ]; then
        echo "Error: Output folder does not exist."
        exit 1
    fi
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file does not exist."
        exit 1
    fi
}

load_config_values() {
    local config_file="$1"
    local conda_source_path
    local conda_env_name
    local project_clone_path
    local mode
    local cpus
    local mem
    local partition

    # Load configuration values from config_template.env
    conda_source_path=$(grep '^conda_source_path=' "$config_file" | awk -F'=' '{print $2}')
    conda_env_name=$(grep '^conda_env_name=' "$config_file" | awk -F'=' '{print $2}')
    project_clone_path=$(grep '^project_clone_path=' "$config_file" | awk -F'=' '{print $2}')
    mode=$(grep '^mode=' "$config_file" | awk -F'=' '{print $2}')
    cpus=$(grep '^cpus_allocated=' "$config_file" | awk -F'=' '{print $2}')
    mem=$(grep '^mem_allocated=' "$config_file" | awk -F'=' '{print $2}')
    partition=$(grep '^partition=' "$config_file" | awk -F'=' '{print $2}')
    job_name=$(grep '^job_name=' "$config_file" | awk -F'=' '{print $2}')

    # inform the user about the loaded configuration values
    printf "Loaded conda_source_path: %s\n" "$conda_source_path"
    printf "Loaded conda_env_name: %s\n" "$conda_env_name"
    printf "Loaded project_clone_path: %s\n" "$project_clone_path"
    printf "Loaded mode: %s\n" "$mode"
    printf "Loaded cpus: %s\n" "$cpus"
    printf "Loaded mem: %s\n" "$mem"
    printf "Loaded partition: %s\n" "$partition"
    printf "Loaded job_name: %s\n" "$job_name"

    echo
    echo "INFO: if any of the above values are empty, please check your config_template.env file."
}

#source and activate conda environment
activate_conda_env() {
    local conda_source_path="$1"
    local conda_env_name="$2"

    # source conda and activate environment
    source "$conda_source_path"
    conda activate "$conda_env_name"

    printf "Activated conda environment: %s\n" "$conda_env_name"
    printf "Conda source path: %s\n" "$conda_source_path"
}

create_output_structure() {
    local output_folder="$1"
    
    mkdir -p "$output_folder"
    mkdir -p "$output_folder/processing_files"
    mkdir -p "$output_folder/completed_files"
    mkdir -p "$output_folder/slurm_output"
}

#only creates the command.
create_ppanggolin_annotation_cmd() {
    local input_annotations="$1"
    local output_dir="$2"
    local cpus="$3"
    local ppanggolin_config_path="$4"

    cmd=(ppanggolin all --anno "$input_annotations" --output "$output_dir" --config "$ppanggolin_config_path" --cpu "${cpus:-1}")
    echo "${cmd[@]}"
}

#wraps a cmd in a slurm cmd and submits it to slurm
run_cmd_via_slurm() {
    local input_cmd="$1"
    local cpus="$2"
    local mem="$3"
    local partition="$4"
    local job_name="$5"
    local slurm_output_dir="$6"

    sbatch --job-name="$job_name" \
           --cpus-per-task="$cpus" \
           --mem="$mem" \
           --partition="$partition" \
           --output="$slurm_output_dir/${job_name}_%j.out" \
           --error="$slurm_output_dir/${job_name}_%j.err" \
           --wrap="$input_cmd"
}

#######################################
############# run script ##############
#######################################


input_annotations=""
output_dir=""
config_file=""
while getopts "h:i:o:c:m:" opt; do
    case ${opt} in
    h) help; exit 0 ;;
    i) input_annotations="$OPTARG" ;;
    o) output_dir="$OPTARG" ;;
    c) config_file="$OPTARG" ;;
    *) help; exit 1 ;;
    esac
done

validate_input_options_exist "$input_annotations" "$output_dir" "$config_file"

load_config_values "$config_file"

activate_conda_env "$conda_source_path" "$conda_env_name"

create_output_structure "$output_dir"

command=$(create_ppanggolin_annotation_cmd "$input_annotations" "$output_dir" "$cpus" "$project_clone_path/scripts/ppanggolin_config.yaml")

#takes information from config and runs the command via slurm
run_cmd_via_slurm "$command" "$cpus" "$mem" "$partition" "$job_name" "$output_dir/slurm_output"






