#!/bin/bash
# make-executable.sh
# Make all shell scripts executable

echo "Making scripts executable..."

chmod +x deploy/*.sh
chmod +x scripts/*.sh
chmod +x *.sh

echo "✅ All scripts are now executable"

# List executable files
echo ""
echo "Executable files:"
find . -name "*.sh" -type f -executable 2>/dev/null || find . -name "*.sh" -type f