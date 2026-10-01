.class public Lcom/godmode/trader/JsRunnable;
.super Ljava/lang/Object;
.source "JsRunnable.java"

# UI 스레드에서 webView.evaluateJavascript(js)

.implements Ljava/lang/Runnable;

.field private w:Landroid/webkit/WebView;
.field private js:Ljava/lang/String;

.method public constructor <init>(Landroid/webkit/WebView;Ljava/lang/String;)V
    .registers 3
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lcom/godmode/trader/JsRunnable;->w:Landroid/webkit/WebView;
    iput-object p2, p0, Lcom/godmode/trader/JsRunnable;->js:Ljava/lang/String;
    return-void
.end method

.method public run()V
    .registers 4
    iget-object v0, p0, Lcom/godmode/trader/JsRunnable;->w:Landroid/webkit/WebView;
    iget-object v1, p0, Lcom/godmode/trader/JsRunnable;->js:Ljava/lang/String;
    const/4 v2, 0x0
    invoke-virtual {v0, v1, v2}, Landroid/webkit/WebView;->evaluateJavascript(Ljava/lang/String;Landroid/webkit/ValueCallback;)V
    return-void
.end method
