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
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int INK = Color.rgb(32, 33, 36);
    private static final int MUTED = Color.rgb(95, 99, 104);
    private static final int SURFACE = Color.rgb(241, 243, 244);
    private static final int CYAN = Color.rgb(0, 217, 255);
    private static final String HOME = "https://www.google.com";
    private final List<WebView> tabs = new ArrayList<>();
    private final List<String> tabTitles = new ArrayList<>();
    private FrameLayout pageHost;
    private EditText address;
    private ProgressBar progress;
    private TextView tabCount;
    private TextView siteIcon;
    private WebView webView;
    private int activeTab = -1;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        CookieManager.getInstance().setAcceptCookie(true);
        buildUi();
        String lastUrl = getPreferences(MODE_PRIVATE).getString("last_url", HOME);
        if (lastUrl == null || !(lastUrl.startsWith("https://") || lastUrl.startsWith("http://"))) lastUrl = HOME;
        addTab(lastUrl);
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.WHITE);

        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setGravity(android.view.Gravity.CENTER_VERTICAL);
        toolbar.setOrientation(LinearLayout.HORIZONTAL);
        toolbar.setPadding(dp(6), dp(7), dp(6), dp(5));
        toolbar.setBackgroundColor(Color.WHITE);

        Button back = iconButton("‹", "Back");
        back.setOnClickListener(v -> { if (webView != null && webView.canGoBack()) webView.goBack(); });
        toolbar.addView(back, new LinearLayout.LayoutParams(dp(38), dp(42)));

        Button forward = iconButton("›", "Forward");
        forward.setOnClickListener(v -> { if (webView != null && webView.canGoForward()) webView.goForward(); });
        toolbar.addView(forward, new LinearLayout.LayoutParams(dp(34), dp(42)));

        LinearLayout addressPill = new LinearLayout(this);
        addressPill.setGravity(android.view.Gravity.CENTER_VERTICAL);
        addressPill.setPadding(dp(10), 0, dp(6), 0);
        addressPill.setBackground(roundRect(SURFACE, dp(24)));
        siteIcon = new TextView(this);
        siteIcon.setText("●");
        siteIcon.setTextColor(MUTED);
        siteIcon.setTextSize(12);
        addressPill.addView(siteIcon, new LinearLayout.LayoutParams(dp(18), dp(38)));
        address = new EditText(this);
        address.setSingleLine(true);
        address.setTextSize(14);
        address.setTextColor(INK);
        address.setHintTextColor(MUTED);
        address.setHint("Search or type URL");
        address.setSelectAllOnFocus(true);
        address.setBackgroundColor(Color.TRANSPARENT);
        address.setPadding(dp(2), 0, dp(2), 0);
        address.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_VARIATION_URI);
        address.setImeOptions(EditorInfo.IME_ACTION_GO);
        addressPill.addView(address, new LinearLayout.LayoutParams(0, dp(40), 1));
        toolbar.addView(addressPill, new LinearLayout.LayoutParams(0, dp(42), 1));

        Button reload = iconButton("↻", "Reload");
        reload.setOnClickListener(v -> { if (webView != null) webView.reload(); });
        toolbar.addView(reload, new LinearLayout.LayoutParams(dp(38), dp(42)));
        root.addView(toolbar);

        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        progress.setProgressTintList(android.content.res.ColorStateList.valueOf(CYAN));
        root.addView(progress, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(2)));

        pageHost = new FrameLayout(this);
        root.addView(pageHost, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        View divider = new View(this);
        divider.setBackgroundColor(Color.rgb(232, 234, 237));
        root.addView(divider, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)));

        LinearLayout bottom = new LinearLayout(this);
        bottom.setGravity(android.view.Gravity.CENTER_VERTICAL);
        bottom.setOrientation(LinearLayout.HORIZONTAL);
        bottom.setPadding(dp(14), dp(3), dp(14), dp(3));
        bottom.setBackgroundColor(Color.WHITE);

        Button home = iconButton("⌂", "Home");
        home.setOnClickListener(v -> navigate(HOME));
        bottom.addView(home, new LinearLayout.LayoutParams(0, dp(46), 1));

        Button share = iconButton("↥", "Share page");
        share.setOnClickListener(v -> shareCurrentPage());
        bottom.addView(share, new LinearLayout.LayoutParams(0, dp(46), 1));

        tabCount = new TextView(this);
        tabCount.setText("1");
        tabCount.setTextColor(INK);
        tabCount.setTextSize(14);
        tabCount.setTypeface(Typeface.DEFAULT_BOLD);
        tabCount.setGravity(android.view.Gravity.CENTER);
        tabCount.setBackground(roundRect(Color.WHITE, dp(5)));
        tabCount.setOnClickListener(v -> showTabs());
        bottom.addView(tabCount, new LinearLayout.LayoutParams(0, dp(46), 1));

        Button menu = iconButton("⋮", "More options");
        menu.setOnClickListener(this::showMenu);
        bottom.addView(menu, new LinearLayout.LayoutParams(0, dp(46), 1));
        root.addView(bottom);

        address.setOnFocusChangeListener((v, focused) -> {
            if (focused) address.selectAll();
            siteIcon.setText(focused ? "⌕" : "●");
            siteIcon.setTextColor(focused ? INK : MUTED);
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
        tabs.clear();
        webView = null;
        CookieManager.getInstance().flush();
        super.onDestroy();
    }
}
