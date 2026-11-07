package io.github.vidoluco.bravetv;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.util.Log;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import android.widget.Toast;

// A pointer for Brave, driven by the remote. Brave is a phone app: its top bar (address, Shields, tabs, menu) only
// answers touches, and the remote's arrows never reach it. Inside Brave the arrows move the pointer, OK taps where it
// points, pushing past the top or bottom edge scrolls, and holding Back shows or hides it. Everywhere else, and while
// the keyboard is up, every key goes through untouched.
public class CursorService extends AccessibilityService {
    static final String BRAVE = "com.brave.browser";
    static final long HOLD_MS = 600;

    final Handler h = new Handler(Looper.getMainLooper());
    WindowManager wm;
    WindowManager.LayoutParams lp;
    View pointer;
    int W, H;
    float x, y;
    boolean on = true, shown, backHeld;
    int mdx, mdy;
    long moveStart, lastScroll;

    @Override
    protected void onServiceConnected() {
        wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        Rect b = wm.getCurrentWindowMetrics().getBounds();
        W = b.width(); H = b.height();
        x = W / 2f; y = H / 2f;
        pointer = new Arrow(this);
        int s = Math.round(H / 28f);
        lp = new WindowManager.LayoutParams(s, Math.round(s * 1.45f), WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.LEFT;
        refresh();
        // For testing over adb, whose injected keys skip this service: only a sender holding DUMP (the shell) gets through.
        //   am broadcast -a io.github.vidoluco.bravetv.TEST --ei key 23 [--ei x 900 --ei y 60]
        IntentFilter f = new IntentFilter(TEST);
        registerReceiver(test, f, "android.permission.DUMP", null, Context.RECEIVER_EXPORTED);
        android.content.pm.PackageManager pm = getPackageManager();
        touch = pm.hasSystemFeature(android.content.pm.PackageManager.FEATURE_TOUCHSCREEN) || pm.hasSystemFeature(android.content.pm.PackageManager.FEATURE_FAKETOUCH);
        Log.i(TAG, "connected " + W + "x" + H + " touch=" + touch);
    }

    static final String TAG = "BraveCursor", TEST = "io.github.vidoluco.bravetv.TEST";

    // Top-level classes only: d8 from build-tools 34 fails on this javac's anonymous and inner classes.
    final BroadcastReceiver test = new TestReceiver(this);

    // The adb test: move the pointer, then press a key as if from the remote.
    void test(Intent i) {
        if (i.hasExtra("x")) { x = i.getIntExtra("x", 0); y = i.getIntExtra("y", 0); place(); }
        int k = i.getIntExtra("key", 0);
        if (k == 0) return;
        long t = SystemClock.uptimeMillis();
        onKeyEvent(new KeyEvent(t, t, KeyEvent.ACTION_DOWN, k, 0));
        onKeyEvent(new KeyEvent(t, t + 50, KeyEvent.ACTION_UP, k, 0));
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent e) { refresh(); }

    @Override
    public void onInterrupt() { stopMove(); }

    @Override
    public void onDestroy() {
        if (shown) wm.removeView(pointer);
        shown = false;
        try { unregisterReceiver(test); } catch (IllegalArgumentException ignored) { }
        super.onDestroy();
    }

    // Brave has the screen and no keyboard is up.
    boolean braveActive() {
        for (AccessibilityWindowInfo w : getWindows()) if (w.getType() == AccessibilityWindowInfo.TYPE_INPUT_METHOD) return false;
        AccessibilityNodeInfo r = getRootInActiveWindow();
        return r != null && r.getPackageName() != null && BRAVE.contentEquals(r.getPackageName());
    }

    void refresh() {
        if (wm == null) return;
        boolean want = on && braveActive();
        if (want && !shown) { place(); wm.addView(pointer, lp); shown = true; }
        else if (!want && shown) { stopMove(); wm.removeView(pointer); shown = false; }
    }

    void place() {
        lp.x = Math.round(x); lp.y = Math.round(y);
        if (shown) wm.updateViewLayout(pointer, lp);
    }

    final Runnable toggle = () -> {
        backHeld = true;
        on = !on;
        refresh();
        Toast.makeText(this, on ? "Freccia attiva" : "Freccia spenta: frecce tra link e bottoni", Toast.LENGTH_SHORT).show();
    };

    @Override
    protected boolean onKeyEvent(KeyEvent e) {
        int k = e.getKeyCode();
        boolean down = e.getAction() == KeyEvent.ACTION_DOWN;
        // Keys are never logged: that would be a key log of everything done in Brave.
        if (!braveActive()) { stopMove(); return false; }
        // Back: a press is Back, a hold shows or hides the pointer.
        if (k == KeyEvent.KEYCODE_BACK) {
            if (down) { if (e.getRepeatCount() == 0) { backHeld = false; h.postDelayed(toggle, HOLD_MS); } return true; }
            h.removeCallbacks(toggle);
            if (!backHeld) performGlobalAction(GLOBAL_ACTION_BACK);
            return true;
        }
        if (!on) return false;
        switch (k) {
            case KeyEvent.KEYCODE_DPAD_UP: return arrow(down, e, 0, -1);
            case KeyEvent.KEYCODE_DPAD_DOWN: return arrow(down, e, 0, 1);
            case KeyEvent.KEYCODE_DPAD_LEFT: return arrow(down, e, -1, 0);
            case KeyEvent.KEYCODE_DPAD_RIGHT: return arrow(down, e, 1, 0);
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_NUMPAD_ENTER:
                if (!down) tap();
                return true;
            default:
                return false;
        }
    }

    boolean arrow(boolean down, KeyEvent e, int dx, int dy) {
        if (!down) { stopMove(); return true; }
        if (e.getRepeatCount() > 0 && mdx == dx && mdy == dy) return true;
        stopMove();
        mdx = dx; mdy = dy;
        step(H / 90f);            // a short press is a small, precise step
        moveStart = SystemClock.uptimeMillis();
        h.postDelayed(mover, 180);
        return true;
    }

    void stopMove() { h.removeCallbacks(mover); mdx = 0; mdy = 0; }

    // Held: the pointer speeds up, from slow to across the screen in about a second.
    final Runnable mover = this::moveTick;

    void moveTick() {
        float t = (SystemClock.uptimeMillis() - moveStart) / 1000f;
        step(Math.min(3f + t * 25f, 24f) * H / 1080f);
        h.postDelayed(mover, 16);
    }

    void step(float d) {
        float nx = x + mdx * d, ny = y + mdy * d;
        if (ny < 0 && mdy < 0) scroll(-1);
        if (ny > H - 1 && mdy > 0) scroll(1);
        x = Math.max(0, Math.min(W - 1, nx));
        y = Math.max(0, Math.min(H - 1, ny));
        place();
    }

    // Past the edge: a swipe on the page, at most every 450 ms while the arrow is held.
    void scroll(int dir) {
        long now = SystemClock.uptimeMillis();
        if (now - lastScroll < 450) return;
        lastScroll = now;
        if (!touch) {
            AccessibilityNodeInfo n = nodeAt(Math.round(x), Math.round(y));
            while (n != null && !n.isScrollable()) n = n.getParent();
            if (n == null) n = findScrollable(getRootInActiveWindow(), 0);
            boolean ok = n != null && n.performAction(dir > 0 ? AccessibilityNodeInfo.ACTION_SCROLL_FORWARD : AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD);
            Log.i(TAG, "scroll " + dir + " " + describe(n) + " ok=" + ok);
            return;
        }
        float sx = Math.max(W * 0.1f, Math.min(W * 0.9f, x));
        float from = dir > 0 ? H * 0.72f : H * 0.32f, to = dir > 0 ? H * 0.32f : H * 0.72f;
        Path p = new Path();
        p.moveTo(sx, from);
        p.lineTo(sx, to);
        gesture(p, 250);
    }

    // Android runs injected touches only on a device with a touchscreen (or "fake touch"). A TV has neither: the tap
    // is cancelled. There the pointer clicks through accessibility instead: the element under it, or its nearest
    // clickable parent, gets a click, as TalkBack does.
    boolean touch;

    void tap() {
        if (touch) {
            Path p = new Path();
            p.moveTo(x, y);
            gesture(p, 40);
            return;
        }
        AccessibilityNodeInfo hit = nodeAt(Math.round(x), Math.round(y)), n = hit;
        while (n != null && !n.isClickable()) n = n.getParent();
        // as TalkBack does: accessibility focus first, then the click (Chromium's web nodes want it)
        if (n != null) n.performAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS);
        boolean ok = n != null && n.performAction(AccessibilityNodeInfo.ACTION_CLICK);
        if (!ok && hit != null && hit.isFocusable()) ok = hit.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
        Log.i(TAG, "click at " + Math.round(x) + "," + Math.round(y) + " on " + describe(n) + " ok=" + ok);
    }

