| Wi-Fi接続 | 送信元 | 送信先 | コマンド | 期待される結果 |
|-----------|--------|--------|---------|--------------|
| Pi上で実行（eth0） | Pi | インターネット | `ping -c3 -I eth0 8.8.8.8` | ✅ OK |
| Pi-IoT（wlx） | PC | Pi gateway | `ping 192.168.200.1` | ✅ OK |
| Pi-IoT（wlx） | PC | インターネット | `ping 8.8.8.8` | ✅ OK（NAT） |
| Pi-IoT（wlx） | PC | インターネット | `curl -s https://ifconfig.me` | ✅ TP-Link IP |
| Pi-IoT（wlx） | PC | TP-Link | `ping 192.168.0.1` | ❌ DROP |
| Pi-IoT（wlx） | PC | Pi eth0 | `ping 192.168.0.151` | ❌ DROP |
| Pi-IoT（wlx） | PC + スマホ | 互いのIP | `ping 192.168.200.x` | ❌ DROP（ap_isolate） |
| TP-Link（eth0） | PC | Pi | `ssh <user>@192.168.0.151` | ✅ OK |
| TP-Link（eth0） | PC | IoTサブネット | `ping 192.168.200.1` | ❌ timeout |
| Pi上で実行 | Pi | - | `systemctl status hostapd` | ✅ EAPOL-4WAY-HS-COMPLETED |



| テスト | 場所 | コマンド | 期待される結果 |
|--------|------|---------|---------------|
| Unbound動作確認 | Pi上 | `dig google.com @127.0.0.1 -p 5335` | ✅ NOERROR |
| dnsmasq転送確認 | Pi上 | `dig google.com @192.168.200.1` | ✅ NOERROR |
| DNS漏洩なし | Pi上 | `ss -tulpn \| grep :53` | 0.0.0.0:53なし ✅ |
| センサーのDNS解決 | Pi-IoTクライアント | `nslookup google.com` | ✅ 解決成功 |
| インターネット接続 | Pi-IoTクライアント | `ping google.com` / `curl.exe -s https://ifconfig.me` | ✅ 応答あり |



| テスト | 送信元 | 送信先 | 期待される結果 |
|--------|--------|--------|---------------|
| `netbird status` | Pi上 | - | ✅ Connected |
| SSH経由 `wt0`| NetBirdピア | Pi | ✅ OK |
| SSH経由 `eth0` | LAN | Pi | ✅ OK |
| SSH経由 パブリックIP（NetBirdオフ） | スマートフォン（4G） | Pi | ❌ timeout |
| SSH経由 `wt0`（NetBirdオン） | スマートフォン（4G） | Pi | ✅ OK |
| HTTPSアウトバウンド | Pi-IoTクライアント | インターネット | ✅ OK |
| ping 8.8.8.8 | Pi-IoTクライアント | インターネット | ✅ OK |
| ping 192.168.0.1 | Pi-IoTクライアント | TP-Link | ❌ DROP |
| SSH経由 `wlx` | Pi-IoTクライアント | Pi | ❌ DROP |
