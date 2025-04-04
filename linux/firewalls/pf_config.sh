#! /bin/sh

# pf_config.sh - Manage packet filter
# reference: https://man.openbsd.org/pfctl

usage() {
    echo "Usage: $0 [-s] [-l <filename>] [-r] [-b <ip>]"
    echo "  -s              Start pf"
    echo "  -l <filename>   Load firewalls from file"
    echo "  -r              Show current pf rules"
    echo "  -b <ip>         Block ip"
    exit 0
}

# Check correct file
check_pf_file() {
    # Check that rule file is created
    if $(! -f /etc/pf.conf); then
        echo "creating config"
        touch /etc/pf.conf
        service pf start
    fi

    # Double check using correct rule file
    if $(! sysrc pf_rules | grep -q "/etc/pf.conf"); then
        echo "reset pfSense conf"
        sysrc pf_rules="/etc/pf.conf"
    fi
}

# Check pf is enabled
check_pf_on() {
    # Enable PF
    if $(! sysrc pf_enable | grep -q "YES"); then
        echo "enabled pfSense"
        sysrc pf_enable="YES"
    fi

    # Check file exists
    check_pf_file

    # Enable
    pfctl -e
}

# Load rules from file
load_file_rules() {    
    # Put rule file in
    cat '$1' | tee /etc/pf.conf

    # Flush existing rules, and load newly created rules
    pfctl -F all -f /etc/pf.conf
}

# Get current rules
get_rules() {
    pfctl -sr
}

# Block ip
# To delete a block, run 'pfctl -t blocked -T delete <ip>'
block_ip() {
    pfctl -t blocked -T add '$1'
    pfctl -t blocked -T show
}

# Parse options with getopts
while getopts ":srf:b:" opt; do
    case "${opt}" in
        s)
            check_pf_on
            ;;
        l)
            check_pf_file
            load_file_rules "${OPTARG}"
            get_rules
            ;;
        r)
            get_rules
            ;;
        b)
            block_ip "${OPTARG}"
        *)
            usage
            ;;
    esac
    found=true
done

# If no flags were provided
if [ -z "$found" ]; then
    usage
fi