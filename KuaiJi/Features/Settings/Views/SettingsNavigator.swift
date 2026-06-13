//
//  SettingsNavigator.swift
//  KuaiJi
//

import SwiftUI

struct SettingsNavigator: View {
    @ObservedObject var viewModel: SettingsScreenModel
    @ObservedObject var rootViewModel: AppRootViewModel
    @ObservedObject var personalLedgerRoot: PersonalLedgerRootViewModel
    @StateObject private var personalSettingsModel: PersonalLedgerSettingsViewModel
    
    init(viewModel: SettingsScreenModel, rootViewModel: AppRootViewModel, personalLedgerRoot: PersonalLedgerRootViewModel) {
        self.viewModel = viewModel
        self.rootViewModel = rootViewModel
        self.personalLedgerRoot = personalLedgerRoot
        _personalSettingsModel = StateObject(wrappedValue: personalLedgerRoot.makeSettingsViewModel())
    }
    
    var body: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel,
                        rootViewModel: rootViewModel,
                        personalSettingsViewModel: personalSettingsModel,
                        personalLedgerRoot: personalLedgerRoot)
        }
        .background(Color.appBackground)
    }
}
