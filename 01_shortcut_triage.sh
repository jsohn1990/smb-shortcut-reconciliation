#!/bin/bash
# Description: Discovers .lnk files directly in the Samba share, sanitizes special characters, and triages matches.

base_dir="${HOME}/smb/${USER}"
shortcut_files_dir="${base_dir}/.shortcut_files"
log_dir="${base_dir}/log_shortcut_triage"

shortcuts_raw="${shortcut_files_dir}/01shortcuts_raw"
shortcuts_paths="${shortcut_files_dir}/02shortcuts_paths"
shortcuts_basenames="${shortcut_files_dir}/03shortcuts_basenames"
shortcuts_basenames_bkslash="${shortcut_files_dir}/04shortcuts_basenames_bkslash"
nonshortcuts="${shortcut_files_dir}/05nonshortcuts"
shortcut_orig="${shortcut_files_dir}/06shortcut_orig.csv"
shortcut_orig_manreview="${log_dir}/01shortcut_orig_manreview.txt"
autoreview_problems="${log_dir}/02autoreview_problems.txt"

if [ ! -d "$base_dir" ]; then
    echo "Error: Directory $base_dir does not exist."
    exit 1
fi

mkdir -p "$shortcut_files_dir" "$log_dir"

set -o pipefail

if ! find "${base_dir}" -name "*.lnk" > "$shortcuts_raw"; then
  echo "The command 'find ${base_dir} -name *.lnk' failed."
  exit 1
fi

if [ ! -s "$shortcuts_raw" ]
then
  echo -e "No shortcuts found in ${base_dir}.\n"
fi

sed -e 's/\.lnk$//' -e 's/\ \-\ Shortcut.*$//' "$shortcuts_raw" > "$shortcuts_paths"
gawk -F/ '{print $NF}' "$shortcuts_paths" > "$shortcuts_basenames"

sed -e 's/\[/\\[/g' -e 's/\]/\\]/g' -e 's/\./\\./g' -e 's/\^/\\^/g' -e 's/\$/\\$/g' "$shortcuts_basenames" > "$shortcuts_basenames_bkslash"

if ! find "${base_dir}/" | sed -n '/\.lnk$/!p' > "$nonshortcuts"; then
  echo "The command 'find ${base_dir}/ | sed -n '/\.lnk$/!p' > $nonshortcuts' failed."
  exit 1
fi

i=1
echo -n "" > "$shortcut_orig"
echo -n "" > "$shortcut_orig_manreview"
cat "$shortcuts_basenames_bkslash" | while IFS= read -r basename
do
  basename_search=$(sed -n "/\/${basename}[^/]*$/p" "$nonshortcuts")
  num_lines=$(sed -n "/\/${basename}[^/]*$/p" "$nonshortcuts" | wc -l)
  if [ -f "${basename_search}" ] && [ ${num_lines} -eq 1 ]; then
	echo "$i|${basename}|${basename_search}|file" >> "$shortcut_orig"
  elif [ -d "${basename_search}" ] && [ ${num_lines} -eq 1 ]; then
	echo "$i|${basename}|${basename_search}|dir" >> "$shortcut_orig"
  elif [ ${num_lines} -gt 1 ]; then
	echo -e "$i\n$(sed -n "${i}p" "$shortcuts_raw")\n${basename_search}" >> "$shortcut_orig_manreview"
  elif [ ${num_lines} -eq 0 ]; then
	echo -e "$i\n$(sed -n "${i}p" "$shortcuts_raw")\nno original detected" >> "$shortcut_orig_manreview"
  fi
  i=$((i + 1))
done

if [ -s "$shortcut_orig_manreview" ]; then
  echo -e "Manual review needed, see $shortcut_orig_manreview.\n"
  sed -i "1i\
  The numbers below are line numbers of ${shortcuts_raw}.\n\
The first line thereafter is the shortcut (lnk) file.\n\
The following lines show possible originals of said shortcuts.\n" "$shortcut_orig_manreview"
else
  rm -f "$shortcut_orig_manreview"
  echo -e "Nothing in manual review log.\n"
fi

if [ -s "$shortcut_orig" ]; then
  echo -n "" > "$autoreview_problems"
  cat "${shortcut_orig}" | while IFS= read -r line
  do
    line_num=$(echo "${line}" | gawk -F'|' '{print $1}')
    shortcut_basename=$(echo "${line}" | gawk -F'|' '{print $2}' | sed -e 's/\\//g')
    shortcut_dest=$(echo "${line}" | gawk -F'|' '{print $3}' | gawk -F'/' '{print $NF}')
    if [ "${shortcut_basename}" = "${shortcut_dest}" ] && [ -n "${shortcut_basename}" ] && [ -n "${shortcut_dest}" ]
    then
      continue
    elif [ "${shortcut_basename}" != "${shortcut_dest}" ] && [ -n "${shortcut_basename}" ] && [ -n "${shortcut_dest}" ]
    then
      if [ "${shortcut_basename}" = "${shortcut_dest%.*}" ]
	  then
        continue
	  else
        echo "${line_num} in ${shortcut_orig} has MISMATCHING NAMES" >> "$autoreview_problems"
	  fi
    elif [ -z "${shortcut_dest}" ]
    then
      echo "${line_num} in ${shortcut_orig} has NO DESTINATION" >> "$autoreview_problems"
    else
	  echo "A possible issue when automatically processing line ${line_num} at ${shortcut_orig}." >> "$autoreview_problems"
    fi
  done

  if [ -s "$autoreview_problems" ]; then
    sed -i "1i\
  Below is a list of issues from automated comparison.\n" "$autoreview_problems"
    echo -e "Auto review completed WITH issues.\n"
  else
    rm -f "$autoreview_problems"
	echo -e "Auto review completed without issues.\n"
  fi
fi

echo "$(date)" >> "${log_dir}/dates_shortcut_script_completed.txt"
exit