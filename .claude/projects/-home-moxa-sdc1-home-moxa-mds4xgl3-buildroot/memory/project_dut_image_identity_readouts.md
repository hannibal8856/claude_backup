---
name: project_dut_image_identity_readouts
description: /etc/moxa/version/BUILD_TIME 才是 image 身分;/etc/os-release 的 VERSION 是寫著 EDS-G4100 的死標籤
metadata: 
  node_type: memory
  type: project
  originSessionId: 543288d9-63d4-40ca-a311-1a8b83f5414d
  modified: 2026-08-13T05:52:57.877Z
---

2026-08-13 差點據此得出「DUT 被換成 EDS 了」這個完全錯誤的結論。

## 正確讀數

```
/etc/moxa/version/BUILD_TIME     2026_0813_0905      ← image 身分
/etc/moxa/version/FWR_VERSION
/tmp/modelName                   MDS-G4012-L3-4XGS-T ← 機種
/proc/device-tree/model          Moxa MDS with Marvell PonCat3 Family
```

## 陷阱

```
DUT /etc/os-release              VERSION=EDS-G4100_v0.1_2026_0611_0159
MDS image 自己的 .config 檔頭      # Buildroot EDS-G4100_v0.1_2026_0611_0159 Configuration
                                 BR2_LINUX_KERNEL_INTREE_DTS_NAME="armada-370-moxa-mds-g4000-4xgs"
```

**MDS 建置樹帶著一個沒人更新的 Buildroot 版本字串**,它會被寫進 `/etc/os-release`。
機種證據是 DTS,不是這個字串。**`/etc/os-release` 的 VERSION 既不能判斷機種、也不能判斷 image。**

燒錄後一定要用 `BUILD_TIME` 確認跑的是新 image —— 靜默失敗的更新會讓後面所有數字來自錯的 image。

## 順帶

- CPU 實際是 **Marvell PJ4B(implementer 0x56, part 0x584)、ARMv7 32-bit**,
  與 `CLAUDE.md` 寫的「Marvell CN9130 / Cortex-A9」對不上(CN9130 是 Cortex-A72 aarch64)。
- **DUT 上沒有 `timeout` 指令**。
- DUT 系統時鐘是錯的(`/tmp` 的檔案日期停在 May 12),**不能用時間戳對齊 pcap 與 DUT 日誌**。

相關:[[project_dut_dual_image_ab_pair]]
