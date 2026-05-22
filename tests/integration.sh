#!/bin/bash
# Integration test for clipboard
# This script verifies downstream-specific integration, branding, and paths.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Antigravity Clipboard Bridge Integration Tests ===${NC}\n"

ERRORS=0

check_file() {
    local file=$1
    if [ -f "$file" ]; then
        echo -e "[${GREEN}PASS${NC}] File exists: $file"
    else
        echo -e "[${RED}FAIL${NC}] File missing: $file"
        ERRORS=$((ERRORS + 1))
    fi
}

check_branding() {
    local file=$1
    local pattern="gemini-clipboard-bridge"
    if grep -q "$pattern" "$file"; then
        echo -e "[${RED}FAIL${NC}] Branding leaked in $file: Found '$pattern'"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "[${GREEN}PASS${NC}] Branding clean in $file"
    fi
}

check_path() {
    local file=$1
    local pattern=$2
    if grep -q "$pattern" "$file"; then
        echo -e "[${GREEN}PASS${NC}] Path correct in $file: Found '$pattern'"
    else
        echo -e "[${RED}FAIL${NC}] Path incorrect in $file: Missing '$pattern'"
        ERRORS=$((ERRORS + 1))
    fi
}

# 1. Verify Directory Structure
echo -e "${BLUE}Checking Directory Structure...${NC}"
check_file "skills/copy/SKILL.md"
check_file "skills/copy/copy.sh"
check_file "skills/help/SKILL.md"

# Verify rules directory has been deleted
if [ -d "rules" ] || [ -f "rules/clipboard.md" ]; then
    echo -e "[${RED}FAIL${NC}] rules folder or rules/clipboard.md still exists"
    ERRORS=$((ERRORS + 1))
else
    echo -e "[${GREEN}PASS${NC}] rules folder and rules/clipboard.md have been successfully removed"
fi

# 1.1 Verify Redundant Instructions Deletion
if [ -f "INSTRUCTIONS.md" ]; then
    echo -e "[${RED}FAIL${NC}] Redundant INSTRUCTIONS.md still exists"
    ERRORS=$((ERRORS + 1))
else
    echo -e "[${GREEN}PASS${NC}] Redundant INSTRUCTIONS.md has been deleted"
fi

# 2. Verify Branding (No upstream names in downstream files)
echo -e "\n${BLUE}Verifying Branding...${NC}"
check_branding "skills/copy/SKILL.md"
check_branding "skills/help/SKILL.md"

# 3. Verify Path Integrity in Instructions
echo -e "\n${BLUE}Verifying Path Integrity...${NC}"
check_path "skills/copy/SKILL.md" "~/.gemini/antigravity-cli/plugins/clipboard/skills/copy/copy.sh"

# 4. Verify Script Executability
echo -e "\n${BLUE}Verifying Script Permissions...${NC}"
if [ -x "skills/copy/copy.sh" ]; then
    echo -e "[${GREEN}PASS${NC}] skills/copy/copy.sh is executable"
else
    echo -e "[${RED}FAIL${NC}] skills/copy/copy.sh is NOT executable"
    ERRORS=$((ERRORS + 1))
fi

# 5. Verify Skill Name Re-branding
echo -e "\n${BLUE}Verifying Skill Name...${NC}"
if grep -q "name: copy" "skills/copy/SKILL.md" && ! grep -q "name: Clipboard Bridge" "skills/copy/SKILL.md"; then
    echo -e "[${GREEN}PASS${NC}] Skill name correctly rebranded to copy"
else
    echo -e "[${RED}FAIL${NC}] Skill name rebranding failed in SKILL.md"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "name: help" "skills/help/SKILL.md"; then
    echo -e "[${GREEN}PASS${NC}] Help skill name correctly set to help"
else
    echo -e "[${RED}FAIL${NC}] Help skill name verification failed in SKILL.md"
    ERRORS=$((ERRORS + 1))
fi

echo -e "\n${BLUE}Summary:${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS tests failed.${NC}"
    exit 1
fi
