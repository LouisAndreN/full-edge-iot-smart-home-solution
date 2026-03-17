# Raspberry Pi 5 Edge IoT Gateway - End-to-End Secure Smart Home Solution

End-to-end edge IoT platform built on Raspberry Pi 5 — encrypted NVMe, isolated IoT network, local DNS, Zero-Trust VPN, ML inference, and smart home services.

---

## Architecture Overview

This project reproduces a production-grade cloud architecture locally on a single Raspberry Pi 5.

| AWS Component | This Setup |
|---|---|
| Internet Gateway | TP-Link Router |
| VPC | Raspberry Pi 5 |
| Public Subnet | eth0 (Wired LAN — 192.168.0.0/24) |
| Private Subnet | wlx0013eff27090 (IoT Network — 192.168.200.0/24) |
| NAT Gateway | Raspberry Pi (nftables MASQUERADE / iptables) |
| Security Group / NACL | nftables (stateful, strict egress) |
| KMS / Encrypted EBS | LUKS2 + AES-XTS-512 + Argon2id on NVMe |
| Route 53 Resolver | Unbound (recursive resolver, local) |
| Route 53 Forwarding Rules | dnsmasq (forwarder → Unbound) |
| AWS Client VPN | NetBird (WireGuard-based Zero-Trust VPN) |
| Bastion Host | Pi5 (SSH via wt0, no port forwarding) |
| CloudWatch / Prometheus | Grafana + InfluxDB (planned) |
| SageMaker Edge | Hailo8L (AI inference at the edge) |

---

## Network Architecture
<img width="964" height="452" alt="image" src="https://github.com/user-attachments/assets/5765a860-d238-48d4-8cd5-c0f2bb577d5f" />

<img width="1107" height="596" alt="image" src="https://github.com/user-attachments/assets/db6cee4e-4a4d-498c-bedc-9c5eb0267b8d" />


**Traffic policy:**
- IoT → Internet: HTTPS (443), HTTP (80), NTP (123), ICMP only
- IoT → LAN: **blocked** (nftables DROP)
- IoT ↔ IoT: **blocked** (ap_isolate layer 2)
- Internet → IoT: **impossible** (NAT + no port forwarding)
- Remote SSH: via NetBird P2P only (no open ports)

---

## Stack

| Layer | Technology | Status |
|---|---|---|
| Storage | LUKS2 + LVM + Btrfs/XFS/ext4 | ✅ Done |
| Network isolation | hostapd + nftables + dnsmasq | ✅ Done |
| Local DNS | Unbound + dnsmasq | ✅ Done |
| Zero-Trust VPN | NetBird (WireGuard) | ✅ Done |
| Security | CrowdSec + Authelia + mTLS | 🔄 Planned |
| SSO | Microsoft Authenticator | 🔄 Planned |
| Observability | Grafana + InfluxDB + Prometheus + Loki | 🔄 Planned |
| IoT messaging | MQTT (Mosquitto) | 🔄 Planned |
| AI inference | Hailo8L (Edge ML) | 🔄 Planned |
| Smart home | Home Assistant | 🔄 Planned |
| EMS / NILM | Custom module (electrical panel) | 🔄 Planned |

---

## Hardware

| Component | Model |
|---|---|
| SBC | Raspberry Pi 5 (8GB) |
| NVMe | Micron 2200 1TB |
| NVMe adapter | SunFounder Dual NVMe Raft (PCIe Gen2) |
| AI accelerator | Hailo8L |
| Wi-Fi adapter | Realtek RTL88x2BU (USB, AP mode) |
| Router | TP-Link |

**NVMe performance (PCIe Gen2 bottleneck):**
- Read: IOPS=3162, BW=395 MiB/s
- Write: IOPS=2992, BW=374 MiB/s

---

## Repository Structure

```
full-edge-iot-smart-home-solution/
├── README.md
├── LICENSE
│
├── 01-storage/
│   ├── README.md                        ← lien article Qiita #0
│   ├── configs/
│   │   ├── etc/
│   │   └── mnt/
│   ├── partitionning_architecture.txt
│   ├── setup_commands.sh                ← script NVMe setup
│   └── verify-boot.sh                   ← validation post-boot
│
├── 02-network/
│   ├── README.md                        ← liens articles Qiita #1 #2 #3
│   ├── hostapd/
│   │   ├── hostapd.conf
│   │   └── override.conf                ← systemd override
│   ├── nftables/
│   │   └── nftables.conf
│   ├── dnsmasq/
│   │   ├── dnsmasq.conf
│   │   └── override.conf                ← systemd override
│   ├── unbound/
│   │   └── pi-iot.conf
│   └── netplan/
│       └── 10-network.yaml
│
├── 03-security/                         ← CrowdSec, Authelia, mTLS
│   └── README.md
│
├── 04-observability/                    ← Grafana, InfluxDB, Prometheus, Loki
│   └── README.md
│
├── 05-iot/                              ← MQTT, ESP32 firmware
│   ├── README.md
│   ├── mqtt/
│   ├── esp32/
│   └── nilm/                            ← EMS/NILM module
│
└── 06-auth/                             ← Authelia SSO, Microsoft Authenticator
    └── README.md
```

