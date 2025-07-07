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
                    clearAllNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    clearAllNotifications()
                }
        }
    }
    
    private func clearAllNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Clear all delivered notifications from the notification center
        center.removeAllDeliveredNotifications()
        
        // Clear all pending notifications
        center.removeAllPendingNotificationRequests()
        
        // Clear the app badge count
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
