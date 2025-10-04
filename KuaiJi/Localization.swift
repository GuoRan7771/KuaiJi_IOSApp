//
//  Localization.swift
//  KuaiJi
//
//  本地化字符串辅助
//

import Foundation
import SwiftUI

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    func localized(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: args)
    }
}

// 本地化键常量
enum L {
    // 通用
    static let ok = "ok"
    static let cancel = "cancel"
    static let done = "done"
    static let save = "save"
    static let delete = "delete"
    static let edit = "edit"
    static let close = "close"
    static let add = "add"
    static let all = "all"
    
    // Tab Bar
    static let tabLedgers = "tab.ledgers"
    static let tabFriends = "tab.friends"
    static let tabSettings = "tab.settings"
    
    // 账本列表
    static let ledgersTitle = "ledgers.title"
    static let ledgersPageTitle = "ledgers.pageTitle"
    static let ledgersNew = "ledgers.new"
    static let ledgersRecentUpdates = "ledgers.recentUpdates"
    static let ledgersMemberCount = "ledgers.memberCount"
    static let ledgersOutstanding = "ledgers.outstanding"
    
    // 创建账本
    static let createLedgerTitle = "createLedger.title"
    static let createLedgerInfo = "createLedger.ledgerInfo"
    static let createLedgerName = "createLedger.ledgerName"
    static let createLedgerCurrency = "createLedger.currency"
    static let createLedgerMembers = "createLedger.members"
    static let createLedgerSelectFriends = "createLedger.selectFriends"
    static let createLedgerSelectedCount = "createLedger.selectedCount"
    static let createLedgerCreate = "createLedger.create"
    static let createLedgerMe = "createLedger.me"
    
    // 账本详情
    static let ledgerTotalSpent = "ledger.totalSpent"
    static let ledgerMembers = "ledger.members"
    static let ledgerNetAmount = "ledger.netAmount"
    static let ledgerAddExpense = "ledger.addExpense"
    static let ledgerViewRecords = "ledger.viewRecords"
    static let ledgerGeneratePlan = "ledger.generatePlan"
    static let ledgerMember = "ledger.member"
    static let ledgerBalances = "ledger.balances"
    
    // 添加支出
    static let expenseTitle = "expense.title"
    static let expenseBasicInfo = "expense.basicInfo"
    static let expensePurpose = "expense.purpose"
    static let expensePurposePlaceholder = "expense.purposePlaceholder"
    static let expenseDate = "expense.date"
    static let expenseAmount = "expense.amount"
    static let expenseCategory = "expense.category"
    static let expenseParticipants = "expense.participants"
    static let expenseNoMembers = "expense.noMembers"
    static let expenseSplitMethod = "expense.splitMethod"
    static let expensePreview = "expense.preview"
    
    // 分账方式
    static let splitMeAllAA = "split.meAllAA"
    static let splitMeAllAADesc = "split.meAllAA.desc"
    static let splitOtherAllAA = "split.otherAllAA"
    static let splitOtherAllAADesc = "split.otherAllAA.desc"
    static let splitMeTreat = "split.meTreat"
    static let splitMeTreatDesc = "split.meTreat.desc"
    static let splitOtherTreat = "split.otherTreat"
    static let splitOtherTreatDesc = "split.otherTreat.desc"
    static let splitHelpPay = "split.helpPay"
    static let splitHelpPayDesc = "split.helpPay.desc"
    static let splitPayer = "split.payer"
    static let splitSelectPayer = "split.selectPayer"
    static let splitBeneficiary = "split.beneficiary"
    static let splitSelectBeneficiary = "split.selectBeneficiary"
    static let splitAddOtherMembers = "split.addOtherMembers"
    
    // 分类
    static let categoryFood = "category.food"
    static let categoryTransport = "category.transport"
    static let categoryAccommodation = "category.accommodation"
    static let categoryEntertainment = "category.entertainment"
    static let categoryUtilities = "category.utilities"
    static let categoryOther = "category.other"
    
    // 结算
    static let settlementTitle = "settlement.title"
    static let settlementCurrentNet = "settlement.currentNet"
    static let settlementMinTransfers = "settlement.minTransfers"
    static let settlementAllSettled = "settlement.allSettled"
    static let settlementTransfer = "settlement.transfer"
    
    // 流水记录
    static let recordsTitle = "records.title"
    static let recordsEmpty = "records.empty"
    static let recordsEmptyDesc = "records.emptyDesc"
    
    // 朋友
    static let friendsTitle = "friends.title"
    static let friendsAdd = "friends.add"
    static let friendsInfo = "friends.info"
    static let friendsName = "friends.name"
    static let friendsCurrency = "friends.currency"
    static let friendsSelectAvatar = "friends.selectAvatar"
    static let friendsAddTitle = "friends.addTitle"
    static let friendsEditTitle = "friends.editTitle"
    
