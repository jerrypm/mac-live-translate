//
//  HistorySection.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Scrollable list of finalized utterances (Chinese + English) with
//  per-row delete and a Clear-all action. Empty state shown when no
//  entries exist yet.
//

import SwiftUI

struct HistorySection: View {

    let entries: [TranslationEntry]
    let onDelete: (UUID) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.small) {
            header
            if entries.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Strings.UI.historyTitle).font(.headline)
            if !entries.isEmpty {
                Text(String(format: Strings.UI.historyCountFormat, entries.count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !entries.isEmpty {
                Button(Strings.UI.historyClearAll, action: onClearAll)
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(.tint)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.Spacing.small) {
                ForEach(entries) { entry in
                    HistoryRow(entry: entry, onDelete: { onDelete(entry.id) })
                }
            }
        }
        .frame(maxHeight: Metrics.Size.historyMaxHeight)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text(Strings.UI.historyEmpty)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Metrics.Spacing.small)
    }
}

// MARK: - Row

private struct HistoryRow: View {

    let entry: TranslationEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Spacing.medium) {
            chineseColumn
            Divider().frame(minHeight: 32)
            englishColumn
            deleteButton
        }
        .padding(Metrics.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: Metrics.Corner.pill)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    /// Chinese characters with pinyin pronunciation underneath, so the user
    /// can still read aloud entries they previously captured.
    private var chineseColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.chineseText)
                .font(.body)
            let pinyin = entry.chineseText.pinyinDisplay
            if !pinyin.isEmpty {
                Text(pinyin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var englishColumn: some View {
        Text(entry.englishText)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: Metrics.Size.historyRowDeleteButton)
        .help(Strings.UI.historyDelete)
    }
}
