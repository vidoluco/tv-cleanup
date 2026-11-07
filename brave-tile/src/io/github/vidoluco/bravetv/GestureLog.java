package io.github.vidoluco.bravetv;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.util.Log;

// Logs whether a tap or a swipe reached the screen. A top-level class: d8 from build-tools 34 fails on it as an inner one.
class GestureLog extends AccessibilityService.GestureResultCallback {
    final String where;

    GestureLog(String where) { this.where = where; }

    @Override
    public void onCompleted(GestureDescription g) { Log.i(CursorService.TAG, "gesture completed at " + where); }

    @Override
    public void onCancelled(GestureDescription g) { Log.w(CursorService.TAG, "gesture cancelled at " + where); }
}
