#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# One-time script to add copyright headers to existing code files

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

COPYRIGHT_LINE="# Copyright (c) 2025 MikeT LLC. All rights reserved."

# Counters (use files to persist across subshells)
COUNTER_FILE=$(mktemp)
echo "0" > "$COUNTER_FILE.modified"
echo "0" > "$COUNTER_FILE.skipped"

add_header_to_file() {
    local file="$1"
    local header="$2"
    
    # Check if file already has copyright header
    if head -n 5 "$file" | grep -qi "copyright.*miket"; then
        echo "  ⏭️  Already has copyright: $file"
        echo $(($(cat "$COUNTER_FILE.skipped") + 1)) > "$COUNTER_FILE.skipped"
        return 0
    fi
    
    # Create temp file with header
    local temp_file=$(mktemp)
    
    # For shell scripts, preserve shebang
    if [[ "$file" == *.sh ]] && head -n 1 "$file" | grep -q "^#!"; then
        head -n 1 "$file" > "$temp_file"
        echo "$header" >> "$temp_file"
        echo "" >> "$temp_file"
        tail -n +2 "$file" >> "$temp_file"
    # For Python files, add header after any shebang
    elif [[ "$file" == *.py ]] && head -n 1 "$file" | grep -q "^#!"; then
        head -n 1 "$file" > "$temp_file"
        echo "$header" >> "$temp_file"
        echo "" >> "$temp_file"
        tail -n +2 "$file" >> "$temp_file"
    # For YAML files, add as comment
    elif [[ "$file" == *.yml ]] || [[ "$file" == *.yaml ]]; then
        echo "$header" > "$temp_file"
        echo "" >> "$temp_file"
        cat "$file" >> "$temp_file"
    # For other files, add at top
    else
        echo "$header" > "$temp_file"
        echo "" >> "$temp_file"
        cat "$file" >> "$temp_file"
    fi
    
    # Replace original file
    mv "$temp_file" "$file"
    echo "  ✅ Added copyright: $file"
    echo $(($(cat "$COUNTER_FILE.modified") + 1)) > "$COUNTER_FILE.modified"
}

# Process shell scripts
echo "Processing shell scripts..."
find . -type f -name "*.sh" ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./.venv/*" ! -path "*/__pycache__/*" 2>/dev/null | while IFS= read -r file; do
    add_header_to_file "$file" "$COPYRIGHT_LINE" || true
done

# Process Python files
echo ""
echo "Processing Python files..."
find . -type f -name "*.py" ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./.venv/*" ! -path "*/__pycache__/*" 2>/dev/null | while IFS= read -r file; do
    # Skip __pycache__ directories
    [[ "$file" == *__pycache__* ]] && continue
    add_header_to_file "$file" "$COPYRIGHT_LINE" || true
done

# Process YAML files (but skip certain generated/config files)
echo ""
echo "Processing YAML files..."
find . -type f \( -name "*.yml" -o -name "*.yaml" \) ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./.venv/*" ! -path "./backups/*" ! -path "./logs/*" ! -path "./artifacts/*" ! -path "*/__pycache__/*" 2>/dev/null | while IFS= read -r file; do
    # Skip lock files and certain generated files
    if [[ "$file" == *.lock.yml ]] || [[ "$file" == */.ansible/* ]] || [[ "$file" == *__pycache__* ]]; then
        continue
    fi
    add_header_to_file "$file" "$COPYRIGHT_LINE" || true
done

FILES_MODIFIED=$(cat "$COUNTER_FILE.modified" 2>/dev/null || echo "0")
FILES_SKIPPED=$(cat "$COUNTER_FILE.skipped" 2>/dev/null || echo "0")
rm -f "$COUNTER_FILE.modified" "$COUNTER_FILE.skipped"

echo ""
echo "=========================================="
echo "Copyright Header Addition Complete"
echo "=========================================="
echo "Files modified: $FILES_MODIFIED"
echo "Files skipped (already had copyright): $FILES_SKIPPED"
echo ""
echo "Review changes with: git diff"
echo "Commit with: git add -A && git commit -m 'Add copyright headers to code files'"
