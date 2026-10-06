package com.terhux.launcher;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.net.Uri;
import android.widget.*;
import android.graphics.Color;

public class MainActivity extends Activity {
  public void onCreate(Bundle b) { super.onCreate(b);
    LinearLayout l=new LinearLayout(this); l.setOrientation(LinearLayout.VERTICAL); l.setPadding(48,80,48,48);
    TextView title=new TextView(this); title.setText("Terhux"); title.setTextSize(32); title.setTextColor(Color.BLACK); l.addView(title);
    TextView info=new TextView(this); info.setText("GitHub → Termux development bridge\n\nThe Terhux service runs in Termux. Use the button below to open Termux."); info.setTextSize(18); l.addView(info);
    Button open=new Button(this); open.setText("Open Termux"); open.setOnClickListener(v -> { try { startActivity(getPackageManager().getLaunchIntentForPackage("com.termux")); } catch(Exception e) {} }); l.addView(open);
    Button repo=new Button(this); repo.setText("Open Terhux on GitHub"); repo.setOnClickListener(v -> startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/Dannygray29/terhux")))); l.addView(repo);
    setContentView(l);
  }
}
