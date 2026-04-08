import yfinance as yf
import pandas as pd
import datetime
from ta.trend import SMAIndicator, MACD
from ta.momentum import RSIIndicator
import tkinter as tk
from tkinter import ttk, messagebox
from nsetools import Nse

def fetch_data(symbol, period="6mo", interval="1d"):
    try:
        ticker = yf.Ticker(symbol + ".NS")
        df = ticker.history(period=period, interval=interval)
        return df
    except Exception as e:
        return pd.DataFrame()  # Return empty DataFrame on error

def fetch_latest_price(symbol):
    nse = Nse()
    try:
        q = nse.get_quote(symbol.lower())
        return q['lastPrice']
    except Exception as e:
        return None

def technical_indicators(df):
    if 'Close' not in df.columns:
        raise ValueError("No 'Close' column in data. Data may be incomplete or unavailable.")
    df['SMA_20'] = SMAIndicator(df['Close'], window=20).sma_indicator()
    df['SMA_50'] = SMAIndicator(df['Close'], window=50).sma_indicator()
    df['RSI'] = RSIIndicator(df['Close'], window=14).rsi()
    macd = MACD(df['Close'])
    df['MACD'] = macd.macd()
    df['MACD_signal'] = macd.macd_signal()
    return df

def analyze(df):
    if df.empty:
        raise ValueError("No data to analyze.")
    latest = df.iloc[-1]
    advice = "Hold"
    target_price = None
    sell_signal = None

    # Buy signal: SMA20 crosses above SMA50, RSI < 70, MACD > MACD_signal
    if (latest['SMA_20'] > latest['SMA_50'] and
        latest['RSI'] < 70 and
        latest['MACD'] > latest['MACD_signal']):
        advice = "Buy"
        # Target: 5% above current close
        target_price = round(latest['Close'] * 1.05, 2)
        # Sell when RSI > 70 or price hits target
        sell_signal = f"Sell when RSI > 70 or price >= {target_price}"
    elif latest['RSI'] > 70:
        advice = "Sell"
        sell_signal = "RSI indicates overbought. Consider selling."
    else:
        sell_signal = "No strong signal. Hold or wait for better entry."

    return {
        "advice": advice,
        "current_price": latest['Close'],
        "target_price": target_price,
        "sell_signal": sell_signal
    }

def run_analysis():
    symbol = symbol_var.get().strip().upper()
    if not symbol:
        messagebox.showwarning("Input Error", "Please enter a stock symbol.")
        return
    result_text.config(state='normal')
    result_text.delete(1.0, tk.END)
    try:
        df = fetch_data(symbol)
        if df.empty:
            result_text.insert(tk.END, f"No data found for symbol '{symbol}' or network error.\n")
            result_text.config(state='disabled')
            return
        if 'Close' not in df.columns:
            result_text.insert(tk.END, f"Data for '{symbol}' does not contain 'Close' prices. Try another symbol.\n")
            result_text.config(state='disabled')
            return
        df = technical_indicators(df)
        result = analyze(df)
        output = f"Analysis for {symbol}:\n"
        output += f"Current Price: ₹{result['current_price']:.2f}\n"
        output += f"Advice: {result['advice']}\n"
        if result['target_price']:
            output += f"Predicted Target Price: ₹{result['target_price']:.2f}\n"
        output += f"When to Sell: {result['sell_signal']}\n"
        result_text.insert(tk.END, output)

        latest_price = fetch_latest_price(symbol)
        if latest_price:
            result_text.insert(tk.END, f"Latest NSE Price: ₹{latest_price}\n")
        else:
            result_text.insert(tk.END, "Could not fetch latest NSE price.\n")
    except Exception as e:
        result_text.insert(tk.END, f"Error: {str(e)}\n")
    result_text.config(state='disabled')

# --- GUI setup ---
root = tk.Tk()
root.title("NSE Stock Technical Analysis")

mainframe = ttk.Frame(root, padding="10")
mainframe.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

ttk.Label(mainframe, text="Enter NSE stock symbol (e.g., RELIANCE):").grid(row=0, column=0, sticky=tk.W)
symbol_var = tk.StringVar()
symbol_entry = ttk.Entry(mainframe, textvariable=symbol_var, width=20)
symbol_entry.grid(row=1, column=0, sticky=(tk.W, tk.E))
analyze_btn = ttk.Button(mainframe, text="Analyze", command=run_analysis)
analyze_btn.grid(row=1, column=1, padx=5)

result_text = tk.Text(mainframe, width=50, height=10, state='disabled')
result_text.grid(row=2, column=0, columnspan=2, pady=10)

symbol_entry.focus()  # Set focus to entry on startup

root.mainloop()