.class public Lcom/godmode/trader/HttpTask;
.super Ljava/lang/Object;
.source "HttpTask.java"

# 백그라운드 스레드에서 HttpURLConnection 으로 요청하고 결과를 JS 로 돌려줌

.implements Ljava/lang/Runnable;

.field public act:Lcom/godmode/trader/MainActivity;
.field public id:Ljava/lang/String;
.field public method:Ljava/lang/String;
.field public url:Ljava/lang/String;
.field public headers:Ljava/lang/String;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public run()V
    .registers 10

    :try_start
    new-instance v0, Ljava/net/URL;
    iget-object v1, p0, Lcom/godmode/trader/HttpTask;->url:Ljava/lang/String;
    invoke-direct {v0, v1}, Ljava/net/URL;-><init>(Ljava/lang/String;)V
    invoke-virtual {v0}, Ljava/net/URL;->openConnection()Ljava/net/URLConnection;
    move-result-object v0
    check-cast v0, Ljava/net/HttpURLConnection;

    iget-object v1, p0, Lcom/godmode/trader/HttpTask;->method:Ljava/lang/String;
    invoke-virtual {v0, v1}, Ljava/net/HttpURLConnection;->setRequestMethod(Ljava/lang/String;)V
    const/16 v1, 0x2710
    invoke-virtual {v0, v1}, Ljava/net/HttpURLConnection;->setConnectTimeout(I)V
    invoke-virtual {v0, v1}, Ljava/net/HttpURLConnection;->setReadTimeout(I)V

    # 요청 헤더 (JSON 객체)
    new-instance v1, Lorg/json/JSONObject;
    iget-object v2, p0, Lcom/godmode/trader/HttpTask;->headers:Ljava/lang/String;
    invoke-direct {v1, v2}, Lorg/json/JSONObject;-><init>(Ljava/lang/String;)V
    invoke-virtual {v1}, Lorg/json/JSONObject;->keys()Ljava/util/Iterator;
    move-result-object v2
    :hloop
    invoke-interface {v2}, Ljava/util/Iterator;->hasNext()Z
    move-result v3
    if-eqz v3, :hdone
    invoke-interface {v2}, Ljava/util/Iterator;->next()Ljava/lang/Object;
    move-result-object v3
    check-cast v3, Ljava/lang/String;
    invoke-virtual {v1, v3}, Lorg/json/JSONObject;->getString(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v4
    invoke-virtual {v0, v3, v4}, Ljava/net/HttpURLConnection;->setRequestProperty(Ljava/lang/String;Ljava/lang/String;)V
    goto :hloop
    :hdone

    # POST 는 파라미터가 쿼리스트링에 있으므로 빈 본문을 명시적으로 전송
    const-string v1, "POST"
    iget-object v2, p0, Lcom/godmode/trader/HttpTask;->method:Ljava/lang/String;
    invoke-virtual {v1, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v1
    if-eqz v1, :nobody
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Ljava/net/HttpURLConnection;->setDoOutput(Z)V
    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->getOutputStream()Ljava/io/OutputStream;
    move-result-object v1
    invoke-virtual {v1}, Ljava/io/OutputStream;->close()V
    :nobody

    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->getResponseCode()I
    move-result v5
    const/16 v1, 0x190
    if-lt v5, v1, :ok
    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->getErrorStream()Ljava/io/InputStream;
    move-result-object v1
    goto :read
    :ok
    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->getInputStream()Ljava/io/InputStream;
    move-result-object v1
    :read
    new-instance v2, Ljava/io/ByteArrayOutputStream;
    invoke-direct {v2}, Ljava/io/ByteArrayOutputStream;-><init>()V
    if-eqz v1, :readdone
    const/16 v3, 0x2000
    new-array v3, v3, [B
    :rloop
    invoke-virtual {v1, v3}, Ljava/io/InputStream;->read([B)I
    move-result v4
    if-ltz v4, :rclose
    const/4 v6, 0x0
    invoke-virtual {v2, v3, v6, v4}, Ljava/io/ByteArrayOutputStream;->write([BII)V
    goto :rloop
    :rclose
    invoke-virtual {v1}, Ljava/io/InputStream;->close()V
    :readdone
    const-string v1, "UTF-8"
    invoke-virtual {v2, v1}, Ljava/io/ByteArrayOutputStream;->toString(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->disconnect()V

    invoke-virtual {p0, v5, v2}, Lcom/godmode/trader/HttpTask;->reply(ILjava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    return-void

    :err
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v0
    const/4 v1, 0x0
    invoke-virtual {p0, v1, v0}, Lcom/godmode/trader/HttpTask;->reply(ILjava/lang/String;)V
    return-void
.end method

# window.__ahttp("id", status, "body")
.method public reply(ILjava/lang/String;)V
    .registers 6
    new-instance v0, Ljava/lang/StringBuilder;
    const-string v1, "window.__ahttp&&window.__ahttp("
    invoke-direct {v0, v1}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    iget-object v1, p0, Lcom/godmode/trader/HttpTask;->id:Ljava/lang/String;
    invoke-static {v1}, Lorg/json/JSONObject;->quote(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, ","
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, ","
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {p2}, Lorg/json/JSONObject;->quote(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, ")"
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    iget-object v2, p0, Lcom/godmode/trader/HttpTask;->act:Lcom/godmode/trader/MainActivity;
    invoke-virtual {v2, v1}, Lcom/godmode/trader/MainActivity;->runJs(Ljava/lang/String;)V
    return-void
.end method
