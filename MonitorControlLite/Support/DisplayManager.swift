//  Copyright © MonitorControlLite. @waydabber

import Cocoa
import CoreGraphics
import os.log
import HAP

class DisplayManager {
  public static let shared = DisplayManager()

  var displays: [Display] = []
  let gammaActivityEnforcer = NSWindow(contentRect: .init(origin: NSPoint(x: 0, y: 0), size: .init(width: DEBUG_GAMMA_ENFORCER ? 15 : 1, height: DEBUG_GAMMA_ENFORCER ? 15 : 1)), styleMask: [], backing: .buffered, defer: false)
  var gammaInterferenceCounter = 0
  var gammaInterferenceWarningShown = false

  func createGammaActivityEnforcer() {
    self.gammaActivityEnforcer.title = "Monior Control Gamma Activity Enforcer"
    self.gammaActivityEnforcer.isMovableByWindowBackground = false
    self.gammaActivityEnforcer.backgroundColor = DEBUG_GAMMA_ENFORCER ? .red : .black
    self.gammaActivityEnforcer.ignoresMouseEvents = true
    self.gammaActivityEnforcer.level = .screenSaver
    self.gammaActivityEnforcer.orderFrontRegardless()
    self.gammaActivityEnforcer.collectionBehavior = [.stationary, .canJoinAllSpaces]
    os_log("Gamma activity enforcer created.", type: .info)
  }

