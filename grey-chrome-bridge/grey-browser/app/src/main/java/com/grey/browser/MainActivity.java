package com.grey.browser;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.URLUtil;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.PopupMenu;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int INK = Color.rgb(234, 251, 255);
    private static final int MUTED = Color.rgb(158, 172, 187);
    private static final int SURFACE = Color.rgb(42, 45, 53);
    private static final int CHROME = Color.rgb(17, 18, 23);
    private static final int CYAN = Color.rgb(0, 217, 255);
    private static final String HOME = "https://www.google.com";
    private final List<WebView> tabs = new ArrayList<>();
    private final List<String> tabTitles = new ArrayList<>();
    private FrameLayout pageHost;
    private EditText address;
    private ProgressBar progress;
    private TextView tabCount;
    private LinearLayout tabStrip;
    private TextView siteIcon;
    private WebView webView;
    private int activeTab = -1;
    private ScheduledExecutorService terhuxScheduler;
    private volatile String terhuxToken = "";

    @Override
    protected void onCreate(Bundle state) {
        getWindow().clearFlags(android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS);
        if (android.os.Build.VERSION.SDK_INT >= 21) {
            getWindow().getDecorView().setSystemUiVisibility(0);
        }

        super.onCreate(state);
        CookieManager.getInstance().setAcceptCookie(true);
        logDisplayMetrics();
        buildUi();
        String lastUrl = getPreferences(MODE_PRIVATE).getString("last_url", HOME);
        if (lastUrl == null || !(lastUrl.startsWith("https://") || lastUrl.startsWith("http://"))) lastUrl = HOME;
        addTab(lastUrl);
        terhuxToken = getPreferences(MODE_PRIVATE).getString("terhux_token", "");
        if (!terhuxToken.isEmpty()) startTerhuxPolling();
    }

    private void logDisplayMetrics() {
        DisplayMetrics dm = getResources().getDisplayMetrics();
        int widthPx = dm.widthPixels;
        int heightPx = dm.heightPixels;
        float density = dm.density;
        android.graphics.Rect visible = new android.graphics.Rect();
        getWindow().getDecorView().getWindowVisibleDisplayFrame(visible);
        Log.i("GREYBrowserDisplay", "screenPx=" + widthPx + "x" + heightPx
                + ", screenDp=" + Math.round(widthPx / density) + "x" + Math.round(heightPx / density)
                + ", density=" + density + ", visibleFrame=" + visible.flattenToString());
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(CHROME);
        // Keep browser chrome comfortably below the Android status bar.
        // The window is configured to fit system windows; this adds extra breathing room.
        root.setPadding(0, dp(12), 0, 0);

        HorizontalScrollViewCompat tabsScroller = new HorizontalScrollViewCompat(this);
        tabsScroller.setHorizontalScrollBarEnabled(false);
        tabsScroller.setFillViewport(false);
        tabsScroller.setBackgroundColor(CHROME);
        tabStrip = new LinearLayout(this);
        tabStrip.setOrientation(LinearLayout.HORIZONTAL);
        tabStrip.setGravity(android.view.Gravity.CENTER_VERTICAL);
        tabStrip.setPadding(dp(4), dp(1), dp(4), dp(1));
        tabsScroller.addView(tabStrip, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(30)));
        root.addView(tabsScroller, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(30)));

        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setGravity(android.view.Gravity.CENTER_VERTICAL);
        toolbar.setOrientation(LinearLayout.HORIZONTAL);
        toolbar.setPadding(dp(3), dp(1), dp(3), dp(1));
        toolbar.setBackgroundColor(CHROME);

        Button home = iconButton("⌂", "Home");
        home.setTextSize(18);
        home.setOnClickListener(v -> navigate(HOME));
        toolbar.addView(home, new LinearLayout.LayoutParams(dp(29), dp(34)));

        Button back = iconButton("‹", "Back");
        back.setTextSize(21);
        back.setOnClickListener(v -> { if (webView != null && webView.canGoBack()) webView.goBack(); });
        toolbar.addView(back, new LinearLayout.LayoutParams(dp(25), dp(34)));

        Button forward = iconButton("›", "Forward");
        forward.setTextSize(21);
        forward.setOnClickListener(v -> { if (webView != null && webView.canGoForward()) webView.goForward(); });
        toolbar.addView(forward, new LinearLayout.LayoutParams(dp(25), dp(34)));

        Button reload = iconButton("↻", "Reload");
        reload.setTextSize(18);
        reload.setOnClickListener(v -> { if (webView != null) webView.reload(); });
        toolbar.addView(reload, new LinearLayout.LayoutParams(dp(27), dp(34)));

        LinearLayout addressPill = new LinearLayout(this);
        addressPill.setGravity(android.view.Gravity.CENTER_VERTICAL);
        addressPill.setPadding(dp(9), 0, dp(7), 0);
        addressPill.setBackground(roundRect(SURFACE, dp(22)));
        siteIcon = new TextView(this);
        siteIcon.setText("●");
        siteIcon.setTextColor(CYAN);
        siteIcon.setTextSize(10);
        addressPill.addView(siteIcon, new LinearLayout.LayoutParams(dp(12), dp(30)));
        address = new EditText(this);
        address.setSingleLine(true);
        address.setTextSize(12);
        address.setTextColor(INK);
        address.setHintTextColor(MUTED);
        address.setHint("Search or type URL");
        address.setSelectAllOnFocus(true);
        address.setBackgroundColor(Color.TRANSPARENT);
        address.setPadding(dp(2), 0, dp(2), 0);
        address.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_VARIATION_URI);
        address.setImeOptions(EditorInfo.IME_ACTION_GO);
        addressPill.addView(address, new LinearLayout.LayoutParams(0, dp(30), 1));
        Button bookmark = iconButton("☆", "Bookmark");
        bookmark.setTextSize(17);
        bookmark.setOnClickListener(v -> Toast.makeText(this, "Bookmark feature coming soon", Toast.LENGTH_SHORT).show());
        addressPill.addView(bookmark, new LinearLayout.LayoutParams(dp(25), dp(30)));
        toolbar.addView(addressPill, new LinearLayout.LayoutParams(0, dp(32), 1));

        Button menu = iconButton("⋮", "More options");
        menu.setTextSize(20);
        menu.setOnClickListener(this::showMenu);
        toolbar.addView(menu, new LinearLayout.LayoutParams(dp(26), dp(34)));
        root.addView(toolbar);

        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        progress.setProgressTintList(android.content.res.ColorStateList.valueOf(CYAN));
        progress.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(Color.rgb(35, 39, 48)));
        root.addView(progress, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(2)));

        pageHost = new FrameLayout(this);
        pageHost.setBackgroundColor(Color.WHITE);
        root.addView(pageHost, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        address.setOnFocusChangeListener((v, focused) -> {
            if (focused) address.selectAll();
            siteIcon.setText(focused ? "⌕" : "●");
            siteIcon.setTextColor(CYAN);
        });
        address.setOnEditorActionListener((v, actionId, event) -> {
            boolean enter = event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER && event.getAction() == KeyEvent.ACTION_UP;
            if (actionId == EditorInfo.IME_ACTION_GO || enter) {
                navigateFromAddress();
                return true;
            }
            return false;
        });
        setContentView(root);
    }

    private void renderTabStrip() {
        if (tabStrip == null) return;
        tabStrip.removeAllViews();
        for (int i = 0; i < tabs.size(); i++) {
            final int index = i;
            LinearLayout chip = new LinearLayout(this);
            chip.setGravity(android.view.Gravity.CENTER_VERTICAL);
            chip.setPadding(dp(7), 0, dp(4), 0);
            chip.setBackground(roundRect(i == activeTab ? Color.rgb(42, 45, 53) : CHROME, dp(8)));
            TextView favicon = new TextView(this);
            favicon.setText("●");
            favicon.setTextColor(i == activeTab ? CYAN : MUTED);
            favicon.setTextSize(9);
            chip.addView(favicon, new LinearLayout.LayoutParams(dp(13), dp(30)));
            TextView label = new TextView(this);
            String title = tabTitles.get(i);
            if (title == null || title.trim().isEmpty()) title = "New tab";
            label.setText(title.length() > 13 ? title.substring(0, 12) + "…" : title);
            label.setTextColor(INK);
            label.setTextSize(11);
            label.setSingleLine(true);
            chip.addView(label, new LinearLayout.LayoutParams(dp(86), dp(30)));
            TextView close = new TextView(this);
            close.setText("×");
            close.setTextSize(17);
            close.setTextColor(MUTED);
            close.setGravity(android.view.Gravity.CENTER);
            close.setContentDescription("Close tab");
            close.setOnClickListener(v -> { if (index == activeTab) closeCurrentTab(); else closeTabAt(index); });
            chip.addView(close, new LinearLayout.LayoutParams(dp(22), dp(30)));
            chip.setOnClickListener(v -> switchToTab(index));
            LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(32));
            cp.rightMargin = dp(4);
            tabStrip.addView(chip, cp);
        }
        TextView plus = new TextView(this);
        plus.setText("+");
        plus.setTextSize(22);
        plus.setTextColor(INK);
        plus.setGravity(android.view.Gravity.CENTER);
        plus.setOnClickListener(v -> addTab(HOME));
        tabStrip.addView(plus, new LinearLayout.LayoutParams(dp(30), dp(28)));
    }

    private void closeTabAt(int index) {
        if (index < 0 || index >= tabs.size()) return;
        WebView removed = tabs.remove(index);
        tabTitles.remove(index);
        if (removed != null) { removed.stopLoading(); removed.destroy(); }
        if (tabs.isEmpty()) { activeTab = -1; addTab(HOME); }
        else {
            if (index < activeTab) activeTab--;
            else if (index == activeTab) activeTab = Math.min(index, tabs.size() - 1);
            switchToTab(activeTab);
        }
        updateTabCount();
    }

    private class HorizontalScrollViewCompat extends android.widget.HorizontalScrollView {
        HorizontalScrollViewCompat(Context context) { super(context); }
    }

    private Button iconButton(String symbol, String description) {
        Button button = new Button(this);
        button.setText(symbol);
        button.setTextSize(23);
        button.setTextColor(INK);
        button.setAllCaps(false);
        button.setMinWidth(0);
        button.setMinimumWidth(0);
        button.setPadding(0, 0, 0, 0);
        button.setBackgroundColor(Color.TRANSPARENT);
        button.setContentDescription(description);
        return button;
    }

    private GradientDrawable roundRect(int color, int radius) {
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(color);
        shape.setCornerRadius(radius);
        return shape;
    }

    private void addTab(String initialUrl) {
        WebView view = new WebView(this);
        configureBrowser(view);
        tabs.add(view);
        tabTitles.add("New tab");
        switchToTab(tabs.size() - 1);
        view.loadUrl(initialUrl);
        updateTabCount();
    }

    private void switchToTab(int index) {
        if (index < 0 || index >= tabs.size()) return;
        if (webView != null && webView.getParent() == pageHost) pageHost.removeView(webView);
        activeTab = index;
        webView = tabs.get(index);
        if (webView.getParent() != null) ((ViewGroup) webView.getParent()).removeView(webView);
        pageHost.addView(webView, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        address.setText(webView.getUrl() == null ? "" : webView.getUrl());
        updateTabCount();
    }

    private void configureBrowser(WebView view) {
        WebSettings settings = view.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSupportMultipleWindows(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setGeolocationEnabled(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        view.setBackgroundColor(Color.WHITE);
        view.setDownloadListener((url, userAgent, contentDisposition, mimeType, contentLength) -> {
            if (url == null || !(url.startsWith("https://") || url.startsWith("http://"))) {
                Toast.makeText(MainActivity.this, "Blocked unsupported download link.", Toast.LENGTH_SHORT).show();
                return;
            }
            try {
                String fileName = URLUtil.guessFileName(url, contentDisposition, mimeType);
                DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                request.setTitle(fileName);
                request.setDescription("Downloading with GREY Browser");
                request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
                String cookie = CookieManager.getInstance().getCookie(url);
                if (cookie != null && !cookie.isEmpty()) request.addRequestHeader("Cookie", cookie);
                if (userAgent != null && !userAgent.isEmpty()) request.addRequestHeader("User-Agent", userAgent);
                DownloadManager manager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
                manager.enqueue(request);
                Toast.makeText(MainActivity.this, "Download started: " + fileName, Toast.LENGTH_LONG).show();
            } catch (Exception e) {
                Toast.makeText(MainActivity.this, "Could not start download.", Toast.LENGTH_LONG).show();
            }
        });
        view.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView current, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String scheme = uri.getScheme();
                if (scheme != null && (scheme.equalsIgnoreCase("https") || scheme.equalsIgnoreCase("http"))) return false;
                Toast.makeText(MainActivity.this, "Blocked unsupported link type.", Toast.LENGTH_SHORT).show();
                return true;
            }
            @Override
            public void onPageStarted(WebView current, String url, Bitmap favicon) {
                if (current == webView) {
                    address.setText(url);
                    progress.setVisibility(View.VISIBLE);
                }
                if (activeTab >= 0 && activeTab < tabs.size() && tabs.get(activeTab) == current) tabTitles.set(activeTab, current.getTitle() == null ? "Loading…" : current.getTitle());
            }
            @Override
            public void onPageFinished(WebView current, String url) {
                if (current == webView) {
                    address.setText(url);
                    if (url != null && (url.startsWith("https://") || url.startsWith("http://"))) {
                        getPreferences(MODE_PRIVATE).edit().putString("last_url", url).apply();
                    }
                    CookieManager.getInstance().flush();
                }
            }
        });
        view.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView current, int value) {
                if (current == webView) {
                    progress.setProgress(value);
                    progress.setVisibility(value >= 100 ? View.GONE : View.VISIBLE);
                }
            }
            @Override
            public void onReceivedTitle(WebView current, String title) {
                int idx = tabs.indexOf(current);
                if (idx >= 0) {
                    tabTitles.set(idx, title == null || title.trim().isEmpty() ? "New tab" : title);
                    if (current == webView) updateTabCount();
                }
            }
        });
    }

    private void navigateFromAddress() {
        String raw = address.getText().toString().trim();
        if (raw.isEmpty()) return;
        String url;
        if (raw.matches("(?i)^https?://.*")) url = raw;
        else if (raw.matches("(?i)^[a-z0-9.-]+\\.[a-z]{2,}([/:?#].*)?$") && !raw.contains(" ")) url = "https://" + raw;
        else url = "https://www.google.com/search?q=" + Uri.encode(raw);
        navigate(url);
    }

    private void navigate(String url) {
        if (webView == null) return;
        Uri parsed = Uri.parse(url);
        String scheme = parsed.getScheme();
        if (scheme == null || !(scheme.equalsIgnoreCase("http") || scheme.equalsIgnoreCase("https"))) {
            Toast.makeText(this, "Only HTTP and HTTPS addresses are supported.", Toast.LENGTH_LONG).show();
            return;
        }
        ((InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(address.getWindowToken(), 0);
        webView.loadUrl(url);
    }

    private void showTabs() {
        if (tabs.isEmpty()) { addTab(HOME); return; }
        String[] labels = new String[tabTitles.size() + 1];
        for (int i = 0; i < tabTitles.size(); i++) labels[i] = (i == activeTab ? "✓  " : "") + (i + 1) + ". " + tabTitles.get(i);
        labels[labels.length - 1] = "+  New tab";
        new AlertDialog.Builder(this).setTitle("Tabs").setItems(labels, (dialog, which) -> {
            if (which == labels.length - 1) addTab(HOME);
            else switchToTab(which);
        }).setNeutralButton("Close current tab", (dialog, which) -> closeCurrentTab()).setNegativeButton("Done", null).show();
    }

    private void closeCurrentTab() {
        if (activeTab < 0 || activeTab >= tabs.size()) return;
        WebView removed = tabs.remove(activeTab);
        tabTitles.remove(activeTab);
        if (removed != null) {
            removed.stopLoading();
            removed.destroy();
        }
        if (tabs.isEmpty()) addTab(HOME);
        else switchToTab(Math.min(activeTab, tabs.size() - 1));
        updateTabCount();
    }

    private void updateTabCount() {
        if (tabCount != null) tabCount.setText(String.valueOf(tabs.size()));
        renderTabStrip();
    }

    private void shareCurrentPage() {
        if (webView == null || webView.getUrl() == null) return;
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("text/plain");
        send.putExtra(Intent.EXTRA_TEXT, webView.getUrl());
        startActivity(Intent.createChooser(send, "Share page"));
    }

    private void showMenu(View anchor) {
        PopupMenu menu = new PopupMenu(this, anchor);
        menu.getMenu().add("Connect Terhux").setOnMenuItemClickListener(item -> { connectTerhux(); return true; });
        menu.getMenu().add("New tab").setOnMenuItemClickListener(item -> { addTab(HOME); return true; });
        menu.getMenu().add("Share").setOnMenuItemClickListener(item -> { shareCurrentPage(); return true; });
        menu.getMenu().add("Reload").setOnMenuItemClickListener(item -> { if (webView != null) webView.reload(); return true; });
        menu.getMenu().add("Downloads").setOnMenuItemClickListener(item -> {
            try {
                startActivity(new Intent(DownloadManager.ACTION_VIEW_DOWNLOADS));
            } catch (Exception e) {
                Toast.makeText(this, "Open the Downloads app to view files.", Toast.LENGTH_LONG).show();
            }
            return true;
        });
        menu.getMenu().add("Copy link").setOnMenuItemClickListener(item -> {
            if (webView != null && webView.getUrl() != null) {
                android.content.ClipboardManager clipboard = (android.content.ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
                clipboard.setPrimaryClip(android.content.ClipData.newPlainText("Page URL", webView.getUrl()));
                Toast.makeText(this, "Link copied", Toast.LENGTH_SHORT).show();
            }
            return true;
        });
        menu.show();
    }

    private void connectTerhux() {
        String saved = getPreferences(MODE_PRIVATE).getString("terhux_token", "");
        final String candidate = saved.isEmpty() ? newTerhuxToken() : saved;
        new Thread(() -> {
            try {
                JSONObject response = terhuxRequest("POST", "/pair", new JSONObject().put("token", candidate), candidate);
                if (!response.optBoolean("ok")) throw new Exception("Pairing rejected");
                runOnUiThread(() -> {
                    terhuxToken = candidate;
                    getPreferences(MODE_PRIVATE).edit().putString("terhux_token", candidate).apply();
                    startTerhuxPolling();
                    Toast.makeText(this, "Terhux connected", Toast.LENGTH_LONG).show();
                });
            } catch (Exception e) {
                runOnUiThread(() -> Toast.makeText(this, "Terhux unavailable. Keep Termux running and try again.", Toast.LENGTH_LONG).show());
            }
        }, "grey-terhux-pair").start();
    }
    private String newTerhuxToken() {
        byte[] bytes = new byte[32]; new SecureRandom().nextBytes(bytes);
        StringBuilder out = new StringBuilder(64);
        for (byte b : bytes) out.append(String.format(java.util.Locale.ROOT, "%02x", b & 0xff));
        return out.toString();
    }
    private JSONObject terhuxRequest(String method, String path, JSONObject body, String token) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL("http://127.0.0.1:8789/v1/browser" + path).openConnection();
        c.setRequestMethod(method); c.setConnectTimeout(1800); c.setReadTimeout(2500); c.setUseCaches(false);
        if (token != null && !token.isEmpty()) c.setRequestProperty("Authorization", "Bearer " + token);
        if (body != null) {
            c.setDoOutput(true); c.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            try (OutputStream o = c.getOutputStream()) { o.write(body.toString().getBytes(StandardCharsets.UTF_8)); }
        }
        int code = c.getResponseCode();
        InputStream in = code >= 400 ? c.getErrorStream() : c.getInputStream();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        if (in != null) try (InputStream i = in) { byte[] b = new byte[2048]; int n; while ((n = i.read(b)) != -1) out.write(b, 0, n); }
        c.disconnect();
        if (code < 200 || code >= 300) throw new java.io.IOException("Terhux HTTP " + code);
        String text = out.toString(StandardCharsets.UTF_8);
        return new JSONObject(text.isEmpty() ? "{}" : text);
    }
    private void startTerhuxPolling() {
        if (terhuxScheduler != null && !terhuxScheduler.isShutdown()) return;
        terhuxScheduler = Executors.newSingleThreadScheduledExecutor();
        terhuxScheduler.scheduleWithFixedDelay(() -> {
            String token = terhuxToken; if (token.isEmpty()) return;
            try {
                JSONObject response = terhuxRequest("GET", "/next", null, token);
                JSONObject command = response.optJSONObject("command");
                if (command != null) runOnUiThread(() -> executeTerhuxCommand(command));
            } catch (Exception e) {
                android.util.Log.w("GREYBrowserTerhux", "Polling failed: " + e.getClass().getSimpleName());
            }
        }, 0, 2, TimeUnit.SECONDS);
    }
    private void executeTerhuxCommand(JSONObject c) {
        String id = c.optString("id", ""), action = c.optString("action", "");
        try {
            switch (action) {
                case "navigate": {
                    String target = c.optString("url", ""); Uri u = Uri.parse(target); String scheme = u.getScheme();
                    if (scheme == null || u.getHost() == null || !(scheme.equalsIgnoreCase("http") || scheme.equalsIgnoreCase("https"))) {
                        sendTerhuxResult(id, false, "Only HTTP/HTTPS navigation is allowed.");
                    } else { navigate(target); sendTerhuxResult(id, true, "Navigation requested: " + target); }
                    return;
                }
                case "back": if (webView != null && webView.canGoBack()) webView.goBack(); sendTerhuxResult(id, true, "Back handled"); return;
                case "forward": if (webView != null && webView.canGoForward()) webView.goForward(); sendTerhuxResult(id, true, "Forward handled"); return;
                case "reload": if (webView != null) webView.reload(); sendTerhuxResult(id, true, "Reload requested"); return;
                case "status": sendTerhuxResult(id, true, webView == null ? "No active tab" : String.valueOf(webView.getUrl())); return;
                default: sendTerhuxResult(id, false, "Unsupported browser action");
            }
        } catch (Exception e) { sendTerhuxResult(id, false, "Browser action failed"); }
    }
    private void sendTerhuxResult(String id, boolean success, String result) {
        if (id == null || id.isEmpty() || terhuxToken.isEmpty()) return;
        new Thread(() -> {
            try { terhuxRequest("POST", "/result", new JSONObject().put("id", id).put("success", success).put("result", result), terhuxToken); }
            catch (Exception ignored) {}
        }).start();
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else if (tabs.size() > 1) closeCurrentTab();
        else super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        for (WebView tab : tabs) {
            if (tab != null) {
                tab.stopLoading();
                tab.setWebChromeClient(null);
                tab.setWebViewClient(null);
                tab.destroy();
            }
        }
        if (terhuxScheduler != null) terhuxScheduler.shutdownNow();
        tabs.clear();
        webView = null;
        CookieManager.getInstance().flush();
        super.onDestroy();
    }
}