    // The element under a point, in the top-most window that holds it (the pointer's own overlay aside): the smallest
    // clickable one, else the smallest of all. Smallest, not deepest: in a web page a line of text has a box as wide
    // as the paragraph, and it covers the link beside it.
    AccessibilityNodeInfo nodeAt(int px, int py) {
        Rect b = new Rect();
        for (AccessibilityWindowInfo w : getWindows()) {
            if (w.getType() == AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY) continue;
            w.getBoundsInScreen(b);
            if (!b.contains(px, py)) continue;
            AccessibilityNodeInfo[] best = new AccessibilityNodeInfo[2];
            long[] area = { Long.MAX_VALUE, Long.MAX_VALUE };
            search(w.getRoot(), px, py, best, area, 0);
            if (best[0] != null) return best[0];
            if (best[1] != null) return best[1];
        }
        return null;
    }

    // best[0]/area[0]: smallest clickable; best[1]/area[1]: smallest of any kind
    void search(AccessibilityNodeInfo n, int px, int py, AccessibilityNodeInfo[] best, long[] area, int depth) {
        if (n == null || depth > 60 || !n.isVisibleToUser()) return;
        Rect b = new Rect();
        n.getBoundsInScreen(b);
        if (!b.contains(px, py)) return;
        long a = (long) b.width() * b.height();
        if (n.isClickable() && a < area[0]) { area[0] = a; best[0] = n; }
        if (a < area[1]) { area[1] = a; best[1] = n; }
        for (int i = 0; i < n.getChildCount(); i++) search(n.getChild(i), px, py, best, area, depth + 1);
    }

