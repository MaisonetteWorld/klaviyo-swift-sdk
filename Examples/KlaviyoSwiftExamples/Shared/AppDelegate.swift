//
//  AppDelegate.swift
//  KlaviyoSwift
//
//  Created by Katy Keuper on 10/05/2015.
//  Copyright (c) 2015 Katy Keuper. All rights reserved.
//

// STEP1: Importing klaviyo SDK into your app code
import KlaviyoSwift
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: - Private members

    private var email: String? {
        UserDefaults.standard.object(forKey: "email") as? String
    }

    private var zip: String? {
        UserDefaults.standard.object(forKey: "zip") as? String
    }

    // MARK: App delegates

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = getFirstViewController
        window?.makeKeyAndVisible()

        // STEP2: Setup Klaviyo SDK with api key
        Klaviyo.setupWithPublicAPIKey(apiKey: "magpcN")

        // EXAMPLE: of how to track an event
        Klaviyo.sharedInstance.trackEvent(eventName: "Opened kLM App")

        // STEP3: register the user email with klaviyo so there is an unique way to identify your app user.
        if let email = email {
            Klaviyo.sharedInstance.setUpUserEmail(userEmail: email)
        }

        // STEP4: Setting up push notifcations
        howToSetupPushNotifications()

        return true
    }

    // MARK: Push Notification implementation

    private func howToSetupPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        // use the below options if you are interested in using provisional push notifications. Note that using this will not
        // show the push notifications prompt to the user.
        // let options: UNAuthorizationOptions = [.alert, .sound, .badge, provisional]
        center.requestAuthorization(options: options) { _, error in
            if let error = error {
                // Handle the error here.
                print("error = ", error)
            }

            // Enable or disable features based on the authorization status.
        }

        UIApplication.shared.registerForRemoteNotifications()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // STEP5: add the push device token to your Klaviyo user profile.
        Klaviyo.sharedInstance.addPushDeviceToken(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error) {
        if error._code == 3010 {
            print("push notifications are not supported in the iOS simulator")
        } else {
            print("application:didFailToRegisterForRemoteNotificationsWithError: \(error)")
        }
    }

    // STEP6: Let Klaviyo SDK know when the user receives a push notification
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if application.applicationState == UIApplication.State.inactive ||
            application.applicationState == UIApplication.State.background {
            Klaviyo.sharedInstance.handlePush(userInfo: userInfo as NSDictionary)
        }
        completionHandler(.noData)
    }

    // MARK: Deep linking implementation

    // If you would like to support deep links the following delegate needs to be implemented
    // it's upto the developer to decide what to do with the URL in this method.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host
        else {
            print("Invalid deeplinking URL")
            return false
        }

        print("components: \(components.debugDescription)")

        // Create the deep link
        guard let deeplink = DeepLinking(rawValue: host) else {
            print("Deeplink not found: \(host)")
            return false
        }

        handle(deeplink, with: url.description)

        return true
    }

    // MARK: private methods

    private var getFirstViewController: UIViewController {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
        if let zip = zip,
           let email = email {
            guard let menuVC = mainStoryboard.instantiateViewController(withIdentifier: "menuVC") as? MenuPageViewController
            else {
                fatalError("missing menu vc in storyboard or storyboard identifier not matching")
            }
            menuVC.email = email
            menuVC.zip = zip

            return menuVC

        } else {
            // show login page
            guard let firstVC = mainStoryboard.instantiateViewController(withIdentifier: "loginVC") as? ViewController
            else {
                fatalError("missing login vc in storyboard or storyboard identifier not matching")
            }

            return firstVC
        }
    }

    private func handle(_ deepLink: DeepLinking, with url: String) {
        switch deepLink {
        case .home:
            // this is where we could present the home view
            break
        case .menu:
            // this is where we could present the menu view
            break
        case .checkout:
            // this is where we could present the checkout view
            break

        case .debug:
            // sending debug should show the deeplink URL in code
            let debugViewController = DebugViewController()
            debugViewController.debugMessage = url
            let navigation = UINavigationController(rootViewController: debugViewController)
            window?.rootViewController?.dismiss(animated: true)
            window?.rootViewController?.present(navigation, animated: true)
        }
    }
}

// MARK: App delegate extensions

// STEP7: Add this extension on AppDelegate for additional push notifications handling
extension AppDelegate: UNUserNotificationCenterDelegate {
    // below method will be called when the user interacts with the push notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        Klaviyo.sharedInstance.handlePush(userInfo: response.notification.request.content.userInfo as NSDictionary)
        completionHandler()
    }

    // below method is called when the app receives push notifications when the app is the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.list, .banner])
        } else {
            completionHandler([.alert])
        }
    }
}
