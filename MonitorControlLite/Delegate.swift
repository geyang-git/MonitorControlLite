import HAP
import Logging

class LoggingDeviceDelegate: DeviceDelegate {
    var logger: Logger
    // DisplayManager
    var displayManager: DisplayManager?

    init(logger: Logger) {
        self.logger = logger
    }

    // 注入DisplayManager
    func injectDisplayManager(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    func didRequestIdentificationOf(_ accessory: Accessory) {
        logger.info("Requested identification of accessory \(accessory.info.name.value ?? "?")")
    }

    func characteristic<T>(_ characteristic: GenericCharacteristic<T>,
                           ofService service: Service,
                           ofAccessory accessory: Accessory,
                           didChangeValue newValue: T?) {
        logger.debug(
            """
            Characteristic \(characteristic) \
            in service \(service.type) \
            of accessory \(accessory.info.name.value ?? "") \
            did change: \(String(describing: newValue))
            """)
        // 将serialNumber转换为CGDirectDisplayID
        let serialNumber = accessory.info.serialNumber.value ?? ""
        guard let displayId = CGDirectDisplayID(serialNumber) else { return }
        // 在displayManager中查找对应的Display
        let display = displayManager?.getByDisplayID(displayID: displayId)
        // 如果找到了对应的Display
        if display != nil {
            // 如果是亮度
            if characteristic.type == .brightness {
                // 设置亮度
                // newValue 转为0-1的浮点数
                let brightness = newValue as! Int
                let to = Float(brightness) / 100
                display?.setBrightness(to,slow:true,isHAP: true)
            }
            // 如果是开关
            if characteristic.type == .powerState {
                // 设置开关
              let powerState = newValue as! Bool
              display?.setBrightness(powerState ? 1 : 0, slow: true, isHAP: true)
            }
      }
    }

    func characteristicListenerDidSubscribe(_ accessory: Accessory,
                                            service: Service,
                                            characteristic: AnyCharacteristic) {
        logger.debug(
            """
            Characteristic \(characteristic) \
            in service \(service.type) \
            of accessory \(accessory.info.name.value ?? "") got a subscriber
            """)
    }

    func characteristicListenerDidUnsubscribe(_ accessory: Accessory,
                                              service: Service,
                                              characteristic: AnyCharacteristic) {
        logger.debug(
            """
            Characteristic \(characteristic) \
            in service \(service.type) \
            of accessory \(accessory.info.name.value ?? "") \
            lost a subscriber
            """)
    }

    func didChangePairingState(from: PairingState, to: PairingState) {
        if to == .notPaired {
            printPairingInstructions()
        }
    }

    func printPairingInstructions() {
        if device.isPaired {
            print()
            print(
                """
                The device is paired, either unpair using your iPhone or \
                remove the configuration file `configuration.json`.
                """)
            print()
        } else {
            print()
            print("Scan the following QR code using your iPhone to pair this device:")
            print()
            print(device.setupQRCode.asText)
            print()
        }
    }
}
