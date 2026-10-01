# Binance USDⓈ-M 선물 수동매매 도우미 (Half-Kelly)

`binance_futures_kelly.py` — Kelly/Half-Kelly 기준으로 포지션 크기와 필요 증거금을 계산하고, **진입 주문만** 넣는 CLI입니다.
TP/SL 주문은 자동으로 걸지 않습니다. 손절·익절은 직접 판단해서 관리하세요.

> 같은 저장소의 `index.html`(GOD MODE 차트)은 별개의 웹 화면입니다. 이 CLI와는 독립적으로 동작합니다.

## 설치

```bash
pip install python-binance python-dotenv
cp .env.example .env      # 그 다음 .env 에 키 입력
```

`.env`

```
BINANCE_API_KEY=발급받은_키
BINANCE_API_SECRET=발급받은_시크릿
BINANCE_FUTURES_TESTNET=true   # 테스트넷이면 true, 실계좌면 false
```

모든 출력 앞에 `[TESTNET]` / `[LIVE]` 가 붙어서 지금 어느 계좌에 주문하는지 바로 보입니다.

## 명령어

```bash
# 1) 계정/심볼 설정 (한 번만)
python binance_futures_kelly.py set_leverage BTCUSDT 20
python binance_futures_kelly.py set_margin_mode BTCUSDT isolated     # isolated | cross
python binance_futures_kelly.py set_position_mode oneway             # oneway | hedge

# 2) 크기 계산 (주문 안 나감)
python binance_futures_kelly.py calc_kelly_long  BTCUSDT 60000 59400 0.55 1000 true
python binance_futures_kelly.py calc_kelly_short BTCUSDT 60000 60600 0.55 1000 true --reward_ratio 3

# 3) 메인: Kelly 크기 + 내가 정한 레버리지에서의 필요 증거금 (주문 안 나감)
python binance_futures_kelly.py plan_position BTCUSDT 60000 59400 0.55 1000 true 20
#   방향은 자동 판단: stop < entry 이면 롱, stop > entry 이면 숏

# 4) 진입 주문 (plan_position 에서 나온 수량을 그대로 입력)
python binance_futures_kelly.py market_long  BTCUSDT 0.002
python binance_futures_kelly.py market_short BTCUSDT 0.002
python binance_futures_kelly.py limit_long   BTCUSDT 59500 0.002
python binance_futures_kelly.py limit_short  BTCUSDT 60500 0.002

# 5) 조회 / 정리
python binance_futures_kelly.py cancel_all BTCUSDT
python binance_futures_kelly.py position BTCUSDT
python binance_futures_kelly.py balance
```

인자 순서: `<symbol> <entry_price> <stop_price> <win_prob> <bankroll> <half> [<leverage>] [--reward_ratio R]`

- 수량은 심볼의 stepSize에 맞춰 **내림**, 지정가는 tickSize에 맞춰 반올림한 뒤 주문합니다.
- 헤지 모드 계정이면 `positionSide`(LONG/SHORT)를 자동으로 붙입니다. 이 명령들은 **진입 전용**입니다.
- `cancel_all`은 일반 미체결 주문만 취소합니다. 바이낸스 앱에서 걸어둔 조건부(스탑) 주문은 건드리지 않습니다.

## 계산 방식

**Kelly**

```
p = 승률, q = 1 - p, b = reward_ratio (기본 2.0)
f* = (p·b − q) / b          f* ≤ 0 이면 "Kelly suggests no position"
half = true  →  f = f*/2    (Half-Kelly: 성장률은 약 75% 유지, 변동성은 절반)
notional = f × bankroll     quantity = notional / entry_price
```

`R = |entry − stop| / entry`(손절 거리)는 출력의 `stop distance`와 `Loss if stop hit = notional × R`에 쓰입니다.

**증거금**

```
required_margin = notional / leverage
margin_ratio    = required_margin / bankroll
```

레버리지를 올리면 **포지션 크기(notional)는 그대로**이고, 묶이는 증거금만 줄어듭니다. 그 대신 청산가가 진입가에 가까워집니다.

- margin_ratio > 50% → `Warning: initial margin uses more than 50% of bankroll.`
- margin_ratio > 80% → `Warning: very high margin usage; small adverse moves may trigger liquidation.`
- 손절 거리 ≥ 약 1/레버리지 → 손절가보다 **청산가에 먼저 닿는다**는 경고 (격리 기준 근사치)

> 참고: 여기서는 Kelly f 를 "명목가 비중"으로 씁니다(요구사항 그대로). 그래서 손절에 걸렸을 때 실제 손실은 `f × R × bankroll`로, f보다 훨씬 작습니다. 이 손실을 정확히 `f × bankroll`로 맞추고 싶다면 notional을 `f × bankroll / R`로 계산해야 합니다.

## 보안 / 주의

- `.env`는 **절대 커밋하지 마세요** (`.gitignore`에 들어 있습니다). 키와 시크릿은 남에게 보여주지 마세요.
- 바이낸스 API 설정에서 **IP 화이트리스트**를 켜고, **출금 권한은 끄고**, 선물 거래 권한만 주세요.
- 먼저 **선물 테스트넷**(`BINANCE_FUTURES_TESTNET=true`, testnet.binancefuture.com에서 발급한 키)에서 충분히 확인하세요.
- 레버리지가 높을수록 청산 위험이 커집니다. Kelly는 **베팅 크기만** 정할 뿐, 청산 구조는 고려하지 않습니다.
- 레버리지 입력 범위는 2–129입니다. 다만 실제 최대치는 심볼과 포지션 구간마다 다릅니다(BTCUSDT는 보통 125x). 그보다 높게 넣으면 바이낸스가 거부합니다.
