#!/bin/bash


check_jar_conflicts() {
    local class_cache=()
    local jar_files=("$1"/*.jar)
    local max_conflicts=${2:-3}

    # Extract the list of class files and their contents from all JAR files
    declare -A class_map
    while IFS= read -r -d '' class_file; do
        local jar_file=$(find "${jar_files[@]}" -type f -name "$(basename "$class_file")" | head -n 1)
        local jar_name=$(basename "$jar_file")
        local class_name=$(echo "$class_file" | sed 's/.*\///;s/\.class$//')

        if [[ -n ${class_map[$class_name]} ]]; then
            echo "Duplicate class file found: $class_file"
            continue
        fi

        class_map[$class_name]=$jar_name$'\n'$(unzip -p "$jar_file" "$class_file" | md5sum | cut -d ' ' -f 1)
    done < <(unzip -Z -1 "${jar_files[@]}" '*.class' | tr '\n' '\0')

    # Check for conflicts between class files
    for class_name in "${!class_map[@]}"; do
        local jar_name=${class_map[$class_name]%%$'\n'*}
        local md5=${class_map[$class_name]#*$'\n'}
        for other_class_name in "${!class_cache[@]}"; do
            local other_jar_name=${class_cache[$other_class_name]%%$'\n'*}
            local other_md5=${class_cache[$other_class_name]#*$'\n'}
            if [[ $class_name != $other_class_name && $jar_name != $other_jar_name && $md5 == $other_md5 ]]; then
                echo "Class $class_name in JAR $jar_name conflicts with class in JAR $other_jar_name"
            fi
        done
        class_cache[$class_name]=$jar_name$'\n'$md5
    done
}

check_jar_conflicts_sequencial_cached_only_jar_names() {
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
