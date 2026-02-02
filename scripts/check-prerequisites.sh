#!/bin/bash
# Check prerequisites for the GenAI Golden Path tutorial

set -e

echo "============================================"
echo "  GenAI Golden Path - Prerequisites Check"
echo "============================================"
echo ""

ERRORS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    local cmd=$1
    local name=$2
    local install_hint=$3

    printf "%-20s" "$name:"
    if command -v "$cmd" &> /dev/null; then
        version=$($cmd --version 2>/dev/null | head -1)
        echo -e "${GREEN}OK${NC} ($version)"
    else
        echo -e "${RED}NOT FOUND${NC}"
        echo "   Install: $install_hint"
        ((ERRORS++))
    fi
}

check_env() {
    local var=$1
    local name=$2

    printf "%-20s" "$name:"
    if [ -n "${!var}" ]; then
        echo -e "${GREEN}SET${NC}"
    else
        echo -e "${RED}NOT SET${NC}"
        ((ERRORS++))
    fi
}

echo "A. Local Development Tools"
echo "-------------------------------------------"
check_command "node" "Node.js" "nvm install 20"
check_command "yarn" "Yarn" "npm install -g yarn"
check_command "docker" "Docker" "https://docs.docker.com/get-docker/"
check_command "git" "Git" "apt install git / brew install git"
echo ""

echo "B. Cloud CLI Tools"
echo "-------------------------------------------"
check_command "gcloud" "Google Cloud SDK" "https://cloud.google.com/sdk/docs/install"
check_command "kubectl" "kubectl" "gcloud components install kubectl"
echo ""

echo "C. Environment Variables"
echo "-------------------------------------------"
check_env "GITLAB_TOKEN" "GITLAB_TOKEN"
check_env "GCP_PROJECT_ID" "GCP_PROJECT_ID (optional)"
echo ""

# Check Docker daemon
printf "%-20s" "Docker daemon:"
if docker ps &> /dev/null; then
    echo -e "${GREEN}RUNNING${NC}"
else
    echo -e "${YELLOW}NOT RUNNING${NC}"
    echo "   Start Docker daemon and try again"
    ((ERRORS++))
fi
echo ""

# Summary
echo "============================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All prerequisites met!${NC}"
    echo "You're ready to start the tutorial."
else
    echo -e "${RED}$ERRORS issue(s) found.${NC}"
    echo "Please fix the issues above before continuing."
fi
echo "============================================"

exit $ERRORS
