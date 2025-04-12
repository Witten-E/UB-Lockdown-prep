# Run this as Administrator

# Allow all traffic from trusted IP (e.g. scoring server or team lead)
New-NetFirewallRule -DisplayName "Allow All from 192.168.4.23" -Direction Inbound -Action Allow -RemoteAddress 192.168.4.23

# LDAP - TCP/UDP 389
New-NetFirewallRule -DisplayName "Allow LDAP TCP" -Direction Inbound -Protocol TCP -LocalPort 389 -Action Allow
New-NetFirewallRule -DisplayName "Allow LDAP UDP" -Direction Inbound -Protocol UDP -LocalPort 389 -Action Allow

# SSH - TCP 22
New-NetFirewallRule -DisplayName "Allow SSH" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow

# Active Directory Common Ports
$adPorts = @(88, 135, 139, 445, 464, 636, 3268, 3269)
foreach ($port in $adPorts) {
    New-NetFirewallRule -DisplayName "Allow AD TCP Port $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
}

# Optional: Set default inbound policy to block (if not already)
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Block

# Optional: Allow outbound by default (common in Windows)
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow

# Display the new rules
Get-NetFirewallRule | Where-Object DisplayName -Like "*Allow*"
