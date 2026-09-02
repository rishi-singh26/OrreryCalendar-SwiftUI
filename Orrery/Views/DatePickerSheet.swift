//
//  DatePickerSheet.swift
//  Orrery
//
//  Native graphical DatePicker, bounded to the current cached range (spec §5).
//

import SwiftUI

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let minDate: Date
    let maxDate: Date

    @Environment(DataController.self) private var dataController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { selectedDate },
                    set: { newValue in
                        selectedDate = dataController.clampedDate(newValue)
                    }
                ),
                in: minDate...maxDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .navigationTitle("Choose a date")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 420)
        #endif
    }
}