    AccessibilityNodeInfo findScrollable(AccessibilityNodeInfo n, int depth) {
        if (n == null || depth > 25) return null;
        if (n.isScrollable() && n.isVisibleToUser()) return n;
        for (int i = 0; i < n.getChildCount(); i++) {
            AccessibilityNodeInfo s = findScrollable(n.getChild(i), depth + 1);
            if (s != null) return s;
        }
        return null;
    }

    // The element's kind only, never its text: what is on screen (addresses, pages, fields) stays out of the log.
    static String describe(AccessibilityNodeInfo n) {
        if (n == null) return "none";
        String c = String.valueOf(n.getClassName());
        return c.substring(c.lastIndexOf('.') + 1);
    }

    void gesture(Path p, long ms) {
        boolean sent = dispatchGesture(new GestureDescription.Builder().addStroke(new GestureDescription.StrokeDescription(p, 0, ms)).build(),
            new GestureLog(Math.round(x) + "," + Math.round(y)), null);
        Log.i(TAG, "gesture " + ms + "ms sent=" + sent);
    }

    // The pointer: a white arrow with a dark edge, its tip at the view's top-left corner, where the tap lands.
    static class Arrow extends View {
        final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG), edge = new Paint(Paint.ANTI_ALIAS_FLAG);
        Arrow(Context c) {
            super(c);
            fill.setColor(0xFFFFFFFF);
            edge.setColor(0xFF1E2026); edge.setStyle(Paint.Style.STROKE); edge.setStrokeWidth(3); edge.setStrokeJoin(Paint.Join.ROUND);
        }
        @Override
        protected void onDraw(Canvas c) {
            float w = getWidth() - 3, hh = getHeight() - 3;
            Path a = new Path();
            a.moveTo(1.5f, 1.5f);
            a.lineTo(1.5f, hh * 0.78f);
            a.lineTo(w * 0.30f, hh * 0.60f);
            a.lineTo(w * 0.50f, hh);
            a.lineTo(w * 0.68f, hh * 0.92f);
            a.lineTo(w * 0.48f, hh * 0.54f);
            a.lineTo(w, hh * 0.54f);
            a.close();
            c.drawPath(a, fill);
            c.drawPath(a, edge);
        }
    }
}
