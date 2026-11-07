package io.github.vidoluco.bravetv;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

// Brave's start page for the TV remote: a box for an address or a search, and a few links.
// Brave's address bar cannot be reached with the remote's arrows, so typing happens here.
public class MainActivity extends Activity {
    static final String BRAVE = "com.brave.browser";
    static final String[][] LINKS = {
        {"GitHub", "https://github.com/vidoluco"},
        {"Google", "https://www.google.com"},
        {"Wikipedia", "https://it.wikipedia.org"},
        {"Brave Search", "https://search.brave.com"},
    };

    EditText box;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(64), dp(48), dp(64), dp(48));
        root.setBackgroundColor(Color.rgb(30, 32, 38));

        TextView title = new TextView(this);
        title.setText("Brave");
        title.setTextColor(Color.WHITE);
        title.setTextSize(40);
        root.addView(title);

        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        box = new EditText(this);
        box.setHint("Cerca o scrivi un indirizzo");
        box.setSingleLine(true);
        box.setTextSize(22);
        box.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        box.setImeOptions(EditorInfo.IME_ACTION_GO);
        box.setOnEditorActionListener((v, action, ev) -> {
            boolean enter = ev != null && ev.getKeyCode() == KeyEvent.KEYCODE_ENTER && ev.getAction() == KeyEvent.ACTION_UP;
            if (action == EditorInfo.IME_ACTION_GO || action == EditorInfo.IME_ACTION_DONE || enter) { go(box.getText().toString()); return true; }
            return false;
        });
        row.addView(box, new LinearLayout.LayoutParams(dp(640), LinearLayout.LayoutParams.WRAP_CONTENT));
        row.addView(button("Vai", () -> go(box.getText().toString())));
        root.addView(row);

        LinearLayout links = new LinearLayout(this);
        links.setPadding(0, dp(24), 0, 0);
        links.addView(button("Continua in Brave", this::resumeBrave));
        for (String[] link : LINKS) links.addView(button(link[0], () -> open(link[1])));
        root.addView(links);

        LinearLayout more = new LinearLayout(this);
        more.setPadding(0, dp(12), 0, 0);
        more.addView(button("Attiva la freccia (Accessibilità)", () -> start(new Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS))));
        root.addView(more);

        TextView help = new TextView(this);
        help.setText("In Brave: con la freccia attiva, frecce per muoverla, OK per cliccare ovunque (anche barra in alto, scudo, schede, tre puntini), OK tenuto premuto per lo schermo intero dei video, spingi oltre il bordo per scorrere. "
            + "Tieni premuto Indietro per spegnerla e muoverti tra link e bottoni con le frecce. Indietro premuto e rilasciato torna indietro come sempre.");
        help.setTextColor(Color.rgb(170, 174, 184));
        help.setTextSize(16);
        help.setPadding(0, dp(32), 0, 0);
        root.addView(help);

        setContentView(root);
        box.requestFocus();
    }

    Button button(String label, Runnable action) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setOnClickListener(v -> action.run());
        return b;
    }

    // An address opens as it is, a bare domain gets https, anything else is a Brave Search query.
    void go(String text) {
        String q = text.trim();
        if (q.isEmpty()) return;
        if (q.matches("^[a-zA-Z][a-zA-Z0-9+.-]*://.*")) open(q);
        else if (!q.contains(" ") && q.matches("^[^.]+\\.[^.].*")) open("https://" + q);
        else open("https://search.brave.com/search?q=" + Uri.encode(q));
    }

    void open(String url) {
        Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
        i.setPackage(BRAVE);
        i.addCategory(Intent.CATEGORY_BROWSABLE);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        start(i);
    }

    void resumeBrave() {
        Intent i = getPackageManager().getLaunchIntentForPackage(BRAVE);
        if (i == null) { missing(); return; }
        start(i);
    }

    void start(Intent i) {
        try { startActivity(i); } catch (ActivityNotFoundException e) { missing(); }
    }

    void missing() {
        Toast.makeText(this, "Brave non è installato", Toast.LENGTH_LONG).show();
    }

    int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
