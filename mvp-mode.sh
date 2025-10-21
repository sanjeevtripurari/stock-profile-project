#!/bin/bash
# MVP Mode Management Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_usage() {
    echo "Usage: $0 {on|off|status|enable|disable}"
    echo ""
    echo "Commands:"
    echo "  on       - Enable MVP mode"
    echo "  off      - Disable MVP mode"
    echo "  status   - Check current status"
    echo "  enable   - Enable MVP + restart services"
    echo "  disable  - Disable MVP + restart services"
}

set_mvp_mode() {
    local enable=$1
    local env_file=".env"
    
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}❌ .env file not found!${NC}"
        return 1
    fi
    
    local new_value
    if [ "$enable" = "true" ]; then
        new_value="MVP_MODE=true"
    else
        new_value="MVP_MODE=false"
    fi
    
    # Check if MVP_MODE exists
    if grep -q "^MVP_MODE=" "$env_file"; then
        # Replace existing line
        sed -i "s/^MVP_MODE=.*/$new_value/" "$env_file"
    else
        # Add new line
        echo "$new_value" >> "$env_file"
    fi
    
    return 0
}

get_mvp_status() {
    local env_file=".env"
    
    echo -e "${BLUE}🎯 MVP Mode Status:${NC}"
    
    if [ ! -f "$env_file" ]; then
        echo -e "${YELLOW}⚠️  .env file not found!${NC}"
        return
    fi
    
    if grep -q "^MVP_MODE=true" "$env_file"; then
        echo -e "${GREEN}✅ MVP Mode: ENABLED (using mock data)${NC}"
    elif grep -q "^MVP_MODE=false" "$env_file"; then
        echo -e "${RED}❌ MVP Mode: DISABLED (using real APIs)${NC}"
    else
        echo -e "${YELLOW}⚠️  MVP Mode: NOT SET (defaulting to real APIs)${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo "  ./mvp-mode.sh on       - Enable MVP mode"
    echo "  ./mvp-mode.sh off      - Disable MVP mode"
    echo "  ./mvp-mode.sh status   - Check current status"
    echo "  ./mvp-mode.sh enable   - Enable MVP + restart services"
    echo "  ./mvp-mode.sh disable  - Disable MVP + restart services"
}

case "${1:-}" in
    "on")
        echo -e "${BLUE}🎯 Enabling MVP Mode (mock data)...${NC}"
        if set_mvp_mode "true"; then
            echo -e "${GREEN}✅ MVP Mode enabled${NC}"
            echo -e "${CYAN}ℹ️  System will use mock data instead of real APIs${NC}"
            echo -e "${YELLOW}🔄 Restart services: make restart${NC}"
        fi
        ;;
    
    "off")
        echo -e "${BLUE}🎯 Disabling MVP Mode (real API data)...${NC}"
        if set_mvp_mode "false"; then
            echo -e "${GREEN}✅ MVP Mode disabled${NC}"
            echo -e "${CYAN}ℹ️  System will use real Alpha Vantage API${NC}"
            echo -e "${YELLOW}⚠️  Make sure ALPHA_VANTAGE_API_KEY is set in .env${NC}"
            echo -e "${YELLOW}🔄 Restart services: make restart${NC}"
        fi
        ;;
    
    "status")
        get_mvp_status
        ;;
    
    "enable")
        echo -e "${BLUE}🎯 Enabling MVP Mode and restarting services...${NC}"
        if set_mvp_mode "true"; then
            echo -e "${GREEN}✅ MVP Mode enabled${NC}"
            echo -e "${YELLOW}🔄 Restarting services...${NC}"
            docker-compose restart
            echo -e "${GREEN}🚀 MVP Mode enabled and services restarted!${NC}"
        fi
        ;;
    
    "disable")
        echo -e "${BLUE}🎯 Disabling MVP Mode and restarting services...${NC}"
        if set_mvp_mode "false"; then
            echo -e "${GREEN}✅ MVP Mode disabled${NC}"
            echo -e "${YELLOW}🔄 Restarting services...${NC}"
            docker-compose restart
            echo -e "${GREEN}🚀 MVP Mode disabled and services restarted!${NC}"
        fi
        ;;
    
    *)
        print_usage
        exit 1
        ;;
esac