    // 设置
    static let settingsTitle = "settings.title"
    static let settingsLanguage = "settings.language"
    static let settingsLanguageLabel = "settings.languageLabel"
    static let settingsLanguageDesc = "settings.languageDesc"
    static let settingsAbout = "settings.about"
    static let settingsGuide = "settings.guide"
    static let settingsContactMe = "settings.contactMe"
    static let settingsClearData = "settings.clearData"
    static let settingsClearDataWarning = "settings.clearDataWarning"
    static let settingsConfirmDelete = "settings.confirmDelete"
    static let settingsDeleteMessage = "settings.deleteMessage"
    
    // 语言选项
    static let languageSystem = "language.system"
    static let languageChinese = "language.chinese"
    static let languageEnglish = "language.english"
    static let languageFrench = "language.french"
    
    // 联系页面
    static let contactAuthor = "contact.author"
    static let contactEmail = "contact.email"
    
    // 首次设置
    static let onboardingTitle = "onboarding.title"
    static let onboardingDescription = "onboarding.description"
    static let onboardingNameSection = "onboarding.nameSection"
    static let onboardingNamePlaceholder = "onboarding.namePlaceholder"
    static let onboardingNameFooter = "onboarding.nameFooter"
    static let onboardingCurrencySection = "onboarding.currencySection"
    static let onboardingCurrencyPicker = "onboarding.currencyPicker"
    static let onboardingCurrencyFooter = "onboarding.currencyFooter"
    static let onboardingAvatarSection = "onboarding.avatarSection"
    static let onboardingCurrentAvatar = "onboarding.currentAvatar"
    static let onboardingAvatarFooter = "onboarding.avatarFooter"
    static let onboardingAllEmojis = "onboarding.allEmojis"
    static let onboardingStartButton = "onboarding.startButton"
    static let onboardingCompleteFooter = "onboarding.completeFooter"
    static let onboardingErrorTitle = "onboarding.errorTitle"
    static let onboardingErrorMessage = "onboarding.errorMessage"
    
    // 个人资料
    static let profileTitle = "profile.title"
    static let profileEdit = "profile.edit"
    static let profileViewInfo = "profile.viewInfo"
    static let profileName = "profile.name"
    static let profileNamePlaceholder = "profile.namePlaceholder"
    static let profileNameFooter = "profile.nameFooter"
    static let profileCurrency = "profile.currency"
    static let profileCurrencyPicker = "profile.currencyPicker"
    static let profileAvatar = "profile.avatar"
    static let profileCurrentAvatar = "profile.currentAvatar"
    static let profileAvatarFooter = "profile.avatarFooter"
    static let profileUserIdLabel = "profile.userIdLabel"
    static let profileCurrencyLabel = "profile.currencyLabel"
    
    // 二维码
    static let qrcodeMyTitle = "qrcode.myTitle"
    static let qrcodeScanInstruction = "qrcode.scanInstruction"
    static let qrcodeScannerTitle = "qrcode.scannerTitle"
    static let qrcodeScannerInstruction = "qrcode.scannerInstruction"
    static let qrcodeScanError = "qrcode.scanError"
    static let qrcodeInvalidFormat = "qrcode.invalidFormat"
    static let qrcodeCannotAddSelf = "qrcode.cannotAddSelf"
    static let qrcodeAlertTitle = "qrcode.alertTitle"
    static let qrcodeCameraError = "qrcode.cameraError"
    static let qrcodeCameraInitError = "qrcode.cameraInitError"
    static let qrcodeCameraInputError = "qrcode.cameraInputError"
    static let qrcodeMetadataOutputError = "qrcode.metadataOutputError"
    
    // 朋友菜单
    static let friendMenuManualInput = "friendMenu.manualInput"
    static let friendMenuMyQRCode = "friendMenu.myQRCode"
    static let friendMenuScanQRCode = "friendMenu.scanQRCode"
    
    // 账本页面卡片
    static let ledgerCardTotalExpenses = "ledger.card.totalExpenses"
    static let ledgerCardMemberExpenses = "ledger.card.memberExpenses"
    static let ledgerCardRecentRecords = "ledger.card.recentRecords"
    static let ledgerCardAllButton = "ledger.card.allButton"
    static let ledgerCardNoRecords = "ledger.card.noRecords"
    static let ledgerCardMemberTotalSpent = "ledger.card.memberTotalSpent"
    static let ledgerCardViewTransferPlan = "ledger.card.viewTransferPlan"
    static let ledgerCardClearBalances = "ledger.card.clearBalances"
    
    // 清账功能
    static let clearBalancesConfirmTitle = "clearBalances.confirmTitle"
    static let clearBalancesConfirmMessage = "clearBalances.confirmMessage"
    static let clearBalancesConfirmButton = "clearBalances.confirmButton"
    
