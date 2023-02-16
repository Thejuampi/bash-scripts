#!/bin/bash


check_jar_conflicts() {
    local class_cache=()
    local jar_files=("$1"/*.jar)
    local max_conflicts=${2:-3}

    # Sort the class files by name
    local class_files=($(find "$1" -name '*.class' -print0 | sort -z))

    # Iterate over each JAR file in the directory
    for jar_file in "${jar_files[@]}"; do
        local jar_name=$(basename "$jar_file")
        local classes=()

        # Iterate over each class file in the JAR file
        while IFS= read -r -d '' class_file; do
            local class_name=$(unzip -p "$jar_file" "$class_file" | head -n 1 | sed 's/.* class \([a-zA-Z0-9$_]*\).*/\1/')
            
            # Check if this class has already been processed
            if [[ ${class_cache[$class_name]} == "$jar_name" ]]; then
                continue
            fi
            
            # Check if this class conflicts with a class from another JAR file
            for other_class_file in "${classes[@]}"; do
                local other_jar_name=${class_cache[$class_name]}
                local other_jar_file="$1/$other_jar_name.jar"
                if cmp -s <(unzip -p "$jar_file" "$class_file") <(unzip -p "$other_jar_file" "$other_class_file"); then
                    echo "Class $class_name in JAR $jar_name conflicts with class in JAR $other_jar_name"
                    break
                fi
            done
            
            # Add the class file to the list of processed classes
            class_cache[$class_name]=$jar_name
            classes+=("$class_file")
        done < <(unzip -Z -1 "$jar_file" '*.class' 2>/dev/null | tr '\n' '\0')
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
