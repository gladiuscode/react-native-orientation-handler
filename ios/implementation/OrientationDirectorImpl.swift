//
//  OrientationDirectorImpl.swift
//  react-native-orientation-director
//
//  Created by gladiuscode on 18/05/2024.
//

import Foundation
import UIKit

@objc public class OrientationDirectorImpl : NSObject {
    private static let TAG = "OrientationDirectorImpl"
    private let sensorListener: OrientationSensorListener
    private let eventManager: OrientationEventManager
    private var initialSupportedInterfaceOrientations: UIInterfaceOrientationMask = UIInterfaceOrientationMask.all
    private var lastInterfaceOrientation = Orientation.UNKNOWN
    private var lastDeviceOrientation = Orientation.UNKNOWN

    @objc public var supportedInterfaceOrientations: UIInterfaceOrientationMask = UIInterfaceOrientationMask.all
    @objc public var isLocked = false

    @objc public override init() {
        eventManager = OrientationEventManager()
        sensorListener = OrientationSensorListener()
        super.init()
        sensorListener.setOnOrientationChanged(callback: self.onOrientationChanged)
        initialSupportedInterfaceOrientations = initInitialSupportedInterfaceOrientations()
        lastInterfaceOrientation = initInterfaceOrientation()
        lastDeviceOrientation = initDeviceOrientation()
        isLocked = initIsLocked()

        supportedInterfaceOrientations = initialSupportedInterfaceOrientations
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    ///         EVENT EMITTER SETUP
    @objc public func setEventManager(delegate: OrientationEventEmitterDelegate) {
        self.eventManager.delegate = delegate
    }
    ///
    //////////////////////////////////////////////////////////////////////////////////////////

    @objc public func getInterfaceOrientation() -> Orientation {
        return lastInterfaceOrientation
    }

    @objc public func getDeviceOrientation() -> Orientation {
        return lastDeviceOrientation
    }

    @objc public func lockTo(rawJsOrientation: NSNumber) {
        let jsOrientation = OrientationDirectorUtils.getOrientationFrom(jsOrientation: rawJsOrientation)
        let mask = OrientationDirectorUtils.getMaskFrom(jsOrientation: jsOrientation)
        self.requestInterfaceUpdateTo(mask: mask)

        updateIsLockedTo(value: true)
        updateLastInterfaceOrientationTo(value: jsOrientation)
    }

    @objc public func unlock() {
        self.requestInterfaceUpdateTo(mask: UIInterfaceOrientationMask.all)

        updateIsLockedTo(value: false)
        self.adaptInterfaceTo(deviceOrientation: lastDeviceOrientation)
    }

    @objc public func resetSupportedInterfaceOrientations() {
        self.supportedInterfaceOrientations = self.initialSupportedInterfaceOrientations
        self.requestInterfaceUpdateTo(mask: self.supportedInterfaceOrientations)
        self.updateIsLockedTo(value: self.initIsLocked())

        let lastMask = OrientationDirectorUtils.getMaskFrom(jsOrientation: lastInterfaceOrientation)
        let isLastMaskSupported = self.supportedInterfaceOrientations.contains(lastMask)
        if (isLastMaskSupported) {
            return
        }

        let supportedInterfaceOrientations = OrientationDirectorUtils.readSupportedInterfaceOrientationsFromBundle()
        if (supportedInterfaceOrientations.contains(UIInterfaceOrientationMask.portrait)) {
            self.updateLastInterfaceOrientationTo(value: Orientation.PORTRAIT)
            return
        }
        if (supportedInterfaceOrientations.contains(UIInterfaceOrientationMask.landscapeRight)) {
            self.updateLastInterfaceOrientationTo(value: Orientation.LANDSCAPE_RIGHT)
            return
        }
        if (supportedInterfaceOrientations.contains(UIInterfaceOrientationMask.landscapeLeft)) {
            self.updateLastInterfaceOrientationTo(value: Orientation.LANDSCAPE_LEFT)
            return
        }

        self.updateLastInterfaceOrientationTo(value: Orientation.PORTRAIT_UPSIDE_DOWN)
    }

    private func initInitialSupportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        let supportedInterfaceOrientations = OrientationDirectorUtils.readSupportedInterfaceOrientationsFromBundle()
        return supportedInterfaceOrientations.reduce(UIInterfaceOrientationMask()) { $0.union($1) }
    }

    private func initInterfaceOrientation() -> Orientation {
        let interfaceOrientation = OrientationDirectorUtils.getInterfaceOrientation()
        return OrientationDirectorUtils.getOrientationFrom(uiInterfaceOrientation: interfaceOrientation)
    }

    private func initDeviceOrientation() -> Orientation {
        return OrientationDirectorUtils.getOrientationFrom(deviceOrientation: UIDevice.current.orientation)
    }

    private func initIsLocked() -> Bool {
        let supportedOrientations = OrientationDirectorUtils.readSupportedInterfaceOrientationsFromBundle()
        if (supportedOrientations.count > 1) {
            return false
        }

        return supportedOrientations.first != UIInterfaceOrientationMask.all
    }

    private func requestInterfaceUpdateTo(mask: UIInterfaceOrientationMask) {
        self.supportedInterfaceOrientations = mask

        if #available(iOS 16.0, *) {
            let window = OrientationDirectorUtils.getCurrentWindow()

            guard let rootViewController = window?.rootViewController else {
                return
            }

            guard let windowScene = window?.windowScene else {
                return
            }

            rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()

            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                print("\(OrientationDirectorImpl.TAG) - requestGeometryUpdate error", error)
            }
        } else {
            UIDevice.current.setValue(mask.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    private func onOrientationChanged(uiDeviceOrientation: UIDeviceOrientation) {
        let deviceOrientation = OrientationDirectorUtils.getOrientationFrom(deviceOrientation: uiDeviceOrientation)
        self.eventManager.sendDeviceOrientationDidChange(orientationValue: deviceOrientation.rawValue)
        lastDeviceOrientation = deviceOrientation
        adaptInterfaceTo(deviceOrientation: deviceOrientation)
    }

    private func adaptInterfaceTo(deviceOrientation: Orientation) {
        if (isLocked) {
            return
        }
        
        if (deviceOrientation == Orientation.FACE_UP || deviceOrientation == Orientation.FACE_DOWN) {
            return
        }

        let newInterfaceOrientationMask = OrientationDirectorUtils.getMaskFrom(deviceOrientation: deviceOrientation)
        let isSupported = self.supportedInterfaceOrientations.contains(newInterfaceOrientationMask)
        if (!isSupported) {
            return
        }

        let newInterfaceOrientation = OrientationDirectorUtils.getOrientationFrom(mask: newInterfaceOrientationMask)
        if (newInterfaceOrientation == lastInterfaceOrientation) {
            return
        }
        
        updateLastInterfaceOrientationTo(value: newInterfaceOrientation)
    }

    private func updateIsLockedTo(value: Bool) {
        eventManager.sendLockDidChange(value: value)
        isLocked = value
    }

    private func updateLastInterfaceOrientationTo(value: Orientation) {
        self.eventManager.sendInterfaceOrientationDidChange(orientationValue: value.rawValue)
        lastInterfaceOrientation = value
    }
}
