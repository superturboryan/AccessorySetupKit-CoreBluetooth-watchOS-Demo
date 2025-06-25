# FB18383742 - Installing watchOS companion app using Core Bluetooth for iOS app using ASK is broken on both platforms 🍏

### Demo Xcode project with barebones iOS target using AccessorySetupKit + watchOS companion using Core Bluetooth

### Setup
🛠️ Xcode 16.4 (16F6)  
📱 iPhone 13 mini (iOS 18.0.1)  
⌚️ Apple Watch Series 10 (watchOS 11.3.1)  

## Observations
- As `AccessorySetupKit` does not request "Core Bluetooth permissions", when a watchOS companion app is installed after having installed the iOS app, the toggle in the watch settings for `Privacy & Security > Bluetooth` is turned off and disabled
- After removing the iPhone associated with the Apple Watch, Bluetooth works as expected in the watchOS app
- Upon reinstalling the iOS app, there's a toggle for Bluetooth in the iOS ASK app's settings and the ASK picker cannot be presented 🤨
- From [ASK Documentation](https://developer.apple.com/documentation/accessorysetupkit):
> AccessorySetupKit is available for iOS and iPadOS. The accessory’s Bluetooth permission doesn’t sync to a companion watchOS app.
- But this doesn't address not being able to use Core Bluetooth in a watch companion app **at all** 🥲

## Reproducing the bug
- Install the iOS + watchOS apps
- Launch iOS app, tap "start scan", observe devices can be discovered (project is set up to find heart rate monitors)
- Launch watchOS, tap allow on Bluetooth permission pop-up
- **watchOS app crashes** 💥
- Meanwhile, in the iOS app, there should be a log entry for `💗 CBCentralManager state: poweredOff` and the **ASK picker is no longer able to discover any devices**
- The state of the device permissions:

<p>
  <img src="https://github.com/user-attachments/assets/526b6772-b676-41d0-a859-162b4c6d5e70" width=250/>
  <img src="https://github.com/user-attachments/assets/02e09cc3-25ce-47cf-a326-97c1d52fe56e" width=250/>
</p>

- Remove the iOS app
- Relaunch the watchOS app
- Notice the CBCentralManager state is `unauthorized`
- Remove and reinstall the watchOS app
- Tap allow on Bluetooth permission pop-up
- watchOS app **does not crash and CBCentralManager state is `poweredOn`**
- The state of the watch permissions:
<p>
  <img src="https://github.com/user-attachments/assets/0dd4636f-f273-4133-81d4-9040de17a432" width=250/>  
</p>

- Note that at this time the iOS app is **not installed**, there is no way to remove Bluetooth permission for the watch app:

<p>
<img src="https://github.com/user-attachments/assets/d44f41ed-11d3-48ed-9d38-5bf9af41ab2c" width=250/>  
</p>

- Reinstall + launch the iOS app
- Notice a warning in the log:
> [##### WARNING #####] App has companion watch app that maybe affected if using CoreBluetooth framework. Please read developer documentation for AccessorySetupKit.
- Notice a log entry for `💗 CBCentralManager state: poweredOn` before tapping start scan
- Tap start scan and observe another log entry:
> Failed to show picker due to: The operation couldn’t be completed. (ASErrorDomain error 550.)
- `ASErrorDomain 550`:
> The picker can't be used because the app is in the background.
- Is this the expected error? 🤔
- The state of the iOS permissions:

<p>
<img src="https://github.com/user-attachments/assets/6efc857f-ea4b-4f72-a115-306e68d2d9a4" width=250/>  
</p>

- The iOS ASK app now has **Core Bluetooth** permission 😵‍💫

### Following up with Apple

- This is a known bug that should be fixed in watchOS 26 when Bluetooth permissions for watch apps can be set independently of the iOS app.
