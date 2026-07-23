#!/bin/bash

set -eu

usage() {
    echo
    echo "Usage: $0 -c <config_file> -i <input_dir> -o <output_dir> [-h]"
    echo
    echo "  -c <config_file> : Path to the configuration file (default: config_template.env)"
    echo "  -i <input_dir>   : Path to the input directory containing genome files"
    echo "  -o <output_dir>  : Path to the output directory where results will be saved"
    echo "  -h               : Display this help message"
}

while getopts "c:i:o:m:h" opt; do
    case ${opt} in
    c)  config_file=$OPTARG ;;
    i)  input_dir=$OPTARG   ;;
    o)  output_dir=$OPTARG  ;;
    m)  mode=$OPTARG      ;;
    h)  usage; exit 0;;
    \?)echo "Invalid option: -$OPTARG" >&2; usage; exit
    esac
done

if [[ -z "$config_file" || -z "$input_dir" || -z "$output_dir" || -z "$mode" ]]; then
    echo "Error: Missing required arguments."
    usage
    exit 1
fi

