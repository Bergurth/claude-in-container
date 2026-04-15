#!/bin/bash
# VPN startup script for security container

VPN_CONFIG="/vpn/configs/client.ovpn"
VPN_CREDS="/vpn/configs/creds.txt"
VPN_LOG="/vpn/logs/connection.log"

# Function to start VPN
start_vpn() {
    echo "🔒 Starting VPN connection..."

    # Check if config exists
    if [[ ! -f "$VPN_CONFIG" ]]; then
        echo "❌ VPN config not found at $VPN_CONFIG"
        return 1
    fi

    # Create log directory
    mkdir -p /vpn/logs

    # Start OpenVPN in background
    if [[ -f "$VPN_CREDS" ]]; then
        echo "🔑 Using credential file: $VPN_CREDS"
        openvpn --config "$VPN_CONFIG" --auth-user-pass "$VPN_CREDS" --daemon --log "$VPN_LOG"
    else
        echo "🔑 No credential file found, using interactive auth"
        openvpn --config "$VPN_CONFIG" --daemon --log "$VPN_LOG"
    fi

    # Wait for connection
    echo "⏳ Waiting for VPN connection..."
    for i in {1..30}; do
        if ip route | grep -q tun0; then
            echo "✅ VPN connected successfully!"
            echo "📊 VPN Interface:"
            ip addr show tun0 2>/dev/null || echo "   tun0 interface details not available"
            echo "🌐 New routing table:"
            ip route | head -5
            return 0
        fi
        sleep 2
        echo -n "."
    done

    echo "❌ VPN connection failed or timed out"
    echo "📋 Check logs: tail -f $VPN_LOG"
    return 1
}

# Function to check VPN status
check_vpn() {
    if ip route | grep -q tun0; then
        VPN_IP=$(ip addr show tun0 2>/dev/null | grep -oP 'inet \K[^/]+' | head -1)
        echo "✅ VPN Active - IP: ${VPN_IP:-unknown}"
        echo "📍 Testing connectivity to internal network..."

        # Test ping to common internal ranges
        for subnet in "10.20.20.0/24" "192.168.1.0/24"; do
            gateway=$(ip route | grep "$subnet" | awk '{print $3}' | head -1)
            if [[ -n "$gateway" ]]; then
                echo "   📡 Testing $subnet gateway: $gateway"
                if ping -c 1 -W 2 "$gateway" >/dev/null 2>&1; then
                    echo "   ✅ $gateway reachable"
                else
                    echo "   ⚠️  $gateway not responding"
                fi
            fi
        done
    else
        echo "❌ VPN not connected"
        return 1
    fi
}

# Function to stop VPN
stop_vpn() {
    echo "🛑 Stopping VPN connection..."
    pkill -f openvpn
    sleep 2
    echo "✅ VPN disconnected"
}

# Main execution
case "${1:-start}" in
    start)
        start_vpn
        ;;
    stop)
        stop_vpn
        ;;
    status)
        check_vpn
        ;;
    restart)
        stop_vpn
        sleep 2
        start_vpn
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac