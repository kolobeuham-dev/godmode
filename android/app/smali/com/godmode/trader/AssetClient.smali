.class public Lcom/godmode/trader/AssetClient;
.super Landroid/webkit/WebViewClient;
.source "AssetClient.java"

# https://appassets.androidplatform.net/<path> 요청을 APK assets/<path> 로 응답

.field private act:Landroid/app/Activity;

.method public constructor <init>(Landroid/app/Activity;)V
    .registers 2
    invoke-direct {p0}, Landroid/webkit/WebViewClient;-><init>()V
    iput-object p1, p0, Lcom/godmode/trader/AssetClient;->act:Landroid/app/Activity;
    return-void
.end method

.method public shouldInterceptRequest(Landroid/webkit/WebView;Landroid/webkit/WebResourceRequest;)Landroid/webkit/WebResourceResponse;
    .registers 8

    invoke-interface {p2}, Landroid/webkit/WebResourceRequest;->getUrl()Landroid/net/Uri;
    move-result-object v0
    invoke-virtual {v0}, Landroid/net/Uri;->getHost()Ljava/lang/String;
    move-result-object v1
    const-string v2, "appassets.androidplatform.net"
    invoke-virtual {v2, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v1
    if-eqz v1, :pass

    invoke-virtual {v0}, Landroid/net/Uri;->getPath()Ljava/lang/String;
    move-result-object v1
    if-eqz v1, :pass
    const/4 v2, 0x1
    invoke-virtual {v1, v2}, Ljava/lang/String;->substring(I)Ljava/lang/String;
    move-result-object v1

    :try_start
    iget-object v2, p0, Lcom/godmode/trader/AssetClient;->act:Landroid/app/Activity;
    invoke-virtual {v2}, Landroid/app/Activity;->getAssets()Landroid/content/res/AssetManager;
    move-result-object v2
    invoke-virtual {v2, v1}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v2
    :try_end
    .catch Ljava/io/IOException; {:try_start .. :try_end} :pass

    invoke-static {v1}, Ljava/net/URLConnection;->guessContentTypeFromName(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    if-nez v0, :mime_ok
    const-string v0, "application/octet-stream"
    :mime_ok
    new-instance v3, Landroid/webkit/WebResourceResponse;
    const-string v4, "utf-8"
    invoke-direct {v3, v0, v4, v2}, Landroid/webkit/WebResourceResponse;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/io/InputStream;)V
    return-object v3

    :pass
    const/4 v0, 0x0
    return-object v0
.end method
