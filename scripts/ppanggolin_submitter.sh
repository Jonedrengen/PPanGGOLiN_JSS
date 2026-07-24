#!/bin/bash

# author: Jon Sztuk Slotved (JOSS@ssi.dk)

#this is a submitter script and will run a tool, depending on the mode of operation, either locally or on a SLURM cluster.

set -eu

usage() {
    echo
    echo "Usage: $0 -c <config_file> -i <input_dir> -o <output_dir> -m <mode> [-s <sample_list>] [-h]"
    echo
    echo "  -c <config_file> : Path to the configuration file"
    echo "  -i <input_dir>   : Path to the input directory containing genome files"
    echo "  -o <output_dir>  : Path to the output directory where results will be saved"
    echo "  -m <mode>        : Mode of operation (opts: 'LOCAL', 'SLURM')"
    echo "  -h               : Display this help message"
    echo
    echo "Optional:"
    echo "  -s <sample_list> : Path to file with line-separated list of sample names to process (default: all samples in input_dir)"
    echo
}

get_config_value() {
    local key="$1"
    local config_file="$2"
    local value

    value=$(grep "^${key}=" "$config_file" | awk -F'=' '{print $2}')

    if [[ -z "$value" ]]; then
        echo "Error: Key '$key' not found in config file '$config_file'."
        exit 1
    fi

    printf '%s\n' "$value"
}

generate_sample_list() {
    local input_dir="$1"
    local sample_list_path="$2"

    find "$input_dir" -maxdepth 1 -type f -name "*.fasta" -exec basename {} .fasta \; > "$sample_list_path"

    if [[ ! -s "$sample_list_path" ]]; then
        echo "sample_list file generation failed or is empty. Please check the input directory for .fasta files."
        exit 1
    fi
}

create_file_system() {
    local output_dir="$1"

    mkdir -p "$output_dir"
    mkdir -p "$output_dir/processing_files"
    mkdir -p "$output_dir/completed_files"

    if [[ ! -d "$output_dir" || ! -d "$output_dir/processing_files" || ! -d "$output_dir/completed_files" ]]; then
        echo "Error: Failed to create necessary directories in '$output_dir'."
        exit 1
    fi
}

create_ppangolin_input_file() {
    local input_dir="$1"
    local sample_list_path="$2"
    local ppanggolin_input_path="$3"
    local sample_id
    local fasta_path

    while IFS= read -r sample_id; do
        [[ -z "$sample_id" ]] && continue

        fasta_path="$input_dir/$sample_id.fasta"
        if [[ ! -f "$fasta_path" ]]; then
            echo "Error: FASTA file for sample '$sample_id' does not exist." >&2
            return 1
        fi

        printf '%s\t%s\n' "$sample_id" "$fasta_path"
    done < "$sample_list_path" > "$ppanggolin_input_path"
}

start_ppanggolin_runner() {
    local config_file="$1"
    local ppanggolin_input_path="$2"
    local results_dir="$3"
    local mode="$4"
    local cpus_allocated
    local mem_allocated
    local partition

    echo "running in $mode mode"
    if [[ "$mode" == "LOCAL" ]]; then
        bash "$project_clone_path/scripts/ppanggolin_runner_LOCAL.sh" -c "$config_file" -i "$ppanggolin_input_path" -o "$results_dir"
    else
        cpus_allocated=$(get_config_value "cpus_allocated" "$config_file")
        mem_allocated=$(get_config_value "mem_allocated" "$config_file")
        partition=$(get_config_value "partition" "$config_file")

        sbatch \
            --cpus-per-task="$cpus_allocated" \
            --mem="$mem_allocated" \
            --partition="$partition" \
            "$project_clone_path/scripts/ppanggolin_runner_SLURM.sh" \
            -c "$config_file" \
            -i "$ppanggolin_input_path" \
            -o "$results_dir"
    fi
}

#
config_file=""
input_dir=""
output_dir=""
mode=""
sample_list=""

while getopts "c:i:o:m:s:h" opt; do
    case ${opt} in
    c)  config_file=$OPTARG     ;;
    i)  input_dir=$OPTARG       ;;
    o)  output_dir=$OPTARG      ;;
    m)  mode=$OPTARG            ;;
    s)  sample_list=$OPTARG     ;;
    h)  usage; exit 0           ;;
    \?)echo "Invalid option: -$OPTARG" >&2; usage; exit 1
    esac
done

if [[ -z "$config_file" || -z "$input_dir" || -z "$output_dir" || -z "$mode" ]]; then
    echo "Error: Missing required arguments."
    usage
    exit 1
fi

if [[ "$mode" != "LOCAL" && "$mode" != "SLURM" ]]; then
    echo "Error: Invalid mode specified. Use 'LOCAL' or 'SLURM'."
    exit 1
fi

#checks for existence of config file and input directory
if [[ ! -f "$config_file" ]]; then
    echo "Error: Config file '$config_file' does not exist."
    exit 1
fi

if [[ ! -d "$input_dir" ]]; then
    echo "Error: Input directory '$input_dir' does not exist."
    exit 1
fi

if [[ -n "$sample_list" && ! -s "$sample_list" ]]; then
    echo "Error: Sample list '$sample_list' does not exist or is empty."
    exit 1
fi

#use absolute paths in the PPanGGOLiN input file and runner arguments
config_file=$(cd "$(dirname "$config_file")" && pwd -P)/$(basename "$config_file")
input_dir=$(cd "$input_dir" && pwd -P)
if [[ -n "$sample_list" ]]; then
    sample_list=$(cd "$(dirname "$sample_list")" && pwd -P)/$(basename "$sample_list")
fi

#read config values
project_clone_path=$(get_config_value "project_clone_path" "$config_file")

#PPanGGOLiN must create its own output directory
results_dir="$output_dir/results"
if [[ -e "$results_dir" ]]; then
    echo "Error: Results directory '$results_dir' already exists."
    exit 1
fi

#filesystem
create_file_system "$output_dir"
output_dir=$(cd "$output_dir" && pwd -P)
results_dir="$output_dir/results"

#generate sample list if not provided
if [[ -z "$sample_list" ]]; then
    sample_list="$output_dir/sample_list.txt"
    generate_sample_list "$input_dir" "$sample_list"
fi

#create PPanGGOLiN's tab-separated genome ID/FASTA path input file
ppanggolin_input_path="$output_dir/ppanggolin_input.tsv"
create_ppangolin_input_file "$input_dir" "$sample_list" "$ppanggolin_input_path"

if [[ ! -s "$ppanggolin_input_path" ]]; then
    echo "Error: Sample list '$sample_list' contains no sample IDs."
    exit 1
fi

#run tool
start_ppanggolin_runner "$config_file" "$ppanggolin_input_path" "$results_dir" "$mode"
