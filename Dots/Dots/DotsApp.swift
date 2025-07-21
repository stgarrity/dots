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
                    clearOutstandingNotifications()
                }
        }
    }
    
    private func clearOutstandingNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Clear all pending notification requests
        center.removeAllPendingNotificationRequests()
        
        // Clear all delivered notifications from notification center
        center.removeAllDeliveredNotifications()
    }
}
