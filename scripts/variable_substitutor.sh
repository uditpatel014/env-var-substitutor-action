#!/bin/bash

# Inputs
FILES=${FILES:-}
PLACEHOLDER_PREFIX=${PREFIX:-env}
FAIL_FAST=${3:-true}
DESTINATION_PATH=${DEST_PATH}
DRY_RUN=${DRY_RUN:-false}
CREATE_DIRS=${CREATE_DIRS:-true}

set -eE -o functrace

# Error handler
fatal() {
  echo "::error::Line $1: Command failed: $2"
  exit 1
}
trap 'fatal "$LINENO" "$BASH_COMMAND"' ERR

# Validation functions
validate_environment() {
  echo "::group::Environment Check"
  if ! command -v envsubst >/dev/null; then
    echo "::error::envsubst not found. Install gettext package first."
    exit 1
  fi
  echo "::endgroup::"
}

validate_prefix() {
  if [ "${#PLACEHOLDER_PREFIX}" -ne 3 ]; then
    echo "::error::Prefix must be exactly 3 characters. Got '$PREFIX'"
    exit 1
  fi
}

validate_files() {
  echo "::group::File Validation"
  local missing=0

  IFS=',' read -ra files <<< "$INPUT_FILES"
  for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
      echo "::error::File not found: $file"
      ((missing++))
    fi
  done

  if [ "$missing" -gt 0 ]; then
    echo "::error::$missing input file(s) missing"
    exit 1
  fi
    echo "::endgroup::"
  }

#validate_output_dir(){
#  if [ ! -w "$DEST_DIR" ]; then
#        echo "::error::Cannot write to $DEST_DIR"
#        exit 1
#      fi
#      echo "::endgroup::"
#
#}

validate_output_dir() {
  echo "::group::Directory Validation"
  if [ -n "$DEST_DIR" ] && [ ! -d "$DEST_DIR" ]; then
    if [ "$CREATE_DIRS" = "true" ]; then
      mkdir -p "$DEST_DIR"
    else
      echo "::error::Destination directory does not exist: $DEST_DIR"
      exit 1
    fi
  fi
 # Now check if it's writable after ensuring it exists
  if [ ! -w "$DEST_DIR" ]; then
    echo "::error::Cannot write to $DEST_DIR"
    exit 1
  fi
  echo "::endgroup::"
}
# Dry run display function
show_diff() {
  local src=$1
  local dest=$2
  echo "::warning::DRY RUN - Proposed changes:"
  diff --color=always -u <(cat "$src") <(echo "$UPDATED_CONTENT") || true
  echo "Would write from: $src"
  echo "Would write to: $dest"
}


# Log configuration
echo "::group::Configurations"
echo "Files: $FILES"
echo "Placeholder Prefix: $PLACEHOLDER_PREFIX"
#echo "Fail on Missing: $FAIL_FAST"
echo "Destination Path: $DESTINATION_PATH"
echo "Dry-run: $DRY_RUN"
echo "Create-Directories: $CREATE_DIRS"
echo "::endgroup::"

# Function to process a single file
process_file() {
  local FILE=$1
  local DEST_DIR=${DESTINATION_PATH:-$(dirname "$FILE")}
  local DEST_FILE


  if [[ "$DEST_DIR" =~ [^a-zA-Z0-9/_\-\.] ]]; then
        echo "::error:: DEST_DIR contains invalid characters" >&2
        exit 1

  elif [[ "$DEST_DIR" == */ ]]; then
      echo "Directory Path provided $DEST_DIR (Ends with /)"
      DEST_FILE=$DEST_DIR/$(basename "$FILE")

  # If DEST_DIR has a file extension, assume it's a file
  elif [[ "$DEST_DIR" =~ \.[a-zA-Z0-9]+$ ]]; then
      echo "File Path (Has extension)"
      DEST_FILE=$DEST_DIR
      DEST_DIR=$(dirname $DEST_DIR)


  # Otherwise, assume it's a directory (it might not exist yet)
  else
      echo "Dir okay (Assumed directory)"
       DEST_FILE=$DEST_DIR/$(basename "$FILE")

  fi

  echo "::group::Output Detials"
  echo "Destination Files Path: $DEST_FILE"
  echo "Destination Directory Path: $DEST_DIR"
  echo "::endgroup::"



  #validate output directory
  validate_output_dir

  echo "::group::Processing $FILE → $DEST_FILE"

  # Check if file exists
  if [ ! -f "$FILE" ]; then
    echo "::error::File $FILE does not exist."
    return 1
  fi

  # Read file content
  CONTENT=$(cat "$FILE")
  UPDATED_CONTENT="$CONTENT"

  # Find all placeholders
  PLACEHOLDERS=$(echo "$CONTENT" | grep -oP '\$\{'"$PLACEHOLDER_PREFIX"'\.[a-zA-Z0-9_*?-]+\s*\}')
  echo "$PLACEHOLDERS"
  if [ -z "$PLACEHOLDERS" ]; then
    echo "::warning::No match found for $PLACEHOLDER_PREFIX in $FILE"
    if [ "$FAIL_FAST" = "true" ]; then
       echo "::error::Missing environment variable in file $FILE."
       return 1
    fi
  fi

  # Substitute placeholders with environment variables
  for VAR in $PLACEHOLDERS; do
    echo "variable_name: $VAR"
    VAR_NAME=$(echo "$VAR" | sed -E 's/\$\{'"$PLACEHOLDER_PREFIX"'\.([a-zA-Z0-9_*?-]+)\s*\}/\1/')
    echo "var_name: $VAR_NAME"
    VALUE=$(eval echo "$VAR_NAME") # Get the value of the environment variable

    VALUE=$(echo "$VALUE" | tr -d '[:space:]')
    if [ -z "$VALUE" ]; then
      echo "::warning::Environment variable $VAR_NAME is not set."
      if [ "$FAIL_FAST" = "true" ]; then
        echo "::error::Missing environment variable $VAR_NAME in file $FILE."
        return 1
      fi

    else
      echo "Substituting {$PLACEHOLDER_PREFIX.$VAR_NAME} with [REDACTED] in $DEST_FILE"
      UPDATED_CONTENT=$(echo "$UPDATED_CONTENT" | sed "s/{$PLACEHOLDER_PREFIX.$VAR_NAME}/$VALUE/g")
      UPDATED_CONTENT=$(echo "$UPDATED_CONTENT" | envsubst)
      echo "$UPDATED_CONTENT"
    fi
  done

  # Handle output
  if [ "$DRY_RUN" = "true" ]; then
    show_diff "$FILE" "$DEST_FILE"
  else
    mkdir -p "$(dirname "$DEST_FILE")"
    # Write updated content back to the file
    echo "$UPDATED_CONTENT" > "$DEST_FILE"
    echo "Updated file: $DEST_FILE"
  fi
}

#Main Substitution
substitute_var(){
# Split comma-separated files into an array
IFS=',' read -r -a FILE_ARRAY <<< "$FILES"

# Process files sequentially
echo "::group::Processing Files"
for FILE in "${FILE_ARRAY[@]}"; do
  process_file "$FILE" || exit 1
done
echo "::endgroup::"
}

# Execution Flow
validate_environment
validate_prefix
validate_files
substitute_var


echo "::notice::Variable Substitution completed successfully!"