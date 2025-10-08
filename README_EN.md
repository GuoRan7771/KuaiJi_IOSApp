<p align="center">
  🌐 <b>Language:</b>
  <a href="README.md">中文</a> |
  <b>English</b> |
  <a href="README_FR.md">Français</a>
</p>

---

# KuaiJi  

## Introduction

**KuaiJi** is an iOS app designed for **bill splitting (AA system)** and **personal bookkeeping**.  
Its goal is simple: stop using calculators when hanging out, traveling, or sharing rent with friends.  

The project is built entirely with **Swift + SwiftUI**, runs **locally without a server**,  
yet still allows **Bluetooth / Wi-Fi** synchronization of ledgers — offering a kind of *“pseudo-distributed”* sharing experience.  
> In fact, the developer just didn’t want to pay Apple’s $99 annual developer fee. ~~(Raised $10 so far from friends)~~

> So CloudKit was never an option — decentralized accounting was the only way!

---

## Features

| Module | Description |
|---------|-------------|
| **Bookkeeping** | Quickly add expenses via voice or manual input, with category tags. |
| **Group Splitting** | One-tap AA, treat, be treated, or custom split modes. |
| **Local Sync** | Share ledgers with friends via Bluetooth or Wi-Fi, no login required. |
| **Offline Storage** | All data stays on your device for maximum privacy. |
| **Statistics View** | Track spending trends and category distribution by month or year. |
| **Decentralized Identity** | Each user has a unique ID for cross-device ledger matching. |

---

## How to Use

1. Clone or download this project  
   ```bash
   git clone https://github.com/GuoRan7771/KuaiJi_IOSApp.git
   cd KuaiJi_IOSApp

2. Open with **Xcode** (`.xcodeproj` or `.xcworkspace`)
3. Run on simulator or real device

   > Real-device sync requires Bluetooth / Wi-Fi access
4. Create a ledger and invite friends
5. Start recording expenses, let it auto-settle, and enjoy never miscalculating again 😌

---

## Developer Notes

> “I just wrote it casually, and somehow it actually works 😎”

* “Full-stack” here means I bullied AI into writing everything.
* Not on App Store due to “decentralized pricing policy”: **no $99**.
* I only knew some Python and Tkinter before, but Apple’s UI is basically Tkinter with gradients.

---

## Recent Updates

### Shared Ledger UI Update (2025-10-06)

All transfer details now fit on one screen  
Fixed category tap bug  
Added full data export/import in Settings for backup and migration  
Fixed Shortcut launch issue for default ledger  

### New Feature: Quick Add (2025-10-05)

Long-press app icon to open default ledger’s add-expense view
Fixed translation issues

---

## License

MIT License — use freely, just don’t blame me for lost data.

---
