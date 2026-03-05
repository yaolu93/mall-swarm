#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

COMPOSE_CMD="docker compose -f document/docker/docker-compose-env.yml -f document/docker/docker-compose-app.yml"

echo -e "${YELLOW}Checking service health status...${NC}\n"

# Array of critical services
SERVICES=("mysql" "elasticsearch" "nacos-registry" "rabbitmq" "redis" "mongo")
APP_SERVICES=("mall-portal" "mall-admin" "mall-gateway" "mall-auth" "mall-monitor" "mall-search")

# Check infrastructure services
echo -e "${YELLOW}Infrastructure Services:${NC}"
for service in "${SERVICES[@]}"; do
    status=$($COMPOSE_CMD ps $service 2>/dev/null | grep -E "healthy|running" | awk '{print $7}' | head -1)
    if [[ $status == *"healthy"* ]]; then
        echo -e "${GREEN}✓${NC} $service: $status"
    elif [[ $status == *"starting"* ]]; then
        echo -e "${YELLOW}⧐${NC} $service: $status"
    else
        echo -e "${RED}✗${NC} $service: $status"
    fi
done

sleep 2

# Check application services
echo -e "\n${YELLOW}Application Services:${NC}"
for service in "${APP_SERVICES[@]}"; do
    status=$($COMPOSE_CMD ps $service 2>/dev/null | tail -1 | awk '{print $6, $7}')
    container_id=$(docker ps -q --filter "name=^$service$" 2>/dev/null)
    
    if [[ -n "$container_id" ]]; then
        # Check if running or exited
        state=$(docker inspect --format='{{.State.Running}}' $container_id)
        if [[ "$state" == "true" ]]; then
            echo -e "${GREEN}✓${NC} $service: Running"
        else
            exit_code=$(docker inspect --format='{{.State.ExitCode}}' $container_id)
            echo -e "${RED}✗${NC} $service: Exited (code: $exit_code)"
        fi
    else
        echo -e "${YELLOW}⧐${NC} $service: Starting..."
    fi
done

echo -e "\n${YELLOW}Testing Mall-Portal Connectivity:${NC}"

# If mall-portal is running, test it
if docker ps | grep -q "mall-portal"; then
    echo "Testing database connectivity from mall-portal..."
    docker exec mall-portal sh -c "apk add --no-cache curl >/dev/null 2>&1 && curl -s http://localhost:8085/actuator/health | head -20" && echo "✓ Portal responding" || echo "✗ Portal not responding yet"
fi

echo -e "\n${YELLOW}Startup order observed:${NC}"
echo "1. Infrastructure (MySQL, Redis, RabbitMQ, Elasticsearch, Nacos)"
echo "2. Services appear when their dependencies are healthy"
echo "3. Check logs with: docker compose ... logs <service>"
