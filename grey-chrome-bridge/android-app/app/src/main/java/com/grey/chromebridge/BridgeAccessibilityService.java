package com.grey.chromebridge;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.graphics.Path;
import android.graphics.Point;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.content.SharedPreferences;
import android.util.Base64;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.ServerSocket;
import java.net.Socket;
import java.security.SecureRandom;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class BridgeAccessibilityService extends AccessibilityService {
    private volatile boolean running = false;
    private ServerSocket server;
    private ExecutorService pool;
    private String token;
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override public void onServiceConnected() {
        super.onServiceConnected();
        SharedPreferences prefs = getSharedPreferences("bridge", MODE_PRIVATE);
        token = prefs.getString("token", null);
        if (token == null) {
            byte[] b = new byte[32]; new SecureRandom().nextBytes(b);
            token = Base64.encodeToString(b, Base64.URL_SAFE | Base64.NO_WRAP | Base64.NO_PADDING);
            prefs.edit().putString("token", token).apply();
        }
        running = true;
        pool = Executors.newSingleThreadExecutor();
        pool.execute(() -> serve());
    }

    private void serve() {
        try (ServerSocket ss = new ServerSocket(8765, 8, java.net.InetAddress.getByName("127.0.0.1"))) {
            server = ss;
            while (running) {
                Socket s = ss.accept();
                s.setSoTimeout(3000);
                handle(s);
            }
        } catch (Exception ignored) { /* Service may be stopped by Android. Never log tokens or requests. */ }
    }

    private void handle(Socket socket) {
        try (Socket s = socket;
             BufferedReader in = new BufferedReader(new InputStreamReader(s.getInputStream(), "UTF-8"));
             OutputStream out = s.getOutputStream()) {
            String first = in.readLine();
            if (first == null) return;
            String[] parts = first.split(" ");
            String method = parts.length > 0 ? parts[0] : "";
            String path = parts.length > 1 ? parts[1] : "/";
            String supplied = "";
            String line;
            int contentLength = 0;
            while ((line = in.readLine()) != null && !line.isEmpty()) {
                int colon = line.indexOf(':');
                if (colon > 0) {
                    String key = line.substring(0, colon).trim();
                    String value = line.substring(colon + 1).trim();
                    if (key.equalsIgnoreCase("X-Grey-Token")) supplied = value;
                    if (key.equalsIgnoreCase("Content-Length")) try { contentLength = Math.min(4096, Integer.parseInt(value)); } catch (Exception ignored) {}
                }
            }
            if (!constantTimeEquals(token, supplied)) { respond(out, 401, "{\"error\":\"unauthorized\"}"); return; }
            JSONObject result;
            if (method.equals("GET") && path.equals("/health")) {
                result = new JSONObject().put("ok", true).put("service", "grey-chrome-bridge").put("port", 8765);
            } else if (method.equals("GET") && path.equals("/windows")) {
                final JSONObject[] holder = new JSONObject[1];
                final Object lock = new Object();
                handler.post(() -> { try { holder[0] = visibleWindow(); } catch (Exception e) { holder[0] = new JSONObject(); } synchronized(lock) { lock.notifyAll(); } });
                synchronized(lock) { lock.wait(2000); }
                result = holder[0] == null ? new JSONObject().put("error", "window_unavailable") : holder[0];
            } else if (method.equals("POST") && path.startsWith("/tap?")) {
                int x = queryInt(path, "x"), y = queryInt(path, "y");
                handler.post(() -> tap(x, y));
                result = new JSONObject().put("accepted", true).put("action", "tap");
            } else if (method.equals("POST") && path.startsWith("/scroll?")) {
                String dir = query(path, "direction");
                handler.post(() -> scroll(dir));
                result = new JSONObject().put("accepted", true).put("action", "scroll").put("direction", dir);
            } else {
                respond(out, 404, "{\"error\":\"not_found\"}"); return;
            }
            respond(out, 200, result.toString());
        } catch (Exception ignored) { }
    }

    private JSONObject visibleWindow() throws Exception {
        JSONObject o = new JSONObject();
        o.put("activePackage", getRootInActiveWindow() == null ? "" : String.valueOf(getRootInActiveWindow().getPackageName()));
        JSONArray items = new JSONArray();
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root != null) collectVisible(root, items, 0);
        o.put("visibleText", items);
        o.put("note", "Visible accessibility labels only; editable text fields are excluded.");
        return o;
    }

    private void collectVisible(AccessibilityNodeInfo node, JSONArray items, int depth) throws Exception {
        if (node == null || depth > 30 || items.length() >= 120) return;
        if (node.isVisibleToUser() && !node.isPassword() && !node.isEditable()) {
            CharSequence t = node.getText();
            CharSequence d = node.getContentDescription();
            String value = t != null ? t.toString() : (d != null ? d.toString() : "");
            if (!value.trim().isEmpty()) {
                Rect b = new Rect(); node.getBoundsInScreen(b);
                items.put(new JSONObject().put("text", value.substring(0, Math.min(300, value.length())))
                    .put("clickable", node.isClickable()).put("x", b.centerX()).put("y", b.centerY()));
            }
        }
        for (int i = 0; i < node.getChildCount(); i++) collectVisible(node.getChild(i), items, depth + 1);
    }

    private void tap(int x, int y) {
        Path p = new Path(); p.moveTo(x, y);
        GestureDescription g = new GestureDescription.Builder().addStroke(new GestureDescription.StrokeDescription(p, 0, 80)).build();
        dispatchGesture(g, null, null);
    }
    private void scroll(String direction) {
        Point size = new Point(); getSystemService(android.view.WindowManager.class).getDefaultDisplay().getRealSize(size);
        int x = size.x / 2, top = size.y / 3, bottom = size.y * 2 / 3;
        Path p = new Path();
        if ("down".equals(direction)) { p.moveTo(x, top); p.lineTo(x, bottom); }
        else { p.moveTo(x, bottom); p.lineTo(x, top); }
        dispatchGesture(new GestureDescription.Builder().addStroke(new GestureDescription.StrokeDescription(p, 0, 350)).build(), null, null);
    }
    private int queryInt(String path, String key) { try { return Integer.parseInt(query(path, key)); } catch (Exception e) { return -1; } }
    private String query(String path, String key) {
        try { for (String part : path.substring(path.indexOf('?') + 1).split("&")) { String[] kv = part.split("=", 2); if (kv.length == 2 && kv[0].equals(key)) return java.net.URLDecoder.decode(kv[1], "UTF-8"); } } catch (Exception ignored) {}
        return "";
    }
    private boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        return java.security.MessageDigest.isEqual(a.getBytes(java.nio.charset.StandardCharsets.UTF_8), b.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }
    private void respond(OutputStream out, int code, String body) throws Exception {
        byte[] bytes = body.getBytes("UTF-8");
        String status = code == 200 ? "OK" : (code == 401 ? "Unauthorized" : "Not Found");
        out.write(("HTTP/1.1 " + code + " " + status + "\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: " + bytes.length + "\r\nConnection: close\r\n\r\n").getBytes("UTF-8"));
        out.write(bytes); out.flush();
    }
    @Override public void onAccessibilityEvent(AccessibilityEvent event) { }
    @Override public void onInterrupt() { }
    @Override public void onDestroy() {
        running = false;
        try { if (server != null) server.close(); } catch (Exception ignored) {}
        if (pool != null) pool.shutdownNow();
        super.onDestroy();
    }
}
