#!/usr/bin/env python3
"""Manual Binance USDⓈ-M Futures assistant: Half-Kelly sizing + entry orders only.

No automatic TP/SL. See README.md for usage.
"""
import argparse
import os
import sys
from decimal import ROUND_DOWN, ROUND_HALF_UP, Decimal

from dotenv import load_dotenv

try:
    from binance.client import Client
    from binance.exceptions import BinanceAPIException, BinanceRequestException
except ImportError:
    sys.exit("python-binance not installed. Run: pip install python-binance python-dotenv")

LEV_MIN, LEV_MAX = 2, 129
DEFAULT_REWARD_RATIO = 2.0

AUTH_MSG = "API key invalid or missing required permissions. Check Binance API settings."
ERROR_HINTS = {
    -1021: "Local clock is out of sync with Binance. Sync your system time.",
    -1022: AUTH_MSG,
    -2008: AUTH_MSG,
    -2014: AUTH_MSG,
    -2015: AUTH_MSG + " (Futures permission enabled? IP whitelisted?)",
    -1121: "Invalid symbol. Use a USDⓈ-M symbol such as BTCUSDT.",
    -1111: "Price/quantity has too many decimals for this symbol.",
    -2019: "Insufficient margin. Reduce quantity or raise leverage.",
    -2027: "Position would exceed the maximum allowed at current leverage. Lower leverage or size.",
    -4003: "Quantity must be greater than zero.",
    -4164: "Order notional is below the symbol's minimum. Increase quantity.",
    -4028: "Leverage not valid for this symbol (above its maximum bracket).",
    -4046: "Margin mode is already set to that value.",
    -4047: "Cannot change margin mode while there are open orders.",
    -4048: "Cannot change margin mode while a position is open.",
    -4059: "Position mode is already set to that value.",
    -4067: "Cannot change position mode while there are open orders.",
    -4068: "Cannot change position mode while a position is open.",
}


class CliError(Exception):
    pass


# ---------- setup ----------

def env_testnet():
    return os.getenv("BINANCE_FUTURES_TESTNET", "false").strip().lower() in ("1", "true", "yes")


def get_client(auth=True):
    key, secret = os.getenv("BINANCE_API_KEY"), os.getenv("BINANCE_API_SECRET")
    if auth and (not key or not secret):
        raise CliError("BINANCE_API_KEY / BINANCE_API_SECRET not set. Copy .env.example to .env and fill them in.")
    return Client(key or None, secret or None, testnet=env_testnet(), ping=False)


def net_label():
    return "TESTNET" if env_testnet() else "LIVE"


def sym(s):
    return s.strip().upper()


def check_leverage(lev):
    if not LEV_MIN <= lev <= LEV_MAX:
        raise CliError(f"Leverage must be between {LEV_MIN} and {LEV_MAX} (got {lev}).")


def parse_bool(s):
    v = s.strip().lower()
    if v in ("true", "t", "1", "yes", "y"):
        return True
    if v in ("false", "f", "0", "no", "n"):
        return False
    raise argparse.ArgumentTypeError(f"expected true/false, got '{s}'")


def fmt(x, nd=4):
    return f"{x:,.{nd}f}"


# ---------- symbol filters (rounding to tick/step) ----------

_filters_cache = {}


def symbol_filters(client, symbol):
    if symbol not in _filters_cache:
        info = client.futures_exchange_info()
        s = next((x for x in info["symbols"] if x["symbol"] == symbol), None)
        if s is None:
            raise CliError(f"Symbol {symbol} not found on USDⓈ-M Futures.")
        f = {x["filterType"]: x for x in s["filters"]}
        _filters_cache[symbol] = {
            "tick": Decimal(f["PRICE_FILTER"]["tickSize"]),
            "step": Decimal(f["LOT_SIZE"]["stepSize"]),
            "min_qty": Decimal(f["LOT_SIZE"]["minQty"]),
            "min_notional": Decimal(f.get("MIN_NOTIONAL", {}).get("notional", "0")),
        }
    return _filters_cache[symbol]


def quantize(value, step, rounding):
    step = step.normalize()
    q = (Decimal(str(value)) / step).quantize(Decimal(1), rounding=rounding) * step
    return format(q.quantize(step), "f")


def round_qty(client, symbol, qty):
    f = symbol_filters(client, symbol)
    q = quantize(qty, f["step"], ROUND_DOWN)
    if Decimal(q) <= 0:
        raise CliError(f"Quantity {qty} rounds to 0 (step size {f['step'].normalize()}).")
    if Decimal(q) < f["min_qty"]:
        raise CliError(f"Quantity {q} is below minimum {f['min_qty'].normalize()} for {symbol}.")
    return q


