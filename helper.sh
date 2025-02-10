#!/bin/bash
# avp helper script - SB Jan '25

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running"
        exit 1
    fi
}

check_compose_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "Error: Docker Compose file '$file' not found"
        exit 1
    fi
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_subnet() {
    local subnet=$1
    if [[ $subnet =~ ^[0-9]{1,2}$ ]] && [ $subnet -ge 0 ] && [ $subnet -le 32 ]; then
        return 0
    else
        return 1
    fi
}

check_interface() {
    if ! ip link show "$1" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

create_network() {
    while true; do
        read -p "Enter the network name: " network_name
        if [ -n "$network_name" ]; then
            break
        else
            echo "Network name cannot be empty. Please try again."
        fi
    done

    while true; do
        read -p "Enter the parent ethernet adapter name (e.g., eth0): " parent_interface
        if check_interface "$parent_interface"; then
            break
        else
            echo "Interface $parent_interface does not exist. Please try again."
        fi
    done

    while true; do
        read -p "Enter subnet address (e.g., 192.168.1.0): " subnet_addr
        read -p "Enter subnet mask (0-32): " subnet_mask
        
        if validate_ip "$subnet_addr" && validate_subnet "$subnet_mask"; then
            subnet="$subnet_addr/$subnet_mask"
            break
        else
            echo "Invalid subnet format. Please try again."
        fi
    done

    while true; do
        read -p "Enter gateway address: " gateway
        if validate_ip "$gateway"; then
            break
        else
            echo "Invalid gateway format. Please try again."
        fi
    done

    if docker network inspect "$network_name" >/dev/null 2>&1; then
        echo "Network $network_name already exists. Please choose a different name."
        return 1
    fi

    echo "Creating Docker network with the following configuration:"
    echo "Network Name: $network_name"
    echo "Parent Interface: $parent_interface"
    echo "Subnet: $subnet"
    echo "Gateway: $gateway"

    docker network create \
        --driver ipvlan \
        --subnet "$subnet" \
        --gateway "$gateway" \
        -o parent="$parent_interface" \
        -o ipvlan_mode=l2 \
        "$network_name"

    if [ $? -eq 0 ]; then
        echo "Network $network_name created successfully!"
    else
        echo "Failed to create network. Please check your configuration and try again."
        return 1
    fi
}

start_avp() {
    check_compose_file "avp-compose.yml"
    echo "Starting AVP stack..."
    docker compose -f avp-compose.yml up -d
}

stop_avp() {
    check_compose_file "avp-compose.yml"
    echo "Stopping AVP stack..."
    docker compose -f avp-compose.yml down
}

start_zigbee() {
    check_compose_file "zigbee2mqtt-compose.yml"
    echo "Starting Zigbee2MQTT stack..."
    docker compose -f zigbee2mqtt-compose.yml up -d
}

stop_zigbee() {
    check_compose_file "zigbee2mqtt-compose.yml"
    echo "Stopping Zigbee2MQTT stack..."
    docker compose -f zigbee2mqtt-compose.yml down
}

check_status() {
if docker ps --format '{{.Names}}' | grep -q shadownet_avp; then
  echo -e "Container shadownet_avp is \033[32m running\033[0m."
else
  echo -e "Container shadownet_avp is \033[31mnot running\033[0m."
fi
if docker ps --format '{{.Names}}' | grep -q zigbee2mqtt; then
  echo -e "Container zigbee2mqtt is \033[32m running\033[0m."
else
  echo -e "Container zigbee2mqtt is \033[31mnot running\033[0m."
fi
if docker ps --format '{{.Names}}' | grep -q mqtt_server; then
  echo -e "Container mqtt_server is \033[32m running\033[0m."
else
  echo -e "Container mqtt_server is \033[31mnot running\033[0m."
fi
if docker network ls --format '{{.Name}}' | grep -q shadownet; then
  echo -e "Network shadownet is \033[32m running\033[0m."
else
  echo -e "Network shadownet is \033[31mnot running\033[0m."
fi
}

show_menu() {
    PS3="Please select an option: "
    options=("Check Status" "Start AVP" "Stop AVP" "Start Zigbee2MQTT" "Stop Zigbee2MQTT" "Create Network" "Exit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Check Status")
                check_status
                break
                ;;
            "Start AVP")
                start_avp
                break
                ;;
            "Stop AVP")
                stop_avp
                break
                ;;
            "Start Zigbee2MQTT")
                start_zigbee
                break
                ;;
            "Stop Zigbee2MQTT")
                stop_zigbee
                break
                ;;
            "Create Network")
                create_network
                break
                ;;
            "Exit")
                exit 0
                ;;
            *) 
                echo "Invalid option $REPLY"
                ;;
        esac
    done
}

main() {
    check_root
    check_docker

    if [ $# -eq 0 ]; then
        show_menu
    else
        case "$1" in
            --check-status)
                check_status
                ;;
            --avp-start)
                start_avp
                ;;
            --avp-stop)
                stop_avp
                ;;
            --zigbee2mqtt-start)
                start_zigbee
                ;;
            --zigbee2mqtt-stop)
                stop_zigbee
                ;;
            --create-network)
                create_network
                ;;
            *)
                echo "Usage: $0 [--check-status|--avp-start|--avp-stop|--zigbee2mqtt-start|--zigbee2mqtt-stop|--create-network]"
                exit 1
                ;;
        esac
    fi
}

main "$@"