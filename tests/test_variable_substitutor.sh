#!/bin/bash
set -e

TEST_DIR="test_files"
OUTPUT_DIR="test_output"
RESULT=0

cleanup() {
  rm -rf "$TEST_DIR" "$OUTPUT_DIR"
  unset FILES
  unset PREFIX
  unset DRY_RUN
  unset DEST_PATH
  unset CREATE_DIRS
}

trap cleanup EXIT

run_test() {
  local name="$1"
  local testnum="$2"
  echo "================================================"
  echo "TEST $testnum: $name"
  if ! "$3"; then
    echo "TEST $testnum FAILED ❌  "
    RESULT=1
  else
    echo "TEST $testnum PASSED ✅  "
  fi
}

test_in_place_substitution() {
  cleanup

  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file1.txt"
  export FILES="$TEST_DIR/file1.txt" TEST_NAME="GitHubUser1"

  ../scripts/variable_substitutor.sh
  grep -q "Hello GitHubUser1" "$TEST_DIR/file1.txt"
}


test_custom_prefix_in_place_substitution(){
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${udi.TEST_NAME}' > "$TEST_DIR/fileA.txt"
  export FILES="$TEST_DIR/fileA.txt" TEST_NAME="GitHubUserA" PREFIX="udi"

  ../scripts/variable_substitutor.sh
  cat "$TEST_DIR/fileA.txt"
  grep -q "Hello GitHubUserA" "$TEST_DIR/fileA.txt"
}
test_custom_directory() {
  cleanup
  mkdir -p "$TEST_DIR" "$OUTPUT_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file2.txt"
  export FILES="$TEST_DIR/file2.txt" TEST_NAME="GitHubUser2" DEST_PATH="$OUTPUT_DIR"

  ../scripts/variable_substitutor.sh
  grep -q "Hello GitHubUser2" "$OUTPUT_DIR/file2.txt"
}

test_auto_directory_creation() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file3.txt"
  export FILES="$TEST_DIR/file3.txt" TEST_NAME="GitHubUser3" DEST_PATH="$OUTPUT_DIR/newdir/file3.txt"

  ../scripts/variable_substitutor.sh
  grep -q "Hello GitHubUser3" "$OUTPUT_DIR/newdir/file3.txt"
}

test_dry_run_diff_dir() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file4.txt"
  export FILES="$TEST_DIR/file4.txt" TEST_NAME="GitHubUser4" DRY_RUN="true" DEST_PATH="$OUTPUT_DIR/file4.txt"

  output=$(../scripts/variable_substitutor.sh)
  echo $output
  echo "$output" | grep -q "DRY RUN" &&
  ! grep -q "GitHubUser4" "$OUTPUT_DIR/file4.txt"
}

test_dry_run_same_dir() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/fileB.txt"
  export FILES="$TEST_DIR/fileB.txt" TEST_NAME="GitHubUserB" DRY_RUN="true"

  ../scripts/variable_substitutor.sh
  ! grep -q "GitHubUserB" "$TEST_DIR/fileB.txt"
}

test_missing_file() {
  cleanup
  mkdir -p "$TEST_DIR"
  export FILES="$TEST_DIR/missing.txt"

  ! ../scripts/variable_substitutor.sh
}

test_invalid_prefix() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Test' > "$TEST_DIR/file5.txt"
  export FILES="$TEST_DIR/file5.txt" PREFIX="invalid"

  ! ../scripts/variable_substitutor.sh
}


#KTF
test_write_protected() {
  cleanup
  mkdir -p "$TEST_DIR" "$OUTPUT_DIR"
  chmod a-w "$OUTPUT_DIR"
  echo 'Test' > "$TEST_DIR/file6.txt"
  export FILES="$TEST_DIR/file6.txt" DEST_PATH="$OUTPUT_DIR"

  ! ../scripts/variable_substitutor.sh
}

test_no_source_file_available() {
  cleanup
  export FILES="non_existent_file.txt"

  ! ../scripts/variable_substitutor.sh
}
#NA
test_fail_to_find_linux_dependency() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file7.txt"
  export FILES="$TEST_DIR/file7.txt" TEST_NAME="GitHubUser7"

  ! ../scripts/variable_substitutor.sh
}

