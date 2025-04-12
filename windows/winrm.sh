# Run this in an elevated (Administrator) PowerShell window

# --- WinRM (Windows Remote Management) ---
# HTTP (port 5985)
New-NetFirewallRule -DisplayName "Allow WinRM HTTP (5985)" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow

# HTTPS (port 5986)
New-NetFirewallRule -DisplayName "Allow WinRM HTTPS (5986)" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow

# --- ICMP (Ping) ---
# Echo Request (IPv4)
New-NetFirewallRule -DisplayName "Allow ICMPv4-In (Ping)" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow

# Echo Request (IPv6) – if you're using IPv6
New-NetFirewallRule -DisplayName "Allow ICMPv6-In (Ping)" -Protocol ICMPv6 -IcmpType 128 -Direction Inbound -Action Allow

# Confirm rules created
Get-NetFirewallRule | Where-Object DisplayName -like "*WinRM*" -or DisplayName -like "*ICMP*"
