# Bottom Navigation Update

## Changes Made

### Navigation Layout

The bottom navigation bar now has **4 navigation items + 1 centered recording FAB**:

```
┌─────────────────────────────────────────────────┐
│  Notes   Processes    [FAB]   Statistics  Profile│
└─────────────────────────────────────────────────┘
```

### Icon Details

1. **Notes** (leftmost)
   - Icon: `Icons.notes`
   - Function: Shows the main calendar + voice notes view (Notes/Analysis tabs)
   - Highlights blue when active

2. **Processes** (left of FAB)
   - Icon: `Icons.sync` (circular arrows)
   - Function: Shows the Processes list page
   - Highlights blue when active

3. **Record FAB** (center, docked)
   - Large circular floating action button
   - Icon: `Icons.mic` / `Icons.mic_none`
   - Function: Start/stop recording

4. **Statistics** (right of FAB)
   - Icon: `Icons.bar_chart`
   - Function: Shows statistics placeholder page (coming soon)
   - Highlights blue when active

5. **Profile** (rightmost)
   - Icon: `Icons.account_circle`
   - Tap: Opens profile page
   - Long press: Shows logout bottom sheet
   - Does NOT navigate in-place (opens separate page)

### Page Index Mapping

- `_currentPageIndex = 0`: Notes/Analysis view (default)
- `_currentPageIndex = 1`: Processes view
- `_currentPageIndex = 2`: Statistics view

### Visual Feedback

- Active navigation items are highlighted in blue
- Inactive items use default grey color
- Recording FAB remains docked in center notch
