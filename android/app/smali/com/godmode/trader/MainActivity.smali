.class public Lcom/godmode/trader/MainActivity;
.super Landroid/app/Activity;
.source "MainActivity.java"

# 단일 WebView 액티비티: 앱 안의 index.html 을 https://appassets.androidplatform.net 으로 띄움

.field public web:Landroid/webkit/WebView;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/app/Activity;-><init>()V
    return-void
.end method

.method protected onCreate(Landroid/os/Bundle;)V
    .registers 6

    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    # 상태바: 흰 배경 + 어두운 아이콘
    invoke-virtual {p0}, Lcom/godmode/trader/MainActivity;->getWindow()Landroid/view/Window;
    move-result-object v0
    const/4 v1, -0x1
    invoke-virtual {v0, v1}, Landroid/view/Window;->setStatusBarColor(I)V
    invoke-virtual {v0}, Landroid/view/Window;->getDecorView()Landroid/view/View;
    move-result-object v0
    const/16 v1, 0x2000
    invoke-virtual {v0, v1}, Landroid/view/View;->setSystemUiVisibility(I)V

    new-instance v0, Landroid/webkit/WebView;
    invoke-direct {v0, p0}, Landroid/webkit/WebView;-><init>(Landroid/content/Context;)V
    iput-object v0, p0, Lcom/godmode/trader/MainActivity;->web:Landroid/webkit/WebView;

    invoke-virtual {v0}, Landroid/webkit/WebView;->getSettings()Landroid/webkit/WebSettings;
    move-result-object v1
    const/4 v2, 0x1
    invoke-virtual {v1, v2}, Landroid/webkit/WebSettings;->setJavaScriptEnabled(Z)V
    invoke-virtual {v1, v2}, Landroid/webkit/WebSettings;->setDomStorageEnabled(Z)V
    const/4 v3, 0x0
    invoke-virtual {v1, v3}, Landroid/webkit/WebSettings;->setAllowFileAccess(Z)V

    new-instance v1, Lcom/godmode/trader/AssetClient;
    invoke-direct {v1, p0}, Lcom/godmode/trader/AssetClient;-><init>(Landroid/app/Activity;)V
    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->setWebViewClient(Landroid/webkit/WebViewClient;)V

    # confirm()/alert() 대화상자 표시용
    new-instance v1, Landroid/webkit/WebChromeClient;
    invoke-direct {v1}, Landroid/webkit/WebChromeClient;-><init>()V
    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->setWebChromeClient(Landroid/webkit/WebChromeClient;)V

    # 바이낸스 REST 호출은 네이티브 HTTP 로 (CORS 영향 없음)
    new-instance v1, Lcom/godmode/trader/Bridge;
    invoke-direct {v1, p0}, Lcom/godmode/trader/Bridge;-><init>(Lcom/godmode/trader/MainActivity;)V
    const-string v2, "AndroidHttp"
    invoke-virtual {v0, v1, v2}, Landroid/webkit/WebView;->addJavascriptInterface(Ljava/lang/Object;Ljava/lang/String;)V

    invoke-virtual {p0, v0}, Lcom/godmode/trader/MainActivity;->setContentView(Landroid/view/View;)V

    const-string v1, "https://appassets.androidplatform.net/index.html"
    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->loadUrl(Ljava/lang/String;)V
    return-void
.end method

.method public runJs(Ljava/lang/String;)V
    .registers 4
    iget-object v0, p0, Lcom/godmode/trader/MainActivity;->web:Landroid/webkit/WebView;
    if-eqz v0, :done
    new-instance v1, Lcom/godmode/trader/JsRunnable;
    invoke-direct {v1, v0, p1}, Lcom/godmode/trader/JsRunnable;-><init>(Landroid/webkit/WebView;Ljava/lang/String;)V
    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->post(Ljava/lang/Runnable;)Z
    :done
    return-void
.end method

.method public onBackPressed()V
    .registers 3
    # 뒤로가기: 앱을 종료하지 않고 백그라운드로
    const/4 v0, 0x1
    invoke-virtual {p0, v0}, Lcom/godmode/trader/MainActivity;->moveTaskToBack(Z)Z
    return-void
.end method
