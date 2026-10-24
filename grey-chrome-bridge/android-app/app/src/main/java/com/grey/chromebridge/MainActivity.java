package com.grey.chromebridge;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.security.SecureRandom;
import android.content.SharedPreferences;
import android.util.Base64;

public class MainActivity extends Activity {
    private String token;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        SharedPreferences prefs = getSharedPreferences("bridge", MODE_PRIVATE);
        token = prefs.getString("token", null);
        if (token == null) {
            byte[] bytes = new byte[32]; new SecureRandom().nextBytes(bytes);
            token = Base64.encodeToString(bytes, Base64.URL_SAFE | Base64.NO_WRAP | Base64.NO_PADDING);
            prefs.edit().putString("token", token).apply();
        }
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(32, 48, 32, 32);
        TextView title = new TextView(this);
        title.setText("GREY Chrome Bridge\n\nThis companion lets Terhux read visible UI labels and perform explicitly requested taps/scrolls in the active app. It cannot read browser cookies, passwords, OTPs, or page storage.\n\nLocal endpoint: http://127.0.0.1:8765\n\nPrivate control token (copy manually into Terhux; do not share):\n" + token + "\n\nKeep this app installed and the accessibility service enabled while using the bridge.");
        title.setTextIsSelectable(true);
        layout.addView(title, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        Button settings = new Button(this); settings.setText("Open Accessibility Settings");
        settings.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        layout.addView(settings);
        Button refresh = new Button(this); refresh.setText("Refresh status");
        refresh.setOnClickListener(v -> recreate());
        layout.addView(refresh);
        setContentView(layout);
    }
}
