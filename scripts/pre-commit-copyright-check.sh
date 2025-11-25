#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# Pre-commit hook to check/add copyright headers to new files

set -euo pipefail

COPYRIGHT_LINE="# Copyright (c) 2025 MikeT LLC. All rights reserved."

add_header_if_needed() {
    local file="$1"
    
    # Skip if file doesn't exist (deleted)
    [[ -f "$file" ]] || return 0
    
    # Skip binary files
    if ! grep -qI . "$file" 2>/dev/null; then
        return 0
    fi
    
    # Check if already has copyright
    if head -n 5 "$file" | grep -qi "copyright.*miket"; then
        return 0
    fi
    
    # Determine file type
    local ext="${file##*.}"
    local basename=$(basename "$file")
    
    # Only process code files
    case "$ext" in
        sh|bash)
            # Shell script - preserve shebang
            if head -n 1 "$file" | grep -q "^#!"; then
                local temp_file=$(mktemp)
                head -n 1 "$file" > "$temp_file"
                echo "$COPYRIGHT_LINE" >> "$temp_file"
                echo "" >> "$temp_file"
                tail -n +2 "$file" >> "$temp_file"
                mv "$temp_file" "$file"
            else
                # No shebang, add at top
                local temp_file=$(mktemp)
                echo "$COPYRIGHT_LINE" > "$temp_file"
                echo "" >> "$temp_file"
                cat "$file" >> "$temp_file"
                mv "$temp_file" "$file"
            fi
            ;;
        py)
            # Python - preserve shebang if present
            if head -n 1 "$file" | grep -q "^#!"; then
                local temp_file=$(mktemp)
                head -n 1 "$file" > "$temp_file"
                echo "$COPYRIGHT_LINE" >> "$temp_file"
                echo "" >> "$temp_file"
                tail -n +2 "$file" >> "$temp_file"
                mv "$temp_file" "$file"
            else
                local temp_file=$(mktemp)
                echo "$COPYRIGHT_LINE" > "$temp_file"
                echo "" >> "$temp_file"
                cat "$file" >> "$temp_file"
                mv "$temp_file" "$file"
            fi
            ;;
        yml|yaml)
            # YAML - add as comment at top
            local temp_file=$(mktemp)
            echo "$COPYRIGHT_LINE" > "$temp_file"
            echo "" >> "$temp_file"
            cat "$file" >> "$temp_file"
            mv "$temp_file" "$file"
            ;;
        *)
            # Other text files - skip for now
            return 0
            ;;
    esac
    
    echo "Added copyright header to: $file"
    git add "$file"
}

# Process all staged files
for file in "$@"; do
    add_header_if_needed "$file"
done