  func enforceGammaActivity() {
    if self.gammaActivityEnforcer.alphaValue == 1 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01) {
      self.gammaActivityEnforcer.alphaValue = 2 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01)
    } else {
      self.gammaActivityEnforcer.alphaValue = 1 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01)
    }
  }

  func moveGammaActivityEnforcer(displayID: CGDirectDisplayID) {
    if let screen = DisplayManager.getByDisplayID(displayID: DisplayManager.resolveEffectiveDisplayID(displayID)) {
      self.gammaActivityEnforcer.setFrameOrigin(screen.frame.origin)
    }
    self.gammaActivityEnforcer.orderFrontRegardless()
  }

  internal var shades: [CGDirectDisplayID: NSWindow] = [:]
  internal var shadeGrave: [NSWindow] = []

  func isDisqualifiedFromShade(_ displayID: CGDirectDisplayID) -> Bool {
    if CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0 {
      if displayID == DisplayManager.resolveEffectiveDisplayID(displayID), DisplayManager.isVirtual(displayID: displayID) || DisplayManager.isDummy(displayID: displayID) {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displayIDs, &displayCount) == .success else {
          return true
        }
        for displayId in displayIDs where CGDisplayMirrorsDisplay(displayId) == displayID && !DisplayManager.isVirtual(displayID: displayID) {
          return true
        }
        return false
      }
      return true
    }
    return false
  }

  internal func createShadeOnDisplay(displayID: CGDirectDisplayID) -> NSWindow? {
    if let screen = DisplayManager.getByDisplayID(displayID: displayID) {
      let shade = NSWindow(contentRect: .init(origin: NSPoint(x: 0, y: 0), size: .init(width: 10, height: 1)), styleMask: [], backing: .buffered, defer: false)
      shade.title = "Monitor Control Window Shade for Display " + String(displayID)
      shade.isMovableByWindowBackground = false
      shade.backgroundColor = .clear
      shade.ignoresMouseEvents = true
      shade.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
      shade.orderFrontRegardless()
      shade.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
      shade.setFrame(screen.frame, display: true)
      shade.contentView?.wantsLayer = true
      shade.contentView?.alphaValue = 0.0
      shade.contentView?.layer?.backgroundColor = .black
      shade.contentView?.setNeedsDisplay(shade.frame)
      os_log("Window shade created for display %{public}@", type: .info, String(displayID))
      return shade
    }
    return nil
  }

  func getShade(displayID: CGDirectDisplayID) -> NSWindow? {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return nil
    }
    if let shade = shades[displayID] {
      return shade
    } else {
      if let shade = self.createShadeOnDisplay(displayID: displayID) {
        self.shades[displayID] = shade
        return shade
      }
    }
    return nil
  }

  func destroyAllShades() -> Bool {
    var ret = false
    for displayID in self.shades.keys {
      os_log("Attempting to destory shade for display  %{public}@", type: .info, String(displayID))
      if self.destroyShade(displayID: displayID) {
        ret = true
      }
    }
    if ret {
      os_log("Destroyed all shades.", type: .info)
    } else {
      os_log("No shades were found to be destroyed.", type: .info)
    }
    return ret
  }

  func destroyShade(displayID: CGDirectDisplayID) -> Bool {
    if let shade = shades[displayID] {
      os_log("Destroying shade for display %{public}@", type: .info, String(displayID))
      self.shadeGrave.append(shade)
      self.shades.removeValue(forKey: displayID)
      shade.close()
      return true
    }
    return false
  }

  func updateShade(displayID: CGDirectDisplayID) -> Bool {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return false
    }
    if let screen = DisplayManager.getByDisplayID(displayID: displayID) {
      if let shade = getShade(displayID: displayID) {
        shade.setFrame(screen.frame, display: true)
        return true
      }
    }
    return false
  }

  func getShadeAlpha(displayID: CGDirectDisplayID) -> Float? {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return 1
    }
    if let shade = getShade(displayID: displayID) {
      return Float(shade.contentView?.alphaValue ?? 1)
    } else {
      return 1
    }
  }

  func setShadeAlpha(value: Float, displayID: CGDirectDisplayID) -> Bool {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return false
    }
    if let shade = getShade(displayID: displayID) {
      shade.contentView?.alphaValue = CGFloat(value)
      return true
    }
    return false
  }

  func configureDisplays() {
    self.clearDisplays()
    delegate.injectDisplayManager(displayManager: self)
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success else {
      os_log("Unable to get display list.", type: .info)
      return
    }
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      let name = DisplayManager.getDisplayNameByID(displayID: onlineDisplayID)
      let id = onlineDisplayID
      let vendorNumber = CGDisplayVendorNumber(onlineDisplayID)
      let modelNumber = CGDisplayModelNumber(onlineDisplayID)
      let serialNumber = CGDisplaySerialNumber(onlineDisplayID)
      let isDummy: Bool = DisplayManager.isDummy(displayID: onlineDisplayID)
      let isVirtual: Bool = DisplayManager.isVirtual(displayID: onlineDisplayID)
      let otherDisplay = Display(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
      os_log("Other display found - %{public}@", type: .info, "ID: \(otherDisplay.identifier), Name: \(otherDisplay.name) (Vendor: \(otherDisplay.vendorNumber ?? 0), Model: \(otherDisplay.modelNumber ?? 0))")
      self.addDisplay(display: otherDisplay)
    }
  }

  func setupOtherDisplays(firstrun: Bool = false) {
    for otherDisplay in self.getAllDisplays() {
      otherDisplay.setupCurrentAndMaxValues(command: .brightness, firstrun: firstrun)
      otherDisplay.brightnessSyncSourceValue = otherDisplay.readPrefAsFloat(for: .brightness)
    }
  }

  func normalizedName(_ name: String) -> String {
    var normalizedName = name.replacingOccurrences(of: "(", with: "")
    normalizedName = normalizedName.replacingOccurrences(of: ")", with: "")
    normalizedName = normalizedName.replacingOccurrences(of: " ", with: "")
    for i in 0 ... 9 {
      normalizedName = normalizedName.replacingOccurrences(of: String(i), with: "")
    }
    return normalizedName
  }

  func getAllDisplays() -> [Display] {
    return self.displays
  }

  func getBuiltInDisplay() -> Display? {
    return self.displays.first { CGDisplayIsBuiltin($0.identifier) != 0 }
  }

  func getCurrentDisplay(byFocus: Bool = false) -> Display? {
    if byFocus {
      guard let mainDisplayID = NSScreen.main?.displayID else {
        return nil
      }
      return self.displays.first { $0.identifier == mainDisplayID }
    } else {
      let mouseLocation = NSEvent.mouseLocation
      let screens = NSScreen.screens
      if let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }) {
        return self.displays.first { $0.identifier == screenWithMouse.displayID }
      }
      return nil
    }
  }

  func addDisplay(display: Display) {
    // 检查是否在列表中
    if !self.displays.contains(where: { $0.identifier == display.identifier }) {
      let livingRoomLightbulb = Accessory.Lightbulb(info: Service.Info(name: display.name, serialNumber: String(display.identifier)),isDimmable:true)
      device.addAccessories([livingRoomLightbulb])
      display.bindAccessory(livingRoomLightbulb)
    }
    self.displays.append(display)
  }

  // 根据id获取display
  func getByDisplayID(displayID: CGDirectDisplayID) -> Display? {
      return self.displays.first { $0.identifier == displayID }
  }

  func clearDisplays() {
    self.displays = []
  }

  func addDisplayCounterSuffixes() {
    var nameDisplays: [String: [Display]] = [:]
    for display in self.displays {
      if nameDisplays[display.name] != nil {
        nameDisplays[display.name]?.append(display)
      } else {
        nameDisplays[display.name] = [display]
      }
    }
    for nameDisplayKey in nameDisplays.keys where nameDisplays[nameDisplayKey]?.count ?? 0 > 1 {
      for i in 0 ... (nameDisplays[nameDisplayKey]?.count ?? 1) - 1 {
        if let display = nameDisplays[nameDisplayKey]?[i] {
          display.name = "" + display.name + " (" + String(i + 1) + ")"
        }
      }
    }
  }

  func resetSwBrightnessForAllDisplays(prefsOnly: Bool = false, noPrefSave: Bool = false, async: Bool = false) {
    for otherDisplay in self.getAllDisplays() {
      if !prefsOnly {
        _ = otherDisplay.setSwBrightness(1, smooth: async, noPrefSave: noPrefSave)
        if !noPrefSave {
          otherDisplay.smoothBrightnessTransient = 1
        }
      } else if !noPrefSave {
        otherDisplay.savePref(1, key: .SwBrightness)
        otherDisplay.smoothBrightnessTransient = 1
      }
      if otherDisplay.isSw(), !noPrefSave {
        otherDisplay.savePref(1, for: .brightness)
      }
    }
  }

  func restoreSwBrightnessForAllDisplays(async: Bool = false) {
    for otherDisplay in self.getAllDisplays() {
      if otherDisplay.isSw() {
        let savedPrefValue = otherDisplay.readPrefAsFloat(key: .SwBrightness)
        otherDisplay.savePref(otherDisplay.getSwBrightness(), key: .SwBrightness)
        os_log("Restoring sw brightness to %{public}@ on other display %{public}@", type: .info, String(savedPrefValue), String(otherDisplay.identifier))
        _ = otherDisplay.setSwBrightness(savedPrefValue, smooth: async)
        if otherDisplay.isSw(), let slider = otherDisplay.sliderHandler[.brightness] {
          os_log("Restoring sw slider to %{public}@ for other display %{public}@", type: .info, String(savedPrefValue), String(otherDisplay.identifier))
          slider.setValue(savedPrefValue, displayID: otherDisplay.identifier)
        }
      } else {
        _ = otherDisplay.setSwBrightness(1)
      }
    }
  }

  func getAffectedDisplays(isBrightness: Bool = false) -> [Display]? {
    var affectedDisplays: [Display]
    let allDisplays = self.getAllDisplays()
    var currentDisplay: Display?
    if isBrightness {
      if prefs.integer(forKey: PrefKey.multiKeyboardBrightness.rawValue) == MultiKeyboardBrightness.allScreens.rawValue {
        affectedDisplays = allDisplays
        return affectedDisplays
      }
      currentDisplay = self.getCurrentDisplay(byFocus: prefs.integer(forKey: PrefKey.multiKeyboardBrightness.rawValue) == MultiKeyboardBrightness.focusInsteadOfMouse.rawValue)
    }
    if let currentDisplay = currentDisplay {
      affectedDisplays = [currentDisplay]
      if CGDisplayIsInHWMirrorSet(currentDisplay.identifier) != 0 || CGDisplayIsInMirrorSet(currentDisplay.identifier) != 0, CGDisplayMirrorsDisplay(currentDisplay.identifier) == 0 {
        for display in allDisplays where CGDisplayMirrorsDisplay(display.identifier) == currentDisplay.identifier {
          affectedDisplays.append(display)
        }
      }
    } else {
      affectedDisplays = []
    }
    return affectedDisplays
  }

  static func isDummy(displayID: CGDirectDisplayID) -> Bool {
    let rawName = DisplayManager.getDisplayNameByID(displayID: displayID)
    var isDummy: Bool = false
    if rawName.lowercased().contains("dummy") {
      os_log("NOTE: Display is a dummy!", type: .info)
      isDummy = true
    }
    return isDummy
  }

  static func isVirtual(displayID: CGDirectDisplayID) -> Bool {
    var isVirtual: Bool = false
    let rawName = DisplayManager.getDisplayNameByID(displayID: displayID).lowercased()
    if rawName.contains("dummy") || rawName.contains("airplay") || rawName.contains("sidecar") {
      isVirtual = true
    }
    return isVirtual
  }

  static func resolveEffectiveDisplayID(_ displayID: CGDirectDisplayID) -> CGDirectDisplayID {
    var realDisplayID = displayID
    if CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0 {
      let mirroredDisplayID = CGDisplayMirrorsDisplay(displayID)
      if mirroredDisplayID != 0 {
        realDisplayID = mirroredDisplayID
      }
    }
    return realDisplayID
  }

  static func getByDisplayID(displayID: CGDirectDisplayID) -> NSScreen? {
    return NSScreen.screens.first { $0.displayID == displayID }
  }

  static func getDisplayNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = NSLocalizedString("Unknown", comment: "Unknown display name")
    if let screen = getByDisplayID(displayID: displayID) {
      return screen.localizedName
    }
    return defaultName
  }
}