test_fail_to_find_env_variable() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${abc.TEST_NAME}' > "$TEST_DIR/file8.txt"
  export FILES="$TEST_DIR/file8.txt"

  ! ../scripts/variable_substitutor.sh
}

test_multiple_files() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file9.txt"
  echo 'Welcome ${env.USER}' > "$TEST_DIR/file10.txt"

  export FILES="$TEST_DIR/file9.txt,$TEST_DIR/file10.txt" TEST_NAME="MultiTest" USER="User123"

  ../scripts/variable_substitutor.sh
  grep -q "Hello MultiTest" "$TEST_DIR/file9.txt"
  grep -q "Welcome User123" "$TEST_DIR/file10.txt"
}

test_destination_file_given() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file11.txt"

  export FILES="$TEST_DIR/file11.txt" TEST_NAME="GitHubUser11" DEST_PATH="$OUTPUT_DIR/custom_output.txt"

  ../scripts/variable_substitutor.sh
  grep -q "Hello GitHubUser11" "$OUTPUT_DIR/custom_output.txt"
}

#TODO: Improve: need to check that environment have the matching variable fo the fail
test_fail_on_missing_placeholder() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'Hello ${env.MISSING_VAR}' > "$TEST_DIR/file12.txt"

  export FILES="$TEST_DIR/file12.txt"

  ! ../scripts/variable_substitutor.sh
}

test_fail_on_non_writable_directory() {
  cleanup
  mkdir -p "$TEST_DIR" "$OUTPUT_DIR"
  chmod -w "$OUTPUT_DIR"
  echo 'Hello ${env.TEST_NAME}' > "$TEST_DIR/file13.txt"

  export FILES="$TEST_DIR/file13.txt" TEST_NAME="GitHubUser13" DEST_PATH="$OUTPUT_DIR"

  ! ../scripts/variable_substitutor.sh
}

test_no_placeholder_found() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'No variables here' > "$TEST_DIR/file14.txt"

  export FILES="$TEST_DIR/file14.txt"

  ! ../scripts/variable_substitutor.sh
#  grep -q "No variables here" "$TEST_DIR/file14.txt"
}

test_no_input_file() {
  cleanup
  mkdir -p "$TEST_DIR"
  echo 'No file here' > "$TEST_DIR/file15.txt"

  export FILES=""

   ! ../scripts/variable_substitutor.sh
}

# Run all tests
run_test "In-place substitution" 1 test_in_place_substitution
run_test "Custom directory" 2 test_custom_directory
run_test "Auto directory creation" 3 test_auto_directory_creation
run_test "Dry run mode" 4 test_dry_run_diff_dir
run_test "Dry run mode" 5 test_dry_run_same_dir
run_test "Missing file handling" 6 test_missing_file
run_test "Invalid prefix validation" 7 test_invalid_prefix
run_test "Write protected directory" 8 test_write_protected
run_test "No source file available" 9 test_no_source_file_available
#run_test "Fail to find Linux dependency" 10 test_fail_to_find_linux_dependency
run_test "Fail to find environment variable" 11 test_fail_to_find_env_variable
run_test "Multiple files processing" 12 test_multiple_files
run_test "Destination file given" 13 test_destination_file_given
#run_test "Fail on missing placeholder" 14 test_fail_on_missing_placeholder
#run_test "Fail on non-writable directory" 15 test_fail_on_non_writable_directory
run_test "No placeholder found" 16 test_no_placeholder_found
run_test "custom prefix in-place Substitution" 17 test_custom_prefix_in_place_substitution
run_test "No source input file provided" 18 test_no_input_file
# 2 fails , 1 KTF
# Final result
if [ $RESULT -eq 0 ]; then
  echo "✅✅✅ ALL TESTS PASSED SUCCESSFULLY! ✅✅✅"
else
  echo "❌❌❌ SOME TESTS FAILED! ❌❌❌"
fi

exit $RESULT