def round_price(client, symbol, price):
    return quantize(price, symbol_filters(client, symbol)["tick"], ROUND_HALF_UP)


def is_hedge_mode(client):
    return bool(client.futures_get_position_mode().get("dualSidePosition"))


# ---------- Kelly ----------

def kelly(entry, stop, p, bankroll, half, b, direction):
    if entry <= 0 or stop <= 0 or bankroll <= 0:
        raise CliError("entry_price, stop_price and bankroll must be positive.")
    if not 0 < p < 1:
        raise CliError("win_prob must be between 0 and 1 (e.g. 0.55).")
    if b <= 0:
        raise CliError("--reward_ratio must be positive.")
    risk = (entry - stop) / entry if direction == "long" else (stop - entry) / entry
    if risk <= 0:
        side = "below" if direction == "long" else "above"
        raise CliError(f"For a {direction}, stop_price must be {side} entry_price.")
    q = 1 - p
    f_full = (p * b - q) / b
    if f_full <= 0:
        return None
    f = f_full / 2 if half else f_full
    notional = f * bankroll
    return {"direction": direction, "risk": risk, "f_full": f_full, "f": f, "half": half,
            "notional": notional, "qty": notional / entry, "loss_at_stop": notional * risk}


def print_kelly(k, client, symbol, b):
    print(f"{symbol} {k['direction'].upper()}  stop distance {k['risk'] * 100:.3f}%  reward_ratio {b:g}")
    print(f"  Kelly f*          {k['f_full'] * 100:.2f}%")
    if k["half"]:
        print(f"  Half-Kelly f      {k['f'] * 100:.2f}%")
    print(f"  Notional          {fmt(k['notional'], 2)} USDT")
    qty_txt = f"{k['qty']:.8f}".rstrip("0").rstrip(".")
    if client is not None:
        try:
            qty_txt = f"{round_qty(client, symbol, k['qty'])}  (raw {qty_txt})"
        except CliError as e:
            qty_txt += f"  ({e})"
        except Exception:
            qty_txt += "  (not rounded: exchange info unavailable)"
    print(f"  Quantity          {qty_txt}")
    print(f"  Loss if stop hit  {fmt(k['loss_at_stop'], 2)} USDT")


def public_client():
    """Exchange info is public; used only to round quantity. Fails soft when offline."""
    try:
        return get_client(auth=False)
    except Exception:
        return None


def run_kelly(a, direction):
    symbol = sym(a.symbol)
    k = kelly(a.entry_price, a.stop_price, a.win_prob, a.bankroll, a.half, a.reward_ratio, direction)
    if k is None:
        print("Kelly suggests no position (f <= 0)")
        return None, symbol
    client = public_client()
    print_kelly(k, client, symbol, a.reward_ratio)
    return k, symbol


# ---------- commands ----------

def cmd_set_leverage(a):
    check_leverage(a.leverage)
    symbol = sym(a.symbol)
    try:
        r = get_client().futures_change_leverage(symbol=symbol, leverage=a.leverage)
    except BinanceAPIException as e:
        raise CliError(
            f"Leverage change failed: {friendly(e)}\n"
            "  Possible reasons: leverage above the symbol's max bracket, current position size\n"
            "  too large for that leverage, insufficient margin to lower leverage, or invalid symbol."
        )
    print(f"[{net_label()}] {symbol} leverage = {r['leverage']}x  (max notional {r.get('maxNotionalValue', '?')})")


def cmd_set_margin_mode(a):
    symbol, mode = sym(a.symbol), a.mode.upper()
    api_mode = {"ISOLATED": "ISOLATED", "CROSS": "CROSSED", "CROSSED": "CROSSED"}.get(mode)
    if api_mode is None:
        raise CliError("mode must be ISOLATED or CROSS.")
    try:
        get_client().futures_change_margin_type(symbol=symbol, marginType=api_mode)
    except BinanceAPIException as e:
        if e.code != -4046:
            raise
    print(f"[{net_label()}] {symbol} margin mode = {'CROSS' if api_mode == 'CROSSED' else 'ISOLATED'}")


def cmd_set_position_mode(a):
    mode = a.mode.upper().replace("-", "").replace("_", "")
    if mode not in ("ONEWAY", "HEDGE"):
        raise CliError("mode must be ONEWAY or HEDGE.")
    try:
        get_client().futures_change_position_mode(dualSidePosition="true" if mode == "HEDGE" else "false")
    except BinanceAPIException as e:
        if e.code != -4059:
            raise
    print(f"[{net_label()}] position mode = {mode}")


