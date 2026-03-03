# full-edge-iot-smart-home-solution

# Network Architecture 

<img width="435" height="746" alt="image" src="https://github.com/user-attachments/assets/6708e7f4-691c-45fc-964e-02f8eb8a8d8b" />


+-------------------------------------------+
|          Internet Gateway (WAN)           |
|             (Ton FAI / Routeur TP-Link)   |
|                   192.168.0.1/24          |
+-------------------------------------------+
                    ↓ (câble Ethernet)
+-----------------------------------------------------------+
|                    VPC: Raspberry Pi 5                    |
|                    (Ubuntu Server LTS on NVMe)            |
|                                                           |
|  +---------------------+     +---------------------+      |
|  | Subnet Public       |     | Subnet IoT Private  |      |
|  | eth0                |     | wlan0 (hostapd AP)  |      |
|  | 192.168.0.151/24    |     | 192.168.200.1/24    |      |
|  | Metric 100          |     | SSID: Pi-IoT        |      |
|  | Internet + LAN      |     | ap_isolate=1        |      |
|  | (Route to IGW)      |     | dnsmasq DHCP        |      |
|  +----------↑----------+     +----------↑----------+      |
|             |                           |                 |
|             |                           ↓                 |
|  +----------|-------------------+  +------------------+   |
|  | Security Group: nftables     |  | Capteurs IoT     |   |
|  | - Policy drop                |  | 192.168.200.50-200|   |
|  | - Forward wlan0 → eth0 NAT   |  | SCD41, BME688...  |   |
|  | - Drop IoT → LAN principal   |  +------------------+   |
|  | - Allow SSH/Grafana via wt0  |                        |
|  +------------------------------+                        |
|                                                           |
|  +---------------------+                                  |
|  | VPN Gateway: wt0    |                                  |
|  | Netbird Mesh        |                                  |
|  | 100.116.35.149/16   |                                  |
|  | Zero-Trust Remote   |                                  |
|  +----------↑----------+                                  |
|             |                                             |
|             ↓                                             |
|  +---------------------+                                  |
|  | Client Devices      |                                  |
|  | (Tablette/Phone/Laptop)                             |
|  | Netbird Client      |                                  |
|  | Accès SSH/Grafana/InfluxDB                          |
|  +---------------------+                                  |
+-----------------------------------------------------------+
