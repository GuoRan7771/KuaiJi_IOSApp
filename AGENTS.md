# KuaiJi Project Map

## Entry Points

- `KuaiJi/App/Lifecycle/KuaiJiApp.swift`: App bootstrap, model container setup, app state, and delegates.
- `KuaiJi/App/Root/ContentView.swift`: Main tab shell only. It wires Personal Ledger, Shared Ledger, and Settings tabs.
- `KuaiJi/App/Intents/`: App Intents and shortcut bridge.

## Shared Ledger

- `KuaiJi/Features/SharedLedger/Models/`: SwiftData domain models, view data, export DTOs, and presentation helpers.
- `KuaiJi/Features/SharedLedger/Services/`: Shared-ledger persistence, import/export, and quick-add helpers.
- `KuaiJi/Features/SharedLedger/ViewModels/`: Root view model, screen models, and protocols.
- `KuaiJi/Features/SharedLedger/Views/`: Navigation, ledger lists, overview, member/expense/settlement entry views, and management sheets.
- `KuaiJi/Features/SharedLedger/Stats/`: Shared-ledger statistics UI and category presentation.

## Personal Ledger

- `KuaiJi/Features/PersonalLedger/Views/PersonalLedgerNavigator.swift`: Personal-ledger route enum and navigator.
- `KuaiJi/Features/PersonalLedger/Models/`: Personal view data, store input/snapshot types, and presentation helpers.
- `KuaiJi/Features/PersonalLedger/ViewModels/`: Root and home view models.
- `KuaiJi/Features/PersonalLedger/Records/`: Record form, all-records view, and related view models.
- `KuaiJi/Features/PersonalLedger/Accounts/`: Account list/form views and view models.
- `KuaiJi/Features/PersonalLedger/Templates/`: Template list/form views and view models.
- `KuaiJi/Features/PersonalLedger/Transfers/`: Transfer form view and view model.
- `KuaiJi/Features/PersonalLedger/Stats/`: Personal statistics views and view models.
- `KuaiJi/Features/PersonalLedger/Categories/`: Category settings, edit sheets, and category settings view model.
- `KuaiJi/Features/PersonalLedger/Export/`: CSV export view and view model.
- `KuaiJi/Features/PersonalLedger/Services/`: Core `PersonalLedgerStore` plus import/export and analytics extensions.

## Other Features

- `KuaiJi/Features/Settings/Views/`: Settings, contact, support, and settings navigation views.
- `KuaiJi/Features/Settings/ViewModels/`: Settings state and import/export orchestration.
- `KuaiJi/Features/Sync/`: Multipeer connectivity, sync engine/models, and nearby-device UI.
- `KuaiJi/Features/Friends/QRCode/`: Friend QR generation and scanning views.
- `KuaiJi/Features/Onboarding/Views/`: Onboarding, welcome guide, usage guide, and avatar picker.
- `KuaiJi/Features/Support/Services/`: App review prompts and StoreKit manager.

## Shared Infrastructure

- `KuaiJi/Shared/Foundation/`: Small foundation helpers such as logging, parsing, and amount formatting.
- `KuaiJi/Shared/Localization/`: Locale preference and localization key access.
- `KuaiJi/Shared/Feedback/`: Haptics and celebration overlay.
- `KuaiJi/Shared/UI/`: Small app-wide SwiftUI/UIKit helpers such as keyboard dismissal and `onChange` compatibility.
- `KuaiJi/Shared/UI/Styling/`: Theme colors, styles, and color conversion helpers.

## Refactor Rules

- Keep business logic, persistence keys, localization keys, colors, modifiers, and gesture ordering unchanged.
- Prefer moving complete types or complete extension responsibilities.
- For SwiftData store changes, run at least:
  `xcodebuild -project KuaiJi.xcodeproj -scheme KuaiJi -destination 'generic/platform=iOS' build`
