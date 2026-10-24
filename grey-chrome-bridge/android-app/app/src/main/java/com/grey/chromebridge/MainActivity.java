package com.grey.chromebridge;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.content.SharedPreferences;
import android.util.Base64;
import java.security.SecureRandom;

public class MainActivity extends Activity {
    private String token;
    private static final String TERMUX_PACKAGE = "com.termux";
    private static final String TERMUX_SERVICE = "com.termux.app.RunCommandService";
    private static final String TERMUX_BASH = "/data/data/com.termux/files/usr/bin/bash";
    private static final String TERHUX_RECEIVER = "/data/data/com.termux/files/home/terhux/repo/grey-chrome-bridge/terhux-client/receive-token.sh";

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        SharedPreferences prefs = getSharedPreferences("bridge", MODE_PRIVATE);
        token = prefs.getString("token", null);
        if (token == null) {
            byte[] bytes = new byte[32];
            new SecureRandom().nextBytes(bytes);
            token = Base64.encodeToString(bytes, Base64.URL_SAFE | Base64.NO_WRAP | Base64.NO_PADDING);
            prefs.edit().putString("token", token).apply();
        }

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(32, 48, 32, 32);

        TextView title = new TextView(this);
        title.setText("GREY Chrome Bridge\n\nOne-tap connection to Terhux. This bridge reads visible UI labels and can perform deliberate taps/scrolls in the active app. It does not read browser cookies, passwords, OTPs, or page storage.\n\nLocal endpoint: http://127.0.0.1:8765\n\nFirst, enable the Accessibility Service below. On first connection only, Android/Termux may require allowing external apps to run commands in Termux settings. Your private token is transferred directly to Termux on this device; it is not displayed or sent to the internet.");
        title.setTextIsSelectable(false);
        layout.addView(title, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        Button connect = new Button(this);
        connect.setText("Connect to Terhux");
        connect.setOnClickListener(v -> connectTerhux());
        layout.addView(connect);

        Button settings = new Button(this);
        settings.setText("Enable Accessibility Service");
        settings.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        layout.addView(settings);

        Button refresh = new Button(this);
        refresh.setText("Refresh");
        refresh.setOnClickListener(v -> recreate());
        layout.addView(refresh);
        setContentView(layout);
    }

    private void connectTerhux() {
        try {
            Intent intent = new Intent("com.termux.RUN_COMMAND");
            intent.setComponent(new ComponentName(TERMUX_PACKAGE, TERMUX_SERVICE));
            intent.putExtra("com.termux.RUN_COMMAND_PATH", TERMUX_BASH);
            intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", new String[] { TERHUX_RECEIVER, token });
            intent.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home");
            intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", false);
            startService(intent);
            Toast.makeText(this, "Connection request sent to Terhux. Check Termux for the result.", Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Toast.makeText(this, "Could not start Terhux. Open Termux settings and allow external apps to run commands, then try again.", Toast.LENGTH_LONG).show();
        }
    }
}
