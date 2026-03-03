# full-edge-iot-smart-home-solution

# Network Architecture 

```
+─────────────────────────────────────────────────────────────────────+
│                           INTERNET                                  │
│                      (ISP / TP-Link BE220)                          │
+──────────────────────────────┬──────────────────────────────────────+
                               │
                  ┌────────────▼────────────┐
                  │  Internet Gateway (IGW) │
                  │     192.168.0.1/24      │
                  └────────────┬────────────┘
                               │ Ethernet LAN
+──────────────────────────────▼──────────────────────────────────────+
│                                                                      │
│   ┌─ VPC ────────────────────────────────────────────────────────┐  │
│   │              Raspberry Pi 5 — Ubuntu Server 24.04            │  │
│   │         NVMe 1TB | LUKS2+LVM | Hailo-8L Edge AI              │  │
│   │                                                               │  │
│   │  ┌─ Public Subnet ──────────┐  ┌─ Private Subnet (IoT) ───┐  │  │
│   │  │ eth0                     │  │ wlan0                    │  │  │
│   │  │ 192.168.0.151/24         │  │ 192.168.200.1/24         │  │  │
│   │  │ Route: 0.0.0.0 → IGW    │  │ hostapd AP               │  │  │
│   │  │ Metric: 100 (primary)   │  │ SSID: Pi-IoT             │  │  │
│   │  │                          │  │ ap_isolate=1             │  │  │
│   │  │ Services:                │  │ dnsmasq DHCP             │  │  │
│   │  │ ● Mosquitto :1883        │  │ 192.168.200.100-200      │  │  │
│   │  │ ● InfluxDB  :8086        │  └──────────┬───────────────┘  │  │
│   │  │ ● Grafana   :3000        │             │                   │  │
│   │  │ ● Node Exp. :9100        │  ┌──────────▼───────────────┐  │  │
│   │  └──────────────────────────┘  │ IoT Endpoints            │  │  │
│   │                                │ ● BME688  192.168.200.100 │  │  │
│   │  ┌─ Security Group ─────────┐  │ ● SCD41   192.168.200.101 │  │  │
│   │  │ nftables — policy: drop  │  │ ● ...     192.168.200.x  │  │  │
│   │  │                          │  │                           │  │  │
│   │  │ Inbound:                 │  │ ap_isolate=1:            │  │  │
│   │  │ ✓ SSH    wt0/eth0  :22   │  │ no peer-to-peer traffic  │  │  │
│   │  │ ✓ MQTT   wlan0    :1883  │  └──────────────────────────┘  │  │
│   │  │ ✓ Influx wlan0    :8086  │                                 │  │
│   │  │ ✓ Grafana wt0     :3000  │                                 │  │
│   │  │ ✓ WG     *        :51820 │                                 │  │
│   │  │ ✓ DHCP   wlan0    :67    │                                 │  │
│   │  │ ✓ DNS    wlan0    :53    │                                 │  │
│   │  │                          │                                 │  │
│   │  │ Forward:                 │                                 │  │
│   │  │ ✗ IoT → 192.168.0.0/24  │                                 │  │
│   │  │ ✓ IoT → Internet (NAT)  │                                 │  │
│   │  └──────────────────────────┘                                 │  │
│   │                                                               │  │
│   │  ┌─ VPN Gateway ────────────────────────────────────────┐    │  │
│   │  │ NetBird Mesh VPN (wt0)                               │    │  │
│   │  │ 100.116.35.149/16 — WireGuard — Zero-Trust           │    │  │
│   │  └──────────────────────────┬───────────────────────────┘    │  │
│   └─────────────────────────────│─────────────────────────────── ┘  │
+─────────────────────────────────│────────────────────────────────────+
                                  │ WireGuard tunnel (encrypted)
                    +─────────────▼──────────────+
                    │   Client Devices           │
                    │   NetBird Client           │
                    │                            │
                    │  ● Laptop                  │
                    │  ● Phone / Tablet          │
                    │  ● Any new device          │
                    │                            │
                    │  SSH     → :22             │
                    │  Grafana → :3000           │
                    │  InfluxDB→ :8086           │
                    +────────────────────────────+


+─────────────────────────────────────────────────────────────────────+
│                    AWS Cloud — Hybrid Extension                      │
│                                                                      │
│  ┌─ Region ap-northeast-1 (Tokyo) ────────────────────────────────┐ │
│  │                                                                  │ │
│  │  ┌──────────────────┐   MQTT    ┌──────────────────┐           │ │
│  │  │  AWS IoT Core    │ ◄──────── │  Pi5 Edge        │           │ │
│  │  │  Topic routing   │           │  Mosquitto bridge│           │ │
│  │  │  Device shadows  │           └──────────────────┘           │ │
│  │  └────────┬─────────┘                                           │ │
│  │           │                                                      │ │
│  │  ┌────────▼─────────┐           ┌──────────────────┐           │ │
│  │  │  AWS Lambda      │           │  Amazon S3       │           │ │
│  │  │  Event processing│           │  IoT Data Lake   │           │ │
│  │  │  Anomaly detect  │──────────►│  lv-cloud-sync   │           │ │
│  │  └────────┬─────────┘           └──────────────────┘           │ │
│  │           │                                                      │ │
│  │  ┌────────▼─────────┐           ┌──────────────────┐           │ │
│  │  │  SageMaker       │           │  CloudWatch      │           │ │
│  │  │  Model retraining│           │  Metrics + Logs  │           │ │
│  │  │  ONNX → Hailo-8L │           │  Alerts          │           │ │
│  │  └──────────────────┘           └──────────────────┘           │ │
│  │                                                                  │ │
│  │  ┌──────────────────┐                                           │ │
│  │  │  IoT Greengrass  │                                           │ │
│  │  │  Edge runtime    │                                           │ │
│  │  │  Remote deploy   │                                           │ │
│  │  └──────────────────┘                                           │ │
│  │                                                                  │ │
│  │  Infrastructure as Code — Terraform                             │ │
│  └──────────────────────────────────────────────────────────────── ┘ │
+─────────────────────────────────────────────────────────────────────+
```

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