---

## Storage Layout (NVMe)

| Partition / LV | Size | FS | Mount | Description |
|---|---|---|---|---|
| nvme0n1p1 | 1 GB | vfat | /boot/firmware | Ubuntu boot |
| nvme0n1p2 | 100 GB | ext4 | / | OS + AI frameworks (Hailo SDK, PyTorch) |
| nvme0n1p3 | 16 GB | swap | swap (encrypted) | ML/Hailo swap (2× RAM) |
| nvme0n1p4 | 5 GB | ext4 | /recovery | Emergency rescue (LUKS header backup, repair tools) |
| nvme0n1p5 | 838 GB | LUKS2 | cryptdata | AES-XTS-512 + Argon2id encryption |
| ├─ lv-var | 20 GB | ext4 | /var | System cache |
| ├─ lv-logs | 30 GB | ext4 | /var/log | IoT + service logs (7-day rotation) |
| ├─ lv-influxdb | 120 GB | xfs | /var/lib/influxdb | IoT time series DB |
| ├─ lv-containers | 80 GB | xfs | /var/lib/containers | Docker (HA, MQTT, Grafana) |
| ├─ lv-grafana | 10 GB | ext4 | /var/lib/grafana | Dashboards |
| ├─ lv-ml-models | 60 GB | xfs | /mnt/ml-models | Hailo models (production/staging/archived) |
| ├─ lv-ml-cache | 40 GB | xfs | /mnt/ml-cache | ML training data + TensorBoard logs |
| ├─ lv-cloud-sync | 80 GB | xfs | /mnt/cloud-sync | S3/Azure sync queue (pending/uploading/failed) |
| ├─ lv-scratch | 60 GB | xfs | /mnt/scratch | Preprocessing buffer (camera, electrical signatures) |
| └─ lv-data | 340 GB | btrfs | /mnt/data | IoT data, archives, backups, personal |

**LUKS features:**
- Encryption: AES-XTS-512
- KDF: Argon2id
- Two keyslots: passphrase + keyfile
- Keyfile backup: AWS S3 / Azure Blob (encrypted, versioned)
- Btrfs incremental cloud sync via snapshot send/receive

---

## Qiita Article Series (日本語)

| # | Title | Status |
|---|---|---|
| 0 | [Pi5 NVMe暗号化セットアップ（LUKS2暗号化 + Argon2id + LVM + Btrfs + ヘッドレスブート対応）](https://qiita.com/LouisAndreN/items/1ace35f6a9e915686fe4) | ✅ Published |
| 1 | IoT隔離ネットワーク（hostapd + nftables） | ✅ Published |
| 2 | ローカルDNSリゾルバでDNS漏洩を防ぐ（Unbound + dnsmasq） | ✅ Published |
| 3 | Zero-TrustリモートアクセスVPN（NetBird + SSH） | ✅ Published |
| 4 | セキュリティ強化（CrowdSec + Authelia） | 🔄 Planned |
| 5 | 観測性（Grafana + InfluxDB + Prometheus + Loki） | 🔄 Planned |
| 6 | IoTセンサー統合（ESP32 + MQTT） | 🔄 Planned |
| 7 | EMS/NILMモジュール | 🔄 Planned |

---

## Security Model

- **Default DROP** on all chains (input, forward)
- **IoT network completely isolated** from home LAN at layer 2 (ap_isolate) and layer 3 (nftables)
- **DNS exfiltration prevented** — Unbound resolves directly from root servers, no external DNS
- **No open ports** on router — SSH only accessible via NetBird P2P tunnel
- **Strict egress** on IoT subnet — only HTTPS/HTTP/NTP/ICMP allowed outbound
- **Full disk encryption** — LUKS2 AES-XTS-512 with Argon2id KDF

---

## Quick Start

See [`01-storage/README.md`](01-storage/README.md) for NVMe setup.
See [`02-network/README.md`](02-network/README.md) for network configuration.

> ⚠️ Replace all placeholders (`<passphrase>`, `<wt0_ip>`, `<interface>`) with your own values before use.