    // 所有成员页面
    static let allMembersTitle = "allMembers.title"
    static let allMembersTotalSpent = "allMembers.totalSpent"
    
    // 支出验证
    static let expenseValidationMinAmount = "expense.validation.minAmount"
    static let expenseOptionalFields = "expense.optionalFields"
    
    // 默认值
    static let defaultUnknown = "default.unknown"
    static let defaultUnknownMember = "default.unknownMember"
    static let defaultUntitledExpense = "default.untitledExpense"
    static let defaultPreview = "default.preview"
    static let defaultNewLedger = "default.newLedger"
    static let defaultClearBalanceTransfer = "default.clearBalanceTransfer"
    static let defaultClearBalanceNote = "default.clearBalanceNote"
    
    // 数据同步
    static let syncTitle = "sync.title"
    static let syncImportantWarning = "sync.importantWarning"
    static let syncWarningTitle = "sync.warningTitle"
    static let syncWarningMessage = "sync.warningMessage"
    static let syncWarningConfirm = "sync.warningConfirm"
    static let syncWarningConfirmNoRemind = "sync.warningConfirmNoRemind"
    static let syncWarning1 = "sync.warning1"
    static let syncWarning2 = "sync.warning2"
    static let syncWarning3 = "sync.warning3"
    static let syncWarning4 = "sync.warning4"
    static let syncRecommendation = "sync.recommendation"
    static let syncStatus = "sync.status"
    static let syncDiscovering = "sync.discovering"
    static let syncNotStarted = "sync.notStarted"
    static let syncConnectedDevices = "sync.connectedDevices"
    static let syncNearbyDevices = "sync.nearbyDevices"
    static let syncNoDevicesFound = "sync.noDevicesFound"
    static let syncConnect = "sync.connect"
    static let syncStartDiscovery = "sync.startDiscovery"
    static let syncStopDiscovery = "sync.stopDiscovery"
    static let syncStartSync = "sync.startSync"
    static let syncConfirmStart = "sync.confirmStart"
    static let syncResultTitle = "sync.resultTitle"
    static let syncMenuTitle = "sync.menuTitle"
    static let syncResultAddedLedgers = "sync.result.addedLedgers"
    static let syncResultUpdatedLedgers = "sync.result.updatedLedgers"
    static let syncResultAddedExpenses = "sync.result.addedExpenses"
    static let syncResultAddedFriends = "sync.result.addedFriends"
    static let syncResultErrors = "sync.result.errors"
    static let syncResultNoUpdates = "sync.result.noUpdates"
    static let syncDeviceAvailable = "sync.deviceAvailable"
    static let syncDeviceConnected = "sync.deviceConnected"
    static let syncCurrentDevice = "sync.currentDevice"
    static let syncShareLedger = "sync.shareLedger"
    static let syncCompleted = "sync.completed"
    static let syncWaitingResponse = "sync.waitingResponse"
    static let syncBidirectionalComplete = "sync.bidirectionalComplete"
    static let syncReceivedFrom = "sync.receivedFrom"
    static let syncSentBack = "sync.sentBack"
    static let syncSendBackError = "sync.sendBackError"
    static let syncErrorPreparing = "sync.errorPreparing"
    static let syncErrorEncoding = "sync.errorEncoding"
    static let syncErrorInvalidData = "sync.errorInvalidData"
    
    // 欢迎引导
    static let guideWelcomeTitle = "guide.welcome.title"
    static let guideWelcomeDesc = "guide.welcome.desc"
    static let guideFriendsTitle = "guide.friends.title"
    static let guideFriendsDesc = "guide.friends.desc"
    static let guideLedgerTitle = "guide.ledger.title"
    static let guideLedgerDesc = "guide.ledger.desc"
    static let guideSyncTitle = "guide.sync.title"
    static let guideSyncDesc = "guide.sync.desc"
    static let guidePrivacyTitle = "guide.privacy.title"
    static let guidePrivacyDesc = "guide.privacy.desc"
    static let guideSkip = "guide.skip"
    static let guideNext = "guide.next"
    static let guidePrevious = "guide.previous"
    static let guideStart = "guide.start"
    // 引导页面视觉元素
    static let guideScanQRCode = "guide.scanQRCode"
    static let guideBecomeFriends = "guide.becomeFriends"
    static let guideExampleTrip = "guide.exampleTrip"
    static let guideExampleDinner = "guide.exampleDinner"
    static let guideYourDevice = "guide.yourDevice"
    static let guideFriendDevice = "guide.friendDevice"
    static let guideLocalStorage = "guide.localStorage"
    static let guideNoServer = "guide.noServer"
    static let guideFullyPrivate = "guide.fullyPrivate"
}


