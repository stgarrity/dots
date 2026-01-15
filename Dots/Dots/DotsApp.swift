//
//  DotsApp.swift
//  Dots
//
//  Created by Steve Garrity on 5/15/25.
//

import SwiftUI
import UserNotifications

@main
struct DotsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    clearDeliveredNotifications()
                }
        }
    }
    
    private func clearDeliveredNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Clear only delivered notifications from notification center
        // This removes the badge and notifications that have already been shown
        // but keeps the scheduled future notifications intact
        center.removeAllDeliveredNotifications()
    }
}