<img width="465" height="682" alt="image" src="https://github.com/user-attachments/assets/45b36f64-a2a3-40fb-b62e-877765c1c3aa" />

+----------------------------------------------+
|                Internet / WAN                |
+----------------------------------------------+
                  ↓ (câble Ethernet)
+----------------------------------------------+
|            Routeur domestique (TP-Link)      |
|            IP: 192.168.0.1/24                |
|            DHCP serveur principal            |
+----------------------------------------------+
                  ↓ eth0 (câble LAN)
+-------------------------------------------------------+
|                  Raspberry Pi 5 (Ubuntu Server)       |
|                                                       |
|  +-------------------+    +-------------------+       |
|  | eth0              |    | wt0 (Netbird)     |       |
|  | 192.168.0.151/24  |    | 100.116.35.149/16 |       |
|  | Metric 100        |    | Mesh VPN Zero-Trust|     |
|  | Internet + LAN    |    | Accès distant      |       |
|  +-------------------+    +-------------------+       |
|          ↑                        ↑                   |
|          |                        |                   |
|   +-------------------+   +-------------------+       |
|   | wlan0 (AP IoT)    |   | Tes appareils     |       |
|   | 192.168.200.1/24  |   | (tablette, phone, |
|   | SSID: Pi-IoT      |   | laptop)           |
|   | DHCP: dnsmasq     |   | - Netbird client  |
|   | ap_isolate=1      |   | - Accès Grafana   |
|   +-------------------+   |   - Accès InfluxDB|
|          ↓                        ↑               |
|   +-------------------+           |               |
|   | Capteurs IoT      |           |               |
|   | 192.168.200.50–200|           |               |
|   | (SCD41, BME688...) |           |               |
|   +-------------------+           |               |
+-------------------------------------------------------+
