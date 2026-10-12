#!/bin/bash
# Description: Safely removes processed legacy .lnk shortcut files and logs actions.

base_dir="${HOME}/smb/${USER}"
shortcut_files_dir="${base_dir}/.shortcut_files"
log_dir="${base_dir}/log_shortcut_cleanup"

rm_log="${log_dir}/rm_log.csv"
shortcut_orig="${shortcut_files_dir}/06shortcut_orig.csv"
shortcuts_raw="${shortcut_files_dir}/01shortcuts_raw"

if [ ! -d "$base_dir" ]; then
    echo "Error: Directory $base_dir does not exist."
    exit 1
fi

if [ ! -s "$shortcut_orig" ]; then
    echo "Error: $shortcut_orig is missing or empty."
    exit 1
fi

if [ ! -s "$shortcuts_raw" ]; then
    echo "Error: $shortcuts_raw does not exist."
    exit 1
fi

mkdir -p "$log_dir"
echo -n "" > "$rm_log"

cat "$shortcut_orig" | while IFS= read -r line
do
  filetype=$(echo "$line" | gawk -F'|' '{print $4}')
    if [ "${filetype}" = dir ] || [ "${filetype}" = file ]; then
      line_num=$(echo "$line" | gawk -F'|' '{print $1}')
      rm_arg=$(sed -n "${line_num}p" "$shortcuts_raw")
	  if rm "${rm_arg}"; then
        echo "${line_num}|rm ${rm_arg}" >> "$rm_log"
	  else 
	    echo "The command 'rm ${rm_arg}' failed."
	  fi
	else
	  echo "Issue processing $line in ${shortcut_orig}."
    fi
done

if [ -s "$rm_log" ]; then
  sed -i "1i\
|Below is a log of shortcut files (.lnk) removed." "$rm_log"
  echo -e "Shortcuts (.lnk) removed, see $rm_log"
else
  echo "No .lnk files deleted."
  rm -f "$rm_log"
fi

echo "$(date)" >> "${log_dir}/dates_shortcut_cleanup_completed.txt"
exit