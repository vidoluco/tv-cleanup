package io.github.vidoluco.bravetv;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

// Hands the adb test broadcast to the pointer service. Registered with the DUMP permission: only the shell can send it.
class TestReceiver extends BroadcastReceiver {
    final CursorService service;

    TestReceiver(CursorService service) { this.service = service; }

    @Override
    public void onReceive(Context c, Intent i) { service.test(i); }
}