def cmd_calc_kelly_long(a):
    run_kelly(a, "long")


def cmd_calc_kelly_short(a):
    run_kelly(a, "short")


def cmd_plan_position(a):
    check_leverage(a.leverage)
    direction = "long" if a.stop_price < a.entry_price else "short"
    k, symbol = run_kelly(a, direction)
    if k is None:
        return
    margin = k["notional"] / a.leverage
    ratio = margin / a.bankroll
    print(f"  Leverage          {a.leverage}x")
    print(f"  Required margin   {fmt(margin, 2)} USDT")
    print(f"  Margin / bankroll {ratio * 100:.2f}%")
    if ratio > 0.8:
        print("Warning: very high margin usage; small adverse moves may trigger liquidation.")
    elif ratio > 0.5:
        print("Warning: initial margin uses more than 50% of bankroll.")
    if k["risk"] >= 1 / a.leverage:
        print(f"Warning: stop is {k['risk'] * 100:.2f}% away but {a.leverage}x liquidates around "
              f"{100 / a.leverage:.2f}% (isolated) — you would be liquidated before the stop.")


def place_order(a, side, order_type):
    client = get_client()
    symbol = sym(a.symbol)
    qty = round_qty(client, symbol, a.quantity)
    params = {"symbol": symbol, "side": side, "type": order_type, "quantity": qty, "newOrderRespType": "RESULT"}
    if order_type == "LIMIT":
        params.update(price=round_price(client, symbol, a.price), timeInForce="GTC")
    if is_hedge_mode(client):
        params["positionSide"] = "LONG" if side == "BUY" else "SHORT"
    r = client.futures_create_order(**params)
    line = f"[{net_label()}] {r['side']} {r['symbol']} {r['type']}"
    if order_type == "LIMIT":
        line += f" price={r['price']}"
    line += f" qty={r['origQty']} status={r['status']} id={r['orderId']}"
    if Decimal(r.get("avgPrice") or "0") > 0:
        line += f" avg={r['avgPrice']}"
    print(line)


def cmd_market_long(a):
    place_order(a, "BUY", "MARKET")


def cmd_market_short(a):
    place_order(a, "SELL", "MARKET")


def cmd_limit_long(a):
    place_order(a, "BUY", "LIMIT")


def cmd_limit_short(a):
    place_order(a, "SELL", "LIMIT")


def cmd_cancel_all(a):
    client, symbol = get_client(), sym(a.symbol)
    n = len(client.futures_get_open_orders(symbol=symbol))
    if n == 0:
        print(f"No open orders for {symbol}")
        return
    client.futures_cancel_all_open_orders(symbol=symbol)
    print(f"[{net_label()}] Cancelled {n} order(s) on {symbol}")


def cmd_position(a):
    client, symbol = get_client(), sym(a.symbol)
    rows = client.futures_position_information(symbol=symbol)
    # positionRisk v3 has no leverage/marginType; account v2 does.
    acct = {(p["symbol"], p.get("positionSide", "BOTH")): p
            for p in client.futures_account().get("positions", []) if p["symbol"] == symbol}
    open_rows = [p for p in rows if Decimal(p["positionAmt"]) != 0]
    if not open_rows:
        any_acct = next(iter(acct.values()), {})
        lev = any_acct.get("leverage", "?")
        mode = "ISOLATED" if any_acct.get("isolated") else "CROSS"
        mark = rows[0]["markPrice"] if rows else "?"
        print(f"{symbol}: none  mark={mark}  lev={lev}x  {mode}")
        return
    table = []
    for p in open_rows:
        amt = Decimal(p["positionAmt"])
        side = p.get("positionSide") if p.get("positionSide") in ("LONG", "SHORT") else ("LONG" if amt > 0 else "SHORT")
        extra = acct.get((symbol, p.get("positionSide", "BOTH")), {})
        lev = p.get("leverage") or extra.get("leverage", "?")
        mt = p.get("marginType") or ("isolated" if extra.get("isolated") else "cross")
        table.append([side, str(abs(amt)), p["entryPrice"], p["markPrice"], p["unRealizedProfit"], f"{lev}x",
                      "ISOLATED" if mt.lower() == "isolated" else "CROSS"])
    for t in table:
        print(f"{symbol} {t[0]} {t[1]} @ {fmt(float(t[2]), 2)}  mark {fmt(float(t[3]), 2)}  "
              f"uPnL {float(t[4]):+,.2f}  {t[5]} {t[6]}")
    head = ["SIDE", "SIZE", "ENTRY", "MARK", "uPnL", "LEV", "MODE"]
    w = [max(len(h), *(len(r[i]) for r in table)) for i, h in enumerate(head)]
    print()
    for r in [head] + table:
        print("  ".join(c.ljust(w[i]) for i, c in enumerate(r)))


