# Testing Voice Entry Deletion

## How to Test on Android Emulator

### Method 1: Long Press
1. **Navigate to Notes tab** (should be default view)
2. **Click and HOLD** on any voice entry card for about 1 second
3. You should see:
   - Entry background turns light blue
   - Check icon appears on the right side
   - App bar appears at top with "1 selected" and delete icon
   - Entry "pops" slightly with elevation change

### Method 2: Bulk Selection
1. After entering selection mode (from Method 1)
2. **Simply tap** (not hold) other entries to select them
3. Each tap toggles selection:
   - Tap unselected entry → turns blue, check icon fills
   - Tap selected entry → becomes white again, check icon empties
4. App bar title updates: "X selected"

### Method 3: Delete
1. Select one or more entries
2. Tap the **trash icon** in the top app bar
3. Confirmation dialog appears:
   - "Delete 1 voice entry?" (singular)
   - "Delete X voice entries?" (plural)
   - Shows "This cannot be undone"
4. Tap **Delete** button (red)
5. Success message appears: "X voice entries deleted"
6. Entries disappear from list
7. Selection mode exits automatically

### Method 4: Exit Selection Mode
1. Enter selection mode and select some entries
2. Tap the **X button** in the top left of app bar
3. All selections clear
4. Returns to normal view

## Troubleshooting

### "Long press not working"
- Make sure you're holding for at least 1 second
- Try clicking on different parts of the entry card (not just the play button area)
- The fix with `HitTestBehavior.opaque` should handle this

### "Nothing happens when I tap in selection mode"
- Make sure you see the app bar with "X selected" at the top
- If not, try long-pressing again to enter selection mode first

### "Delete doesn't work"
- Check that you confirmed in the dialog
- Check console for any error messages
- Verify Supabase connection is working

## Visual Indicators

✅ **Selection Mode Active:**
- App bar visible at top
- Selected entries have blue background
- Check icons visible on right side
- Play controls hidden

✅ **Normal Mode:**
- No app bar
- All entries white background
- No check icons
- Play controls visible

## Expected Behavior on Emulator

Since you're using Android Studio emulator with mouse:
1. **Long-press** = Click and hold left mouse button for ~1 second
2. **Tap** = Quick click with left mouse button
3. **Release** = Let go of mouse button

The `HitTestBehavior.opaque` ensures the gesture detector captures all mouse events properly on the emulator.
