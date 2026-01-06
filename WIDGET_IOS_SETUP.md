# 🍎 iOS Widget Setup Guide

Since implementing Widgets on iOS requires using Xcode to add a specific Target and Capabilities, you need to follow these manual steps.

## 1. Add Widget Network Extension

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Go to **File > New > Target**.
3. Search for **"Widget Extension"** and choose it.
4. Name it `CopyPawsWidget`.
5. Uncheck "Include Live Activity" and "Include Configuration App Intent" (unless you want them).
6. Click **Finish**.
7. When asked about activating the scheme, click **Activate**.

## 2. Configure App Group (Required for Data Sync)

Data sharing between the main App and Widget requires an App Group.

1. **For Runner (Main App):**
   - Click on the `Runner` project in the left navigator.
   - Select the `Runner` target.
   - Go to **Signing & Capabilities**.
   - Click `+ Capability` and select **App Groups**.
   - Click `+` in the App Groups section.
   - Enter `group.com.example.copypaws` (Must match the one in `lib/core/services/widget_service.dart`).
   - Check the box next to it.

2. **For CopyPawsWidget (Extension):**
   - Select the `CopyPawsWidget` target.
   - Go to **Signing & Capabilities**.
   - Click `+ Capability` and select **App Groups**.
   - Use the **SAME** group ID (`group.com.example.copypaws`).
   - Check the box next to it.

## 3. Implement SwiftUI Widget View

Open the newly created `CopyPawsWidget/CopyPawsWidget.swift` file and replace the content with the code below. This code reads the shared data saved by Flutter.

```swift
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), content: "Preview Content", source: "MacBook", time: "Just now")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), content: "Snapshot Content", source: "Device", time: "Now")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Read data from App Group UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.example.copypaws")
        let content = userDefaults?.string(forKey: "clip_content") ?? "No clips yet"
        let source = userDefaults?.string(forKey: "clip_source") ?? ""
        let time = userDefaults?.string(forKey: "clip_time") ?? ""

        let entry = SimpleEntry(date: Date(), content: content, source: source, time: time)

        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let content: String
    let source: String
    let time: String
}

struct CopyPawsWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CopyPaws")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(entry.content)
                .font(.body)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack {
                Text(entry.source)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color("WidgetBackground"))
    }
}

@main
struct CopyPawsWidget: Widget {
    let kind: String = "CopyPawsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CopyPawsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recent Clip")
        .description("Shows the latest clipboard content from your hub.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

## 4. Run and Test

1. Run the app on Simulator or Real Device: `flutter run`
2. Connect to Hub (or wait for a clip).
3. Go to Home Screen.
4. Long press > `+` (Add Widget).
5. Search for "CopyPaws".
6. Add the widget.
7. Send a clip from Desktop -> The widget should update!
