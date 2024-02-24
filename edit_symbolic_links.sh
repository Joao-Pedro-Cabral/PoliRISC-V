#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Error: Insufficient number of arguments. Please provide two arguments."
    exit 1
fi

if [ "$1" != "create" ] && [ "$1" != "remove" ]; then
  echo "Invalid command"
  exit 1
fi

# create or remove
command=$1

# run this file in root directory of the project
root_dir="."

# List of directories to exclude
exclude_dirs=("docs" "simulation" "synthesis" ".git")

# Path to the macros file (simulation)
macros_file="$PWD/simulation/$2.vh"

if ! [ -e "$macros_file" ]; then
  macros_file="$PWD/synthesis/Vivado/$2.vh" # synthesis macro
  if ! [ -e "$macros_file" ]; then
    echo "Macros file doesn't exists"
    exit 1
  fi
fi

# Function to check if a directory is in the exclude list
is_excluded() {
    local dir="$1"
    for exclude_dir in "${exclude_dirs[@]}"
    do
      if [ "$exclude_dir" == "$dir" ] ; then
        return 0
      fi
    done
    return 1
}

# Function to check if a directory is a leaf directory
is_leaf() {
    local dir="$1"
    # Check if the directory has no subdirectories
    [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -type d)" ]
}

# Function to check if a directory doesn't contain the macros file
contain_macros_file() {
    local dir="$1"
    # Check if the macros file is not present in the directory
    [ -e "$dir/$2.vh" ]
}

# Iterate through all subdirectories
find "$root_dir" -type d | while read -r sub_dir; do

    # Extract the directory name from the path
    dir_name=$(echo "$sub_dir" | sed 's|^\./\([^/]*\)/.*|\1|')

    # Check if the directory should be excluded
    if is_excluded "$dir_name"; then
        echo "Skipping excluded directory: $sub_dir"
        continue
    fi

    if [ -d "$sub_dir" ] && is_leaf "$sub_dir"; then
        if ! contain_macros_file "$sub_dir" "$2" && [ "$command" == "create" ]; then
          echo "Creating macros file from leaf directory: $sub_dir"
          ln -s "$macros_file" "$sub_dir/$2.vh"
        elif contain_macros_file "$sub_dir" "$2" && [ "$command" == "remove" ]; then
          echo "Removing macros file from leaf directory: $sub_dir"
          rm "$sub_dir/$2.vh"
        fi
    fi
done
