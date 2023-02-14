#!/bin/bash

check_jar_conflicts() {
  local directory=$1
  local jar_files=$(find "$directory" -name "*.jar")
  local conflict_found=false

  for jar_file in $jar_files; do
    local classes=$(jar -tf "$jar_file" | grep '\.class$' | sed 's/\.class$//' | tr '/' '.')

    for other_jar_file in $jar_files; do
      if [ "$jar_file" != "$other_jar_file" ]; then
        local other_classes=$(jar -tf "$other_jar_file" | grep '\.class$' | sed 's/\.class$//' | tr '/' '.')
        local common_classes=$(comm -12 <(echo "$classes" | sort) <(echo "$other_classes" | sort))
        if [ ! -z "$common_classes" ]; then
          conflict_found=true
          echo "Class conflicts found between $jar_file and $other_jar_file:"
          echo "$common_classes"
        fi
      fi
    done
  done

  if ! $conflict_found; then
    echo "No class conflicts found."
  fi
}

check_jar_conflicts_v2() {
  local directory=$1
  local regex_filter=$2
  local jar_files=$(find "$directory" -name "*.jar")
  local conflict_found=false

  for jar_file in $jar_files; do
    local classes=$(jar -tf "$jar_file" | grep '\.class$' | sed 's/\.class$//' | tr '/' '.')

    if [ ! -z "$regex_filter" ]; then
      classes=$(echo "$classes" | grep -E "$regex_filter")
    fi

    for other_jar_file in $jar_files; do
      if [ "$jar_file" != "$other_jar_file" ]; then
        (
          local other_classes=$(jar -tf "$other_jar_file" | grep '\.class$' | sed 's/\.class$//' | tr '/' '.')
          if [ ! -z "$regex_filter" ]; then
            other_classes=$(echo "$other_classes" | grep -E "$regex_filter")
          fi
          local common_classes=$(comm -12 <(echo "$classes" | sort) <(echo "$other_classes" | sort))
          if [ ! -z "$common_classes" ]; then
            conflict_found=true
            echo "Class conflicts found between $jar_file and $other_jar_file:"
            echo "$common_classes"
          fi
        ) &
      fi
    done
  done

  # Wait for all subshells to finish before returning
  wait

  if ! $conflict_found; then
    echo "No class conflicts found."
  fi
}
