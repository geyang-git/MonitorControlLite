//  Copyright © MonitorControlLite. @waydabber

import Cocoa
import Foundation
import HAP
import Logging
import Darwin

let storage = FileStorage(filename: "configuration.json")

let DEBUG_VIRTUAL = false
let DEBUG_MACOS10 = false
let DEBUG_GAMMA_ENFORCER = false

let MIN_PREVIOUS_BUILD_NUMBER = 1

var app: AppDelegate!
var menu: MenuHandler!

let prefs = UserDefaults.standard
let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
let displaysPrefsVc = storyboard.instantiateController(withIdentifier: "DisplaysPrefsVC") as? DisplaysPrefsViewController
let menuslidersPrefsVc = storyboard.instantiateController(withIdentifier: "MenuslidersPrefsVC") as? MenuslidersPrefsViewController
let keyboardPrefsVc = storyboard.instantiateController(withIdentifier: "KeyboardPrefsVC") as? KeyboardPrefsViewController
let aboutPrefsVc = storyboard.instantiateController(withIdentifier: "AboutPrefsVC") as? AboutPrefsViewController

fileprivate let logger = Logger(label: "bridge")
LoggingSystem.bootstrap(createLogHandler)

// Define two light bulb accessories.
//let livingRoomLightbulb = Accessory.Lightbulb(info: Service.Info(name: "Living Room", serialNumber: "00002"),isDimmable:true)
//let bedroomNightStand = Accessory.Lightbulb(info: Service.Info(name: "Bedroom", serialNumber: "00003"),isDimmable:true)

// Attach those to the bridge device.
let device = Device(
        bridgeInfo: Service.Info(name: "Macbook Pro 16", serialNumber: "00001"),
        setupCode: "123-44-321",
        storage: storage,
        accessories: [])

// Attach a delegate that logs all activity.
var delegate = LoggingDeviceDelegate(logger: logger)
device.delegate = delegate

// Attach device to a server handling networking.
let server = try Server(device: device)

logger.info("Initializing the server...")

//// Toggle the lights every 5 seconds.
//let timer = DispatchSource.makeTimerSource()
//timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(5))
//timer.setEventHandler(handler: {
////    livingRoomLightbulb.lightbulb.powerState.value = !(livingRoomLightbulb.lightbulb.powerState.value ?? false)
////  随机亮度 int
//  livingRoomLightbulb.lightbulb.brightness?.value = Int.random(in: 0...100)
//})
//timer.resume()

delegate.printPairingInstructions()

autoreleasepool { () -> Void in
    let mc = NSApplication.shared
    let mcDelegate = AppDelegate()
    mc.delegate = mcDelegate
    mc.run()
}
