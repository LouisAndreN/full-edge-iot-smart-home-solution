# Input chain (Inbound)

| # | Type | Protocol | Port | Source | Action |
|---|---|---|---|---|---|
| 100 | All traffic | All | All | lo（ループバック） | ✅ ALLOW |
| 200 | All traffic | All | All | established / related | ✅ ALLOW |
| 300 | WireGuard | UDP | 51820 | Any | ✅ ALLOW |
| 400 | SSH | TCP | 22 | 192.168.0.0/24（eth0 LAN） | ✅ ALLOW |
| 500 | SSH | TCP | 22 | wt0（NetBird VPN） | ✅ ALLOW |
| 600 | All traffic | All | All | wlx → 192.168.0.151（eth0 IP） | ❌ DROP |
| 700 | DHCP | UDP | 67 | wlx（IoTサブネット） | ✅ ALLOW |
| 800 | DNS | UDP | 53 | wlx（IoTサブネット） | ✅ ALLOW |
| 900 | ICMP | ICMP | - | Any | ✅ ALLOW（5回/秒） |
| * | All traffic | All | All | Any | ❌ DROP + LOG |

# Forward chain (Outbound IoT strict egress)

| # | Type | Protocol | Port | Source → Destination | Action |
|---|---|---|---|---|---|
| 100 | All traffic | All | All | wlx → 192.168.0.0/24（LAN） | ❌ DROP |
| 200 | NTP | UDP | 123 | wlx → Internet | ✅ ALLOW |
| 300 | HTTPS | TCP | 443 | wlx → Internet | ✅ ALLOW |
| 400 | HTTP | TCP | 80 | wlx → Internet | ✅ ALLOW |
| 500 | ICMP | ICMP | - | wlx → Internet | ✅ ALLOW |
| 600 | All traffic | All | All | eth0 → wlx（established） | ✅ ALLOW |
| 700 | All traffic | All | All | wlx → eth0（その他） | ❌ DROP |
| * | All traffic | All | All | Any | ❌ DROP + LOG |
