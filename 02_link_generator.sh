#!/bin/bash
# Description: Generates symbolic and hard links based on triage CSV output.

base_dir="${HOME}/smb/${USER}"
shortcut_files_dir="${base_dir}/.shortcut_files"
log_dir="${base_dir}/log_link_generator"

shortcut_orig="${shortcut_files_dir}/06shortcut_orig.csv"
shortcuts_paths="${shortcut_files_dir}/02shortcuts_paths"
symlink_log_csv="${log_dir}/01symlink_log.csv"
hardlink_log_csv="${log_dir}/02hardlink_log.csv"

if [ ! -d "$base_dir" ]; then
    echo "Error: Directory $base_dir does not exist."
    exit 1
fi

if [ ! -s "$shortcut_orig" ]; then
    echo "Error: $shortcut_orig is missing or empty."
    exit 1
fi

if [ ! -s "$shortcuts_paths" ]; then
    echo "Error: $shortcuts_paths is missing or empty."
    exit 1
fi

mkdir -p "$shortcut_files_dir" "$log_dir"

set -o pipefail

echo -n "" > "$symlink_log_csv"
echo -n "" > "$hardlink_log_csv"

cat "$shortcut_orig" | while IFS= read -r line
do
  filetype=$(echo "$line" | gawk -F'|' '{print $4}')
  if [ "${filetype}" = dir ]
  then
    ln_orig=$(echo "$line" | gawk -F'|' '{print $3}')
	line_num=$(echo "$line" | gawk -F'|' '{print $1}')
    ln_link=$(sed -n "${line_num}p" "$shortcuts_paths")
	if ln -s "$ln_orig" "$ln_link"; then
	  echo "${line_num}|${ln_orig}|${ln_link}" >> "$symlink_log_csv"
	else
	  echo "The command 'ln -s $ln_orig $ln_link' failed."
	fi
  elif [ "${filetype}" = file ]
  then
    ln_orig=$(echo "$line" | gawk -F'|' '{print $3}')
	line_num=$(echo "$line" | gawk -F'|' '{print $1}')
    ln_link=$(sed -n "${line_num}p" "$shortcuts_paths")
	if ln "$ln_orig" "$ln_link"; then
	  echo "${line_num}|${ln_orig}|${ln_link}" >> "$hardlink_log_csv"
	else
	  echo "The command 'ln $ln_orig $ln_link' failed."
	fi
  else
    echo "Problem with processing ${line} in ${shortcut_orig}."
  fi
done

if [ -s "$symlink_log_csv" ]; then
  sed -i "1i\
|Below is a log of symbolic links made." "$symlink_log_csv"
  echo -e "Symlinks generated, see ${symlink_log_csv}."
else
  echo "No symlinks generated."
  rm -f "$symlink_log_csv"
fi

if [ -s "$hardlink_log_csv" ]; then
  sed -i "1i\
|Below is a log of hard links made." "$hardlink_log_csv"
  echo -e "Hardlinks generated, see ${hardlink_log_csv}."
else
  echo "No hardlinks generated."
  rm -f "$hardlink_log_csv"
fi

echo "$(date)" >> "${log_dir}/dates_links_script_completed.txt"
exit