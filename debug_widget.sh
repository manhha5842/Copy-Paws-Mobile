#!/bin/bash
# Widget Debug Script for CopyPaws Android

echo "=== CopyPaws Widget Debug Script ==="
echo ""

echo "1. Checking if widget is installed..."
adb shell dumpsys appwidget | grep -i "copypaws" -A 10

echo ""
echo "2. Checking widget provider registration..."
adb shell pm list packages | grep copypaws

echo ""
echo "3. Testing widget data..."
adb shell run-as com.example.copypaws cat shared_prefs/FlutterSharedPreferences.xml 2>/dev/null || echo "Cannot read shared prefs (app might not have data yet)"

echo ""
echo "4. Forcing widget update..."
adb shell am broadcast -a android.appwidget.action.APPWIDGET_UPDATE

echo ""
echo "5. Checking recent widget logs..."
adb logcat -d | grep -i "CopyPawsWidget" | tail -20

echo ""
echo "=== Debug Instructions ==="
echo "If widget shows blank:"
echo "  1. Long press home screen"
echo "  2. Tap Widgets"
echo "  3. Find 'copypaws' widget"
echo "  4. Drag to home screen"
echo ""
echo "If widget still blank after adding:"
echo "  1. Remove widget from home screen"
echo "  2. Reinstall app: flutter install --debug"
echo "  3. Add widget again"
echo ""
echo "To monitor realtime logs:"
echo "  adb logcat | grep -i CopyPaws"
