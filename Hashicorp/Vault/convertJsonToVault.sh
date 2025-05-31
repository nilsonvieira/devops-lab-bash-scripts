#!/bin/bash

INPUT_JSON="input.json"
JSON_CONTENT=$(cat "$INPUT_JSON")

echo "$JSON_CONTENT" | jq '
{
  saida1: with_entries({
    key: (.key | gsub("\\."; "_") | ascii_upcase),
    value: .value
  }),
  saida2: with_entries({
    key: .key,
    value: ("${" + (.key | gsub("\\."; "_") | ascii_upcase) + "}")
  })
}
'