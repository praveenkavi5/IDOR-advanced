#!/bin/bash

# Enhanced IDOR Scanner with Advanced Techniques
# Features: Multi-parameter fuzzing, Session handling, Response analysis, Dynamic wordlist generation
# Inspired by methodologies from :cite[1]:cite[3]:cite[6]

# Configuration
declare -a HTTP_METHODS=("GET" "POST" "PUT" "DELETE" "PATCH")
declare -a PARAM_LOCATIONS=("url" "body" "header" "cookie")
declare -a FUZZ_PARAMETERS=("id" "user" "uid" "account" "file" "document" "uuid")
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
RATE_LIMIT=0.5  # Seconds between requests

# Advanced variables
HIGH_PRIVILEGE_COOKIE=""
LOW_PRIVILEGE_COOKIE=""
SESSION_TOKEN=""
CSRF_TOKEN=""

function advanced_idor_scan {
    local base_url=$1
    local wordlist=$2
    local output=$3
    
    echo -e "\n\033[1;34m[+] Starting Advanced IDOR Scan\033[0m"
    echo -e "Target: ${base_url}"
    echo -e "Techniques Enabled:"
    echo -e " - Multi-parameter fuzzing"
    echo -e " - Session privilege escalation"
    echo -e " - Response fingerprinting"
    echo -e " - HTTP method testing (${HTTP_METHODS[@]})"
    echo -e " - Parallel processing\n"
    
    # Dynamic wordlist generation
    generate_dynamic_wordlist "${base_url}"
    
    # Multi-user testing
    if [[ -n "$HIGH_PRIVILEGE_COOKIE" && -n "$LOW_PRIVILEGE_COOKIE" ]]; then
        echo -e "\033[1;33m[!] Testing privilege escalation scenarios\033[0m"
        test_privilege_escalation "${base_url}"
    fi
    
    # Parallel fuzzing
    echo -e "\033[1;33m[!] Starting parallel fuzzing\033[0m"
    while read -r line; do
        for method in "${HTTP_METHODS[@]}"; do
            for param_location in "${PARAM_LOCATIONS[@]}"; do
                (
                test_endpoint "${base_url}" "${line}" "${method}" "${param_location}" "${output}"
                ) &
                sleep $RATE_LIMIT
            done
        done
    done < "${wordlist}"
    
    wait
}

function test_endpoint {
    local base_url=$1
    local resource=$2
    local method=$3
    local param_location=$4
    local output=$5
    
    local url="${base_url}/${resource}"
    local headers=()
    local body=""
    
    # Parameter fuzzing with multiple patterns :cite[3]:cite[10]
    for param in "${FUZZ_PARAMETERS[@]}"; do
        case $param_location in
            "url")
                url+="?${param}=FUZZ"
                ;;
            "body")
                body+="${param}=FUZZ&"
                ;;
            "header")
                headers+=("-H" "${param}: FUZZ")
                ;;
            "cookie")
                headers+=("-H" "Cookie: ${param}=FUZZ")
                ;;
        esac
    done
    
    # Test various parameter formats :cite[3]
    for value in "1001" "0001" "../${resource}" "%2e%2e%2f${resource}" "[1001]" "{id:1001}"; do
        local test_url="${url//FUZZ/${value}}"
        local test_body="${body//FUZZ/${value}}"
        
        # Send requests with different privilege levels
        local response_high=$(send_request "${method}" "${test_url}" "${test_body}" "${headers[@]}" "-H" "Cookie: ${HIGH_PRIVILEGE_COOKIE}")
        local response_low=$(send_request "${method}" "${test_url}" "${test_body}" "${headers[@]}" "-H" "Cookie: ${LOW_PRIVILEGE_COOKIE}")
        
        analyze_responses "${response_high}" "${response_low}" "${test_url}" "${output}"
    done
}

function analyze_responses {
    local resp_high=$1
    local resp_low=$2
    local url=$3
    local output=$4
    
    # Response fingerprint comparison :cite[7]
    local length_high=$(echo "${resp_high}" | wc -c)
    local length_low=$(echo "${resp_low}" | wc -c)
    
    if [[ "$resp_high" == "$resp_low" && "$length_high" -eq "$length_low" ]]; then
        echo -e "\033[1;31m[+] Potential IDOR: ${url}\033[0m"
        echo "Vulnerable URL: ${url}" >> "${output}"
        echo "Response High: ${length_high} bytes" >> "${output}"
        echo "Response Low: ${length_low} bytes" >> "${output}"
    fi
}

function generate_dynamic_wordlist {
    local url=$1
    echo -e "\033[1;33m[!] Generating dynamic wordlist\033[0m"
    
    # Extract parameters from page content :cite[6]
    curl -s "${url}" | grep -Eo "id=['\"][a-zA-Z0-9_]+" | cut -d= -f2 | tr -d "'\"" >> dynamic_wordlist.txt
    curl -s "${url}" | grep -Eo "/[a-z0-9_]{8,}/" | sort -u >> dynamic_wordlist.txt
    
    # Combine with standard wordlist
    sort -u dynamic_wordlist.txt "${wordlist}" > combined_wordlist.txt
    wordlist="combined_wordlist.txt"
}