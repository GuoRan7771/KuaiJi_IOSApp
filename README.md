<p align="center">
  <b>Language / 语言 / Langue :</b>
  <b>English</b> |
  <a href="README_CN.md">中文</a> |
  <a href="README_FR.md">Français</a>
</p>

---
# 🚀 App Store
> Now available on the App Store! Search “KuaiJi” in English/French, or “快记KuaiJi” in Chinese. Download: https://apps.apple.com/us/app/kuaiji/id6754407498

# KuaiJi  

## Overview

**KuaiJi** is an iOS app for **AA bill-splitting** and **personal bookkeeping**.  
Its goals are simple:  
1. Make group gatherings, trips, and shared apartments free from manual debt calculations.  
2. Help manage your personal finances efficiently.

The app is built entirely with **Swift + SwiftUI**, requires **no server**, and runs fully **offline**.  
However, it still supports **Bluetooth / Wi-Fi** synchronization between devices, providing a kind of “pseudo-distributed” shared experience.  
> The developer simply didn’t want to pay Apple’s USD 99 annual developer fee. ~~(Currently has raised $10 among friends.)~~

> Therefore, CloudKit is not an option — decentralized accounting is the only way!

---

## Key Features

| Module | Description |
|---------|--------------|
| **Personal & Shared Ledgers** | Quickly add expenses with voice input, manual entry, or category tags. |
| **Multi-user Splitting** | One-tap AA split, “I pay,” “They pay,” or fully customized splitting. |
| **Local Network Sync** | Share ledgers with friends over Bluetooth or Wi-Fi without any login. |
| **Fully Local Storage** | All data stays on your device for maximum privacy and security. |
| **Statistics View** | Track monthly and yearly spending trends and category distributions. |
| **Multi-language Support** | English, French, and Chinese. |

---

## How to Use

### Method 1 (Simple)
Visit the main source repository:  
[https://github.com/GuoRan7771/Guo_s_Apps](https://github.com/GuoRan7771/Guo_s_Apps)

### Method 2 (For Developers)

1. Clone the entire project  
2. Open the project directory with **Xcode**  
3. Run it on the simulator or a physical device  

   > Note: Real-device sync requires Bluetooth / Wi-Fi permissions.

---

## Developer Notes

* This is my first project built from scratch, and I’m proud of it — from code to UI to distribution, everything was a challenge I managed to overcome.  
* It’s not on the App Store yet because of a **“decentralized pricing policy”** — I just refuse to pay the USD 99 developer fee for now.  
* I started with some Python and tkinter experience. SwiftUI feels like Apple’s own tkinter — just shinier.  
<details>
<summary>?</summary>
Thanks to my girlfriend for all her silent support behind the scenes! Heyhey 😁
</details>



---

## Recent Updates  
### V4.51(8) – UI Redesign & Feature Consolidation
- **Interface & Navigation:** Moved Friends tab to Shared Ledger for better access; Redesigned Statistics page; Optimized first launch UI.
- **Category Control:** Support changing colors/hiding system categories; More SF symbols for custom icons.
- **Templates:** Added Personal Ledger Templates for quick entry; fully supported in backups.
- **Archiving:** Shared Ledgers now support archiving (swipe to archive); separated "Recent" and "Archived" lists.
- **Backup & Misc:** Enhanced backup to include category settings and templates; Added desktop quick actions; Improved delete confirmations.

### New Improvements V4.33(6)

 - Added support for more currencies  
 - Added detailed usage instructions and the app’s design philosophy  
 - Added more ways to contact the developer and refreshed animations  
 - Improved overall UI visuals  

### V4.3(1)

 - “Clear debts” now syncs in the shared ledger (recommended for all users)  
 - Optional tipping to support the developer — the app stays free and ad-free regardless  
 - “Export personal ledger CSV” page now shows account balances and includes an “Add entry” button  
 - UI polished for English and French

### Bug fixes + new light/dark appearance toggle (2024.10.23, V4.2(1))

 - Adapted the app for light/dark appearance switching  
 - Bug fixes and visual polish  

### Bug fixes, translated V4_1_3.ipa (2024.10.21)

 - Switched Apple ID to export V4_1_3.ipa  

### Bug fixes, but V4_1_2 ipa not exported due to signing (2024.10.21)

 - Fixed French decimal-input issue  
 - Personal ledger edit detail view refreshes instantly  
 - Recent-records list grows from 3 to 5  

### Added More Category Tags (2025.10.15, V4.1(3))

### Feature Freeze – Bug Fixes Only (2025-10-14)

### Major Update (2025-10-10)

 - Added personal ledger: accounts, records, statistics, internal transfers, CSV export and data clearing  
 - Updated settings: personal ledger preferences and default landing page in shared view  
 - UI adjustments  
 - Quick Actions: shortcut access to personal ledger

### Shared Ledger UI Redesign (2025-10-06)

 - All transfer info now displayed on a single screen — no extra pages  
 - Fixed category-selection issues  
 - Added full data export/import for backup and migration  
 - Fixed Shortcut integration for quick ledger access  

### New Feature: Quick Record (2025-10-05)

 - Long-press app icon to open default ledger directly  
 - Fixed translation errors  

---

## License

MIT License — use it freely, just don’t blame me if your data disappears.
