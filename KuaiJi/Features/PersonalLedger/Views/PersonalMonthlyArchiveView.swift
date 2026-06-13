//
//  PersonalMonthlyArchiveView.swift
//  KuaiJi
//

import SwiftUI

struct PersonalMonthlyArchiveView: View {
    @ObservedObject var viewModel: PersonalLedgerHomeViewModel
    var onSelect: (PersonalYearMonth) -> Void

    var body: some View {
        List {
            if viewModel.isLoadingArchive {
                Section(header: Text(L.personalArchiveTitle.localized)) {
                    HStack {
                        ProgressView()
                        Text(L.personalArchiveLoading.localized)
                    }
                }
            } else if viewModel.availableMonths.isEmpty {
                Section(header: Text(L.personalArchiveTitle.localized)) {
                    Text(L.personalArchiveEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text(L.personalArchiveTitle.localized)) {
                    ForEach(viewModel.availableMonths, id: \.id) { ym in
                        Button {
                            onSelect(ym)
                        } label: {
                            HStack {
                                Text(String(format: "%04d-%02d", ym.year, ym.month))
                                    .foregroundStyle(Color.appLedgerContentText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.appLedgerContentText)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(L.personalArchiveTitle.localized)
    }
}
