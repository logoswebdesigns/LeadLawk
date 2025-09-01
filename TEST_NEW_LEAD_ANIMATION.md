# Testing New Lead Animation

## What's Been Implemented

1. **Auto-refresh**: The leads list now automatically updates when new leads are added via WebSocket
2. **Fade-in animation**: New leads fade in with a scale effect (1.2 seconds)
3. **Visual indicators**:
   - Golden glow and border around new lead cards
   - "NEW" badge with star icon
   - Sheen overlay effect that pulses
   - Animation persists for 5 seconds

## How to Test

1. **Start the backend server**:
   ```bash
   docker-compose up -d
   ```

2. **Run the Flutter app**:
   ```bash
   flutter run
   ```

3. **Navigate to the Leads List page** in the app

4. **Run the test script** in a new terminal:
   ```bash
   cd server
   python test_new_lead_animation.py
   ```

5. **Observe the animation**:
   - A new lead should appear automatically (no manual refresh needed)
   - The card should fade in with a scale effect
   - Golden glow and border should be visible
   - "NEW" badge should appear with a sheen effect
   - Animation should last for 5 seconds total

## What to Look For

✅ **Success indicators**:
- Lead appears without pressing refresh button
- Smooth fade-in animation (1.2 seconds)
- Golden glow effect around the card
- "NEW" badge with star icon
- Sheen/shimmer effect on the overlay
- Animation persists for 5 seconds

❌ **Issues to report**:
- Lead doesn't appear automatically
- Animation is choppy or instant
- No visual effects visible
- Animation disappears too quickly

## Technical Details

- WebSocket broadcasts `lead_created` event
- Flutter listens for WebSocket state changes
- Provider invalidation triggers UI refresh
- AnimatedContainer and TweenAnimationBuilder handle effects
- 5-second timer removes animation state