def cmd_balance(a):
    rows = get_client().futures_account_balance()
    shown = 0
    for r in rows:
        wallet = Decimal(r["balance"])
        total = wallet + Decimal(r.get("crossUnPnl", "0"))
        if wallet == 0 and total == 0:
            continue
        shown += 1
        print(f"{r['asset']:<6} wallet {fmt(float(wallet))}  available {fmt(float(r['availableBalance']))}  "
              f"total {fmt(float(total))}")
    if not shown:
        print("No futures balance.")


# ---------- CLI ----------

def friendly(e):
    hint = ERROR_HINTS.get(e.code)
    return f"{hint} [Binance {e.code}: {e.message}]" if hint else f"Binance {e.code}: {e.message}"


def build_parser():
    ap = argparse.ArgumentParser(prog="binance_futures_kelly.py",
                                 description="Manual Binance USDⓈ-M Futures assistant (Half-Kelly sizing, entry orders only).")
    sp = ap.add_subparsers(dest="cmd", required=True, metavar="command")

    p = sp.add_parser("set_leverage", help="set leverage (2-129)")
    p.add_argument("symbol"); p.add_argument("leverage", type=int)
    p.set_defaults(fn=cmd_set_leverage)

    p = sp.add_parser("set_margin_mode", help="ISOLATED or CROSS")
    p.add_argument("symbol"); p.add_argument("mode")
    p.set_defaults(fn=cmd_set_margin_mode)

    p = sp.add_parser("set_position_mode", help="ONEWAY or HEDGE")
    p.add_argument("mode")
    p.set_defaults(fn=cmd_set_position_mode)

    def kelly_args(p):
        p.add_argument("symbol")
        p.add_argument("entry_price", type=float)
        p.add_argument("stop_price", type=float)
        p.add_argument("win_prob", type=float)
        p.add_argument("bankroll", type=float)
        p.add_argument("half", type=parse_bool)

    for name, fn in (("calc_kelly_long", cmd_calc_kelly_long), ("calc_kelly_short", cmd_calc_kelly_short)):
        p = sp.add_parser(name, help="Kelly size, no order")
        kelly_args(p)
        p.add_argument("--reward_ratio", type=float, default=DEFAULT_REWARD_RATIO)
        p.set_defaults(fn=fn)

    p = sp.add_parser("plan_position", help="Kelly size + required margin at leverage, no order")
    kelly_args(p)
    p.add_argument("leverage", type=int)
    p.add_argument("--reward_ratio", type=float, default=DEFAULT_REWARD_RATIO)
    p.set_defaults(fn=cmd_plan_position)

    for name, fn in (("market_long", cmd_market_long), ("market_short", cmd_market_short)):
        p = sp.add_parser(name, help=f"MARKET {'BUY' if 'long' in name else 'SELL'}")
        p.add_argument("symbol"); p.add_argument("quantity", type=float)
        p.set_defaults(fn=fn)

    for name, fn in (("limit_long", cmd_limit_long), ("limit_short", cmd_limit_short)):
        p = sp.add_parser(name, help=f"LIMIT {'BUY' if 'long' in name else 'SELL'} (GTC)")
        p.add_argument("symbol"); p.add_argument("price", type=float); p.add_argument("quantity", type=float)
        p.set_defaults(fn=fn)

    p = sp.add_parser("cancel_all", help="cancel all open orders for symbol")
    p.add_argument("symbol")
    p.set_defaults(fn=cmd_cancel_all)

    p = sp.add_parser("position", help="show position")
    p.add_argument("symbol")
    p.set_defaults(fn=cmd_position)

    p = sp.add_parser("balance", help="show futures balances")
    p.set_defaults(fn=cmd_balance)
    return ap


def main(argv=None):
    load_dotenv()
    args = build_parser().parse_args(argv)
    try:
        args.fn(args)
    except CliError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except BinanceAPIException as e:
        print(f"Error: {friendly(e)}", file=sys.stderr)
        return 1
    except BinanceRequestException as e:
        print(f"Error: bad response from Binance ({e.message}).", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
    except Exception as e:  # network errors etc.
        print(f"Error: {type(e).__name__}: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
