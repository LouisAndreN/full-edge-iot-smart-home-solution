# NVMe Encrypted Setup on Raspberry Pi 5 for Edge IoT/ML 

This project provides an optimized configuration and partitionning system on a 1 TB NVMe, booted on Raspberry Pi 5, mounted with SunFounder Dual NVMe Raft PCIe adapter, optimized for orchestration of Edge AI devices, ML models and other ervices for an advanced smart home.
It uses Ubuntu Server LTS 24.04.3 and tested on NVMe Micron 2200. After running write and read test speed, I get the following performances :

- read: IOPS=3162, BW=395MiB/s (414MB/s) 
- write: IOPS=2992, BW=374MiB/s (392MB/s)

PCIe Gen2 Bottleneck appears despite Pi5 forcing PCIe Gen3, adapter path limits negotiation to Gen2.

The script `/opt/verify-boot.sh` is generated automatically during the installation and launched manually after the first boot on NVMe to validate all mounts LUKS, LVM, FS tuning, TRIM, etc.

- Encrypted save of LUKS keyfile on AWS S3/Azure Blob with rsync with rotation and versioning
- Incremental save Btrfs lv-data to cloud through snapshots send/receive with lv-cloud-sync

The partitionning system is made as follows :

| Partition / LV          | Size     | FSType | Mount Point / Name                  | Utility / Description                                                                |
|-------------------------|----------|--------|-------------------------------------|--------------------------------------------------------------------------------------|
| nvme0n1p1               | 1 GB     | vfat   | /boot/firmware                      | Ubuntu boot + multiple kernels                                                       |
| nvme0n1p2               | 100 GB   | ext4   | /                                   | OS + libs + AI frameworks (Hailo SDK, PyTorch)  |
| nvme0n1p3               | 16 GB    | swap   | swap (encrypted)                    | Dedicated Swap ML/Hailo (2× RAM, except LVM for performances)                        |
| nvme0n1p4               | 5 GB     | ext4   | /recovery                           | Emergency rescue : Backup LUKS header + scripts repair + mini-tools (cryptsetup, lvm2, btrfs-progs, ddrescue) |
| nvme0n1p5               | 838 GB   | LUKS   | cryptdata (encrypted)               | LUKS encryption                                                                      |
| ├─ vg-main              | 838 GB   | LVM    | Volume Group                        | Group LVM Volume on cryptdata                                                        |
| ├─ lv-var               | 20 GB    | ext4   | /var                                | System cache (APT, systemd, tmp)                                                     |
| ├─ lv-logs              | 30 GB    | ext4   | /var/log                            | Logs ESP32 + HA + Influx + cloud ops (7 days rotation, persistant journald)          |
| ├─ lv-influxdb          | 120 GB   | xfs    | /var/lib/influxdb                   | IoT Timeseries |
| ├─ lv-containers        | 80 GB    | xfs    | /var/lib/containers                 | Docker (HA, MQTT, Grafana, Prometheus – except DB)          |
| ├─ lv-grafana           | 10 GB    | ext4   | /var/lib/grafana                    | Dashboards                                        |
| ├─ lv-ml-models         | 60 GB    | xfs    | /mnt/ml-models                      | production/ (active models Hailo)<br>staging/ (A/B testing)<br>archived/ (rollback)<br>datasets/ (training data local edge) |
| ├─ lv-ml-cache          | 40 GB    | xfs    | /mnt/ml-cache                       | staging/ (validation SageMaker-like)<br>training_data/ (export cloud)<br>logs/ (TensorBoard, ML metrics) |
| ├─ lv-cloud-sync        | 80 GB    | xfs    | /mnt/cloud-sync                     | pending/ (Influx export in progress)<br>uploading/ (upload S3/Azure in progress)<br>uploaded/ (success, retention 7d)<br>failed/ (retry + Prometheus alerts) |
| ├─ lv-scratch           | 60 GB    | xfs    | /mnt/scratch                        | Buffer preprocessing (nowcasting camera images, device electrical signatures)        |
| ├─ lv-data              | 340 GB   | btrfs  | /mnt/data                           | @iot-hot/ (active data 7-30d, quota 100 GiB)<br>@iot-archives (long term multi-year, compression zstd:3 max)<br>@backups (exported snapshots LVM, send/receive to cloud)<br>@personal (docs, source code) |


---


## How to install

Flash a SD card (max 64GB) with Ubuntu Server LTS with Raspberry Pi Imager. Plug the SD card and the NVMe on the Pi 5 and boot on the SD card.
Connect by SSH on the Pi.
Open the setup_commands.sh file and execute all the commands one by one to setup the NVMe.
Once done, shutdown the Pi 5 and remove only the SD card.
Now the Pi should boot Ubuntu Server on the NVMe and you can connect to it by SSH.

---

# 日本語

本プロジェクトは、Raspberry Pi 5 において 1TB NVMe を使用した最適化された構成およびパーティション管理システムを提供します。
NVMe は SunFounder Dual NVMe Raft PCIe アダプターにより接続され、Edge AI デバイス、機械学習モデル、および高度なスマートホーム向け各種サービスのオーケストレーションに最適化されています。

