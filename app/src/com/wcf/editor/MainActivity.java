package com.wcf.editor;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.OutputStream;

/**
 * WebView shell for the "吾苍耳冯福" five-character codec page.
 *
 * The page ships inside the APK (assets/index.html) so everything runs offline.
 * After each page load a small shim is injected that:
 *   1. routes clipboard writes to the real Android clipboard (navigator.clipboard
 *      is unreliable for file:// documents inside WebView), and
 *   2. maps window.close() to Activity.finish(), so the "不同意，退出应用"
 *      button actually leaves the app instead of being silently ignored.
 *
 * Saving a stub as .txt goes through ACTION_CREATE_DOCUMENT: no storage
 * permission is needed on any API level, and the user picks the folder.
 *
 * Sharing: the activity also accepts ACTION_SEND text/plain from other apps.
 * Incoming text is parked in pendingShare and pulled by the page itself
 * (window.wcfPull -> AndroidShell.takeShared), so no string escaping ever
 * happens on the Java side. Outgoing text goes through the system chooser.
 */
public class MainActivity extends Activity {

    private static final String START_URL = "file:///android_asset/index.html";
    private static final int BG = 0xFF0B1220;
    private static final int REQ_SAVE_TEXT = 4001;

    private static final String SHIM =
            "(function(){"
          + "try{"
          + "Object.defineProperty(navigator,'clipboard',{configurable:true,value:{"
          + "writeText:function(t){try{AndroidShell.copyToClipboard(String(t));}catch(e){}"
          + "return Promise.resolve();}"
          + "}});"
          + "}catch(e){}"
          + "try{window.close=function(){try{AndroidShell.closeApp();}catch(e){}};}catch(e){}"
          + "})();";

    private WebView webView;
    private String pendingName;
    private String pendingText;
    /** Text handed to us by another app, waiting for the page to pull it. */
    private String pendingShare;

    /** Only plain text from ACTION_SEND is interesting; everything else is dropped. */
    private static String extractShared(Intent intent) {
        if (intent == null || !Intent.ACTION_SEND.equals(intent.getAction())) {
            return null;
        }
        CharSequence cs = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
        if (cs == null) {
            return null;
        }
        String text = cs.toString().trim();
        if (text.isEmpty() || text.length() > 20000) {
            return null;
        }
        return text;
    }

    private class ShellBridge {
        @JavascriptInterface
        public void copyToClipboard(final String text) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
                    if (cm != null) {
                        cm.setPrimaryClip(ClipData.newPlainText("wcf", text));
                    }
                }
            });
        }

        @JavascriptInterface
        public void closeApp() {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    finish();
                }
            });
        }

        /** JS calls this from the WebView's JavaBridge thread, so bounce to UI. */
        @JavascriptInterface
        public void saveText(final String fileName, final String content) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    pendingName = fileName;
                    pendingText = content;
                    Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    i.addCategory(Intent.CATEGORY_OPENABLE);
                    i.setType("text/plain");
                    i.putExtra(Intent.EXTRA_TITLE, fileName);
                    try {
                        startActivityForResult(i, REQ_SAVE_TEXT);
                    } catch (Exception e) {
                        pendingName = null;
                        pendingText = null;
                        toast("无法打开保存对话框");
                    }
                }
            });
        }

        /** Returns the parked share text once, then forgets it ("" when there is none). */
        @JavascriptInterface
        public String takeShared() {
            String text = pendingShare;
            pendingShare = null;
            return text == null ? "" : text;
        }

        @JavascriptInterface
        public void shareText(final String text) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    if (text == null || text.isEmpty()) {
                        return;
                    }
                    Intent send = new Intent(Intent.ACTION_SEND);
                    send.setType("text/plain");
                    send.putExtra(Intent.EXTRA_TEXT, text);
                    try {
                        startActivity(Intent.createChooser(send, "发给朋友"));
                    } catch (Exception e) {
                        toast("这台设备没有可用的分享方式");
                    }
                }
            });
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_SAVE_TEXT) {
            return;
        }
        Uri uri = (resultCode == RESULT_OK && data != null) ? data.getData() : null;
        if (uri == null || pendingText == null) {
            pendingName = null;
            pendingText = null;
            return;
        }
        String name = pendingName;
        try {
            OutputStream os = getContentResolver().openOutputStream(uri, "wt");
            if (os == null) {
                throw new java.io.IOException("cannot open output stream");
            }
            try {
                os.write(pendingText.getBytes("UTF-8"));
                os.flush();
            } finally {
                os.close();
            }
            toast("已保存 " + name);
        } catch (Exception e) {
            toast("保存失败：" + e.getMessage());
        } finally {
            pendingName = null;
            pendingText = null;
        }
    }

    /** Park anything another app shared with us; the page pulls it when ready. */
    private void handleShareIntent(Intent intent) {
        String text = extractShared(intent);
        if (text != null) {
            pendingShare = text;
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleShareIntent(intent);
        if (webView != null) {
            webView.evaluateJavascript("try{window.wcfPull&&window.wcfPull();}catch(e){}", null);
        }
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setBackgroundDrawable(new ColorDrawable(BG));
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);

        webView = new WebView(this);
        webView.setBackgroundColor(BG);
        webView.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);

        webView.addJavascriptInterface(new ShellBridge(), "AndroidShell");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url != null && url.startsWith("file://")) {
                    return false;
                }
                // Nothing in this app should leave the bundled page. If a link
                // ever shows up, hand it to the system browser instead of
                // loading foreign content into a WebView that exposes the bridge.
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                } catch (Exception ignored) {
                }
                return true;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                // The shim first (clipboard / window.close), then let the page pick
                // up anything that arrived with the launch intent.
                view.evaluateJavascript(SHIM + "try{window.wcfPull&&window.wcfPull();}catch(e){}", null);
            }
        });

        webView.setWebChromeClient(new WebChromeClient());

        setContentView(webView);
        handleShareIntent(getIntent());
        webView.loadUrl(START_URL);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (webView != null && webView.canGoBack()) {
                webView.goBack();
            } else {
                finish();
            }
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.loadUrl("about:blank");
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
}
