//
//  PersonalTransferFormView.swift
//  KuaiJi
//

import SwiftUI

struct PersonalTransferFormHost: View {
    @StateObject private var viewModel: PersonalTransferFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeTransferFormViewModel())
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalTransferFormView(viewModel: viewModel, onDone: onDismiss)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}

struct PersonalTransferFormView: View {
    @ObservedObject var viewModel: PersonalTransferFormViewModel
    var onDone: () -> Void

    var body: some View {
        Form {
            Section(header: Text(L.personalTransferAccounts.localized)) {
                Picker(L.personalTransferFrom.localized, selection: $viewModel.fromAccountId) {
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(account.remoteId as UUID?)
                    }
                }
                Picker(L.personalTransferTo.localized, selection: $viewModel.toAccountId) {
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(account.remoteId as UUID?)
                    }
                }
            }
            Section(header: Text(L.personalTransferAmount.localized)) {
                TextField(L.personalFieldAmount.localized, text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.amountText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { viewModel.amountText = validated }
                    }
                TextField(L.personalFieldFXRate.localized,
                          text: $viewModel.fxRateText,
                          prompt: Text(viewModel.fxRatePlaceholder).foregroundStyle(.secondary))
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.fxRateText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 6, locale: .current, oldValue: oldValue)
                        if validated != newValue { viewModel.fxRateText = validated }
                    }
                    .disabled(!viewModel.fxRateEditable)
                    .allowsHitTesting(viewModel.fxRateEditable)
                    .opacity(viewModel.fxRateEditable ? 1 : 0.6)
                if viewModel.fxRateEditable {
                    HStack(spacing: 8) {
                        Text(viewModel.fxInfoText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L.personalTransferInvert.localized) {
                            viewModel.invertFXRate()
                        }
                        .font(.caption)
                    }
                }
                TextField(L.personalTransferFee.localized,
                          text: $viewModel.feeText,
                          prompt: Text(viewModel.feePlaceholder).foregroundStyle(.secondary))
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.feeText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { viewModel.feeText = validated }
                    }
                Picker(L.personalTransferFeeSide.localized, selection: $viewModel.selectedFeeSide) {
                    Text(L.personalTransferFeeFrom.localized).tag(PersonalTransferFeeSide.from)
                    Text(L.personalTransferFeeTo.localized).tag(PersonalTransferFeeSide.to)
                }
                Text(L.personalTransferFeeHint.localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                DatePicker(L.personalFieldDate.localized, selection: $viewModel.occurredAt, displayedComponents: [.date, .hourAndMinute])
                TextField(L.personalFieldNote.localized, text: $viewModel.note)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .tint(Color.appTextPrimary)
        .dismissKeyboardOnTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.cancel.localized, action: onDone)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.save.localized) {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
    }
}