本システムは Ubuntu Server LTS 24.04.3 を使用し、Micron 2200 NVMe にて動作検証を行っています。
読み書き速度テストの結果は以下の通りです。

read: IOPS=3162, BW=395MiB/s (414MB/s)
write: IOPS=2992, BW=374MiB/s (392MB/s)

Raspberry Pi 5 は PCIe Gen3 を強制設定していますが、アダプター経路の制限によりネゴシエーションが Gen2 に制限されるため、PCIe Gen2 がボトルネックとなっています。

/opt/verify-boot.sh スクリプトはインストール時に自動生成され、NVMe からの初回起動後に手動で実行します。
これにより、LUKS、LVM、ファイルシステムのチューニング、TRIM など、すべてのマウント状態を検証します。

主な機能：

・LUKS キーファイルの暗号化バックアップを AWS S3 / Azure Blob に rsync を用いて保存（ローテーションおよびバージョニング対応）
・Btrfs lv-data のインクリメンタルバックアップをスナップショットの send/receive 機能によりクラウドへ同期（lv-cloud-sync）

パーティション構成は以下の通りです。

| Partition / LV          | Size     | FSType | Mount Point / Name                  | 用途 / 説明                                                                |
|-------------------------|----------|--------|-------------------------------------|--------------------------------------------------------------------------------------|
| nvme0n1p1               | 1 GB     | vfat   | /boot/firmware                      | Ubuntu ブート領域（複数カーネル対応）                                                       |
| nvme0n1p2               | 100 GB   | ext4   | /                                   |  OS、ライブラリ、AI フレームワーク（Hailo SDK、PyTorch）  |
| nvme0n1p3               | 16 GB    | swap   | swap (encrypted)                    | 専用スワップ（ML/Hailo 用、RAM の 2 倍）                       |
| nvme0n1p4               | 5 GB     | ext4   | /recovery                           | 緊急復旧領域（LUKS ヘッダバックアップ、修復スクリプト、cryptsetup / lvm2 / btrfs-progs / ddrescue 等） |
| nvme0n1p5               | 838 GB   | LUKS   | cryptdata (encrypted)               | LUKS 暗号化領域                                                                     |
| ├─ vg-main              | 838 GB   | LVM    | Volume Group                        | 上の LVM ボリュームグループ                                                       |
| ├─ lv-var               | 20 GB    | ext4   | /var                                | システムキャッシュ（APT、systemd、tmp）                                                    |
| ├─ lv-logs              | 30 GB    | ext4   | /var/log                            | ESP32、Home Assistant、Influx、クラウド操作ログ（7日ローテーション）         |
| ├─ lv-influxdb          | 120 GB   | xfs    | /var/lib/influxdb                   | IoT 時系列データベース |
| ├─ lv-containers        | 80 GB    | xfs    | /var/lib/containers                 | Docker（HA、MQTT、Grafana、Prometheus 等）          |
| ├─ lv-grafana           | 10 GB    | ext4   | /var/lib/grafana                    | Grafana ダッシュボード                                        |
| ├─ lv-ml-models         | 60 GB    | xfs    | /mnt/ml-models                      | production/（稼働中モデル Hailo）　staging/（A/B テスト）　archived/（ロールバック用）　datasets/（ローカル学習データ） |
| ├─ lv-ml-cache          | 40 GB    | xfs    | /mnt/ml-cache                       | staging/（検証環境 SageMaker 類似）　training_data/（クラウド送信用データ）logs/（TensorBoard、ML メトリクス） |
| ├─ lv-cloud-sync        | 80 GB    | xfs    | /mnt/cloud-sync                     | pending/（Influx エクスポート待ち）　uploading/（S3 / Azure アップロード中）　uploaded/（成功データ、7日保持）　failed/（再試行 + Prometheus アラート） |
| ├─ lv-scratch           | 60 GB    | xfs    | /mnt/scratch                        | 前処理用バッファ（カメラ画像解析、デバイス電力シグネチャ解析など）      |
| ├─ lv-data              | 340 GB   | btrfs  | /mnt/data                           | @iot-hot（アクティブデータ 7〜30日、100GiB クォータ）　@iot-archives（長期保存、zstd:3 圧縮）　@backups（LVM スナップショットのクラウド送信）　@personal（ドキュメント、ソースコード） |


## インストール方法

1. Raspberry Pi Imager を使用し、Ubuntu Server LTS を SD カード（最大 64GB）に書き込みます。
2. SD カードと NVMe を Raspberry Pi 5 に接続し、SD カードから起動します。
3. SSH で Raspberry Pi に接続します。
4. setup_commands.sh を開き、記載されているコマンドを順番に実行して NVMe の設定を行います。
5. 設定完了後、Raspberry Pi 5 をシャットダウンし、SD カードのみ取り外します。
6. その後、NVMe から Ubuntu Server が起動し、SSH で接続できるようになります。


詳細な手順は [Qiita記事](https://qiita.com/LouisAndreN/items/1ace35f6a9e915686fe4) をご覧ください。

---



