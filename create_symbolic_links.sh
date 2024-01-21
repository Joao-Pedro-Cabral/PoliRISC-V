#!/bin/bash

# run this file in root directory of the project
root_dir="."

# List of directories to exclude
exclude_dirs=("docs" "simulation" "synthesis" ".git")

# Path to the macros.vh file
macros_file="$PWD/simulation/macros.vh"

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

# Function to check if a directory doesn't contain "macros.vh"
does_not_contain_macros_vh() {
    local dir="$1"
    # Check if the "macros.vh" file is not present in the directory
    [ ! -e "$dir/macros.vh" ]
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

    if [ -d "$sub_dir" ] && is_leaf "$sub_dir" && does_not_contain_macros_vh "$sub_dir"; then
        echo "Processing leaf directory without macros.vh: $sub_dir"

        # Create a symbolic link to macros.vh in the subdirectory
        ln -s "$macros_file" "$sub_dir/macros.vh"
    fi
done
