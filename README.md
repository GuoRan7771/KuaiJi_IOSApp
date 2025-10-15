<p align="center">
  <b>Language / 语言 / Langue :</b>
  <b>English</b> |
  <a href="README_CN.md">中文</a> |
  <a href="README_FR.md">Français</a>
</p>

---
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
