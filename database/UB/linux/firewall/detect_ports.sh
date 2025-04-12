#!/bin/bash
#
# A simple script that scans for listening ports and
# adds a firewall rule command to an output script to then
# be run by the user.
output_script="open_ports_rules.sh"

echo "[*] Scanning for listening TCP/UDP ports..."
echo "#!/bin/bash" > "$output_script"
echo "# Generated on $(date)" >> "$output_script"
echo "" >> "$output_script"

# Detect TCP ports
tcp_ports=$(ss -tnl | awk 'NR>1 {split($4,a,":"); print a[length(a)]}' | sort -n | uniq)

# Detect UDP ports
udp_ports=$(ss -unl | awk 'NR>1 {split($4,a,":"); print a[length(a)]}' | sort -n | uniq)

# Write rules for TCP ports
for port in $tcp_ports; do
    echo "nft add rule inet filter input tcp dport $port accept" >> "$output_script"
done

# Write rules for UDP ports
for port in $udp_ports; do
    echo "nft add rule inet filter input udp dport $port accept" >> "$output_script"
done

chmod +x "$output_script"

echo "[+] Rules written to $output_script"
echo "    Run './$output_script' to apply them."

