.class public Lcom/godmode/trader/Bridge;
.super Ljava/lang/Object;
.source "Bridge.java"

# JS: AndroidHttp.request(id, method, url, headersJson) -> 결과는 window.__ahttp(id, status, body)

.field private act:Lcom/godmode/trader/MainActivity;

.method public constructor <init>(Lcom/godmode/trader/MainActivity;)V
    .registers 2
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput-object p1, p0, Lcom/godmode/trader/Bridge;->act:Lcom/godmode/trader/MainActivity;
    return-void
.end method

.method public request(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V
    .registers 8
    .annotation runtime Landroid/webkit/JavascriptInterface;
    .end annotation

    new-instance v0, Lcom/godmode/trader/HttpTask;
    invoke-direct {v0}, Lcom/godmode/trader/HttpTask;-><init>()V
    iget-object v1, p0, Lcom/godmode/trader/Bridge;->act:Lcom/godmode/trader/MainActivity;
    iput-object v1, v0, Lcom/godmode/trader/HttpTask;->act:Lcom/godmode/trader/MainActivity;
    iput-object p1, v0, Lcom/godmode/trader/HttpTask;->id:Ljava/lang/String;
    iput-object p2, v0, Lcom/godmode/trader/HttpTask;->method:Ljava/lang/String;
    iput-object p3, v0, Lcom/godmode/trader/HttpTask;->url:Ljava/lang/String;
    iput-object p4, v0, Lcom/godmode/trader/HttpTask;->headers:Ljava/lang/String;

    new-instance v1, Ljava/lang/Thread;
    invoke-direct {v1, v0}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V
    invoke-virtual {v1}, Ljava/lang/Thread;->start()V
    return-void
.end method
