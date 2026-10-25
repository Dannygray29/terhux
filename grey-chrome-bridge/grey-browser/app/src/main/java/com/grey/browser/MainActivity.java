package com.grey.browser;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {
    private WebView webView;
    private EditText address;
    private ProgressBar progress;
    private TextView status;
    private Button backButton;
    private Button forwardButton;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        buildUi();
        configureBrowser();
        if (state != null) {
            webView.restoreState(state);
        } else {
            webView.loadUrl("https://www.google.com");
        }
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.WHITE);

        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setPadding(dp(8), dp(8), dp(8), dp(4));

        address = new EditText(this);
        address.setSingleLine(true);
        address.setHint("Search or enter website");
        address.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_VARIATION_URI);
        address.setImeOptions(EditorInfo.IME_ACTION_GO);
        bar.addView(address, new LinearLayout.LayoutParams(0, dp(48), 1));

        Button go = new Button(this);
        go.setText("Go");
        bar.addView(go, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(48)));
        root.addView(bar);

        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        root.addView(progress, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(3)));

        webView = new WebView(this);
        root.addView(webView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        LinearLayout controls = new LinearLayout(this);
        controls.setOrientation(LinearLayout.HORIZONTAL);
        controls.setPadding(dp(4), dp(2), dp(4), dp(2));
        backButton = controlButton("Back", v -> { if (webView.canGoBack()) webView.goBack(); });
        forwardButton = controlButton("Forward", v -> { if (webView.canGoForward()) webView.goForward(); });
        Button reload = controlButton("Reload", v -> webView.reload());
        Button home = controlButton("Home", v -> webView.loadUrl("https://www.google.com"));
        controls.addView(backButton, new LinearLayout.LayoutParams(0, dp(44), 1));
        controls.addView(forwardButton, new LinearLayout.LayoutParams(0, dp(44), 1));
        controls.addView(reload, new LinearLayout.LayoutParams(0, dp(44), 1));
        controls.addView(home, new LinearLayout.LayoutParams(0, dp(44), 1));
        root.addView(controls);

        status = new TextView(this);
        status.setText("GREY Browser · local mode");
        status.setTextColor(Color.DKGRAY);
        status.setPadding(dp(10), dp(4), dp(10), dp(6));
        root.addView(status);

        go.setOnClickListener(v -> navigateFromAddress());
        address.setOnEditorActionListener((v, actionId, event) -> {
            boolean enter = event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER
                    && event.getAction() == KeyEvent.ACTION_UP;
            if (actionId == EditorInfo.IME_ACTION_GO || enter) {
                navigateFromAddress();
                return true;
            }
            return false;
        });
        setContentView(root);
    }

    private Button controlButton(String label, View.OnClickListener listener) {
        Button b = new Button(this);
        b.setText(label);
        b.setOnClickListener(listener);
        return b;
    }

    private void configureBrowser() {
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSupportMultipleWindows(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setGeolocationEnabled(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        webView.setBackgroundColor(Color.WHITE);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String scheme = uri.getScheme();
                if (scheme != null && (scheme.equalsIgnoreCase("https") || scheme.equalsIgnoreCase("http"))) {
                    return false;
                }
                Toast.makeText(MainActivity.this, "Blocked unsupported link type.", Toast.LENGTH_SHORT).show();
                return true;
            }

            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                address.setText(url);
                status.setText("Loading…");
                updateNavigationButtons();
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                address.setText(url);
                status.setText("Ready · local browser");
                updateNavigationButtons();
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                progress.setProgress(newProgress);
                progress.setVisibility(newProgress >= 100 ? View.GONE : View.VISIBLE);
            }

            @Override
            public void onReceivedTitle(WebView view, String title) {
                if (title != null && !title.trim().isEmpty()) status.setText(title);
            }
        });
    }

    private void navigateFromAddress() {
        String raw = address.getText().toString().trim();
        if (raw.isEmpty()) return;
        String url;
        if (raw.matches("(?i)^https?://.*")) {
            url = raw;
        } else if (raw.matches("(?i)^[a-z0-9.-]+\\.[a-z]{2,}([/:?#].*)?$") && !raw.contains(" ")) {
            url = "https://" + raw;
        } else {
            url = "https://www.google.com/search?q=" + Uri.encode(raw);
        }
        Uri parsed = Uri.parse(url);
        String scheme = parsed.getScheme();
        if (scheme == null || !(scheme.equalsIgnoreCase("http") || scheme.equalsIgnoreCase("https"))) {
            Toast.makeText(this, "Only HTTP and HTTPS addresses are supported.", Toast.LENGTH_LONG).show();
            return;
        }
        ((InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE))
                .hideSoftInputFromWindow(address.getWindowToken(), 0);
        webView.loadUrl(url);
    }

    private void updateNavigationButtons() {
        if (backButton != null) backButton.setEnabled(webView.canGoBack());
        if (forwardButton != null) forwardButton.setEnabled(webView.canGoForward());
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        if (webView != null) webView.saveState(outState);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.stopLoading();
            webView.setWebChromeClient(null);
            webView.setWebViewClient(null);
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
}
