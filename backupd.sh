#!/bin/bash

# Validate input parameters
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 dir backupdir interval-secs max-backups"
  exit 1
fi

# Assign input parameters to variables
source_dir=$1
backup_dir=$2
interval_secs=$3
max_backups=$4

# Validate directories
if [ ! -d "$source_dir" ]; then
  echo "Error: Source directory '$source_dir' does not exist."
  exit 1
fi

# Create the backup directory if it doesn't exist
mkdir -p "$backup_dir" || {
  echo "Error: Unable to create or access backup directory '$backup_dir'."
  exit 1
}

# Get initial directory info
info_last="$backup_dir/directory-info.last"
ls -lR "$source_dir" > "$info_last"

# Function to perform backup
perform_backup() {
  timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
  backup_subdir="$backup_dir/$timestamp"
  cp -r "$source_dir" "$backup_subdir" || {
    echo "Error: Failed to copy directory to backup location '$backup_subdir'."
    return 1
  }
  echo "Backup created at: $backup_subdir"

  # Manage backup limit
  backups=("$backup_dir"/20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*/)
  if [ "${#backups[@]}" -gt "$max_backups" ]; then
    to_delete=$(("${#backups[@]}" - max_backups))
    for old_backup in "${backups[@]:0:to_delete}"; do
      rm -rf "$old_backup" && echo "Deleted old backup: $old_backup"
    done
  fi
}

# Perform initial backup
perform_backup || exit 1

# Start monitoring loop
while true; do
  sleep "$interval_secs"
  info_new="$backup_dir/directory-info.new"
  ls -lR "$source_dir" > "$info_new"

  if [ -f "$info_last" ] && [ -f "$info_new" ]; then
    if ! cmp -s "$info_last" "$info_new"; then
      perform_backup && mv "$info_new" "$info_last"
    else
      rm "$info_new"
    fi
  else
    echo "Error: One of the comparison files is missing."
    exit 1
  fi
done

