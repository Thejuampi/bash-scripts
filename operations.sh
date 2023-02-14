#!/bin/bash

check_jar_conflicts_sequencial_cached_only_jar_names() {
  local directory="$1"
  local regex_filter="$2"

  declare -A class_cache=()

  while IFS= read -r -d '' jar_file; do
    class_cache["$jar_file"]=$(jar -tf "$jar_file" | grep '\.class$' | sed 's/\.class$//' | tr '/' '.' | grep -E "$regex_filter" || true)
  done < <(find "$directory" -name "*.jar" -print0)

  local conflict_found=false

  for jar_file1 in "${!class_cache[@]}"; do
    local classes1="${class_cache[$jar_file1]}"
    for jar_file2 in "${!class_cache[@]}"; do
      if [ "$jar_file1" != "$jar_file2" ]; then
        local classes2="${class_cache[$jar_file2]}"
        local common_classes=$(comm -12 <(echo "$classes1" | sort) <(echo "$classes2" | sort))
        if [ ! -z "$common_classes" ]; then
          conflict_found=true
          echo "$jar_file1 and $jar_file2 have class conflicts."
          break
        fi
      fi
    done
  done

  if ! $conflict_found; then
    echo "No class conflicts found."
  fi
}

check_jar_conflicts_sequencial_cached() {
  local directory="$1"
  local regex_filter="$2"

  declare -A class_cache=()

  while IFS= read -r -d '' jar_file; do
    class_cache["$jar_file"]=$(jar -tf "$jar_file" | grep -E '\.class$' | grep -vE '^(module-info|META-INF/versions/).*\.class$' | sed 's/\.class$//' | tr '/' '.' | grep -E "$regex_filter" || true)

  done < <(find "$directory" -name "*.jar" -print0)

  local conflict_found=false

  for jar_file1 in "${!class_cache[@]}"; do
    local classes1="${class_cache[$jar_file1]}"
    for jar_file2 in "${!class_cache[@]}"; do
      if [ "$jar_file1" != "$jar_file2" ]; then
        local classes2="${class_cache[$jar_file2]}"
        local common_classes=$(comm -12 <(echo "$classes1" | sort) <(echo "$classes2" | sort))
        if [ ! -z "$common_classes" ]; then
          conflict_found=true
          echo "Class conflicts found between $jar_file1 and $jar_file2:"
          head -n 3 <<< "$common_classes"
          if [ $(wc -l <<< "$common_classes") -gt 3 ]; then
            echo "and $(($(wc -l <<< "$common_classes") - 3)) more."
          fi
        fi
      fi
    done
  done

  if ! $conflict_found; then
    echo "No class conflicts found."
  fi
}
