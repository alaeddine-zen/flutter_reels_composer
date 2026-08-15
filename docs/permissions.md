# Permissions

The composer records video, records audio, and reads the photo library.
Declare native permissions in **your** app. The Dart packages cannot add
Info.plist keys or manifest entries for you.

The [example](../example/) is the reference implementation.

## Android

From `example/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

| Permission | Why |
| --- | --- |
| `CAMERA` | Record |
| `RECORD_AUDIO` | Record + mix |
| `READ_MEDIA_VIDEO` / `IMAGES` / `AUDIO` | Gallery and device audio (API 33+) |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`) | Gallery on older APIs |

Runtime requests go through `permission_handler` (camera/mic) and
`photo_manager` (library). Match each plugin’s `minSdk` (example uses
`flutter.minSdkVersion`).

## iOS usage descriptions

From `example/ios/Runner/Info.plist`:

| Key | Example string |
| --- | --- |
| `NSCameraUsageDescription` | The example uses the camera to record Reels. |
| `NSMicrophoneUsageDescription` | The example uses the microphone to record Reels. |
| `NSPhotoLibraryUsageDescription` | The example accesses your photos and videos to import Reels. |
| `NSPhotoLibraryAddUsageDescription` | The example may save exported Reels to your library. |

Replace copy with your product name before shipping.

## Swift Package Manager

Recent Flutter iOS apps (including this example) use SPM. There is **no
Podfile** under `example/ios/`.

`permission_handler` **12.x** enables permission groups from Info.plist usage
keys when using SPM. Keep the four `NS*` strings above.

## CocoaPods

If your host still uses CocoaPods, `permission_handler` compiles **no**
permission handlers unless you set macros. Add to the `Podfile` `post_install`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_PHOTOS_ADD_ONLY=1',
      ]
    end
  end
end
```

Then `cd ios && pod install`.

Missing macros look like “permission permanently denied” even when Info.plist
is correct.

## Denied permissions

The camera and gallery pages prompt with bundled copy (`cameraPermission`,
`galleryPermission`) and can open system settings (`openSettings`). Handle
`ComposerAnalyticsEventType.permissionDenied` if you pass `onEvent`.
