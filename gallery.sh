#!/data/data/com.termux/files/usr/bin/bash

# 🧼 Clean previous log
rm -f cl.txt

# ✅ Install required packages
for pkg in python wget; do
  if ! command -v $pkg >/dev/null 2>&1; then
    echo "📦 Installing $pkg..."
    pkg install $pkg -y
  else
    echo "✅ $pkg already installed"
  fi
done

# Install cloudflared if not available
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "📦 Installing cloudflared..."
  pkg install cloudflared -y
fi

# 🚀 Start Python HTTP server
PORT=$((RANDOM % 1000 + 8000))
echo "🌐 Starting Python server on port $PORT..."
python -m http.server $PORT > /dev/null 2>&1 &
PHP_PID=$!
echo "Python server PID: $PHP_PID"

# 🌐 Start Cloudflared tunnel
echo "🌐 Starting Cloudflared..."
cloudflared tunnel --url http://127.0.0.1:$PORT --logfile cl.txt > /dev/null 2>&1 &
CF_PID=$!
echo "Cloudflared PID: $CF_PID"

sleep 5

# 🔎 Extract Cloudflared public URL
echo "⏳ Waiting for Cloudflared link..."
LINK=""
for i in {1..20}; do
  if [[ -f "cl.txt" ]]; then
    LINK=$(grep -o 'https://[-a-zA-Z0-9.]*\.trycloudflare\.com' "cl.txt" | head -1)
    [[ -n "$LINK" ]] && break
  fi
  sleep 3
  echo "Attempt $i/20..."
done

# 📤 Show wget command
if [[ -n "$LINK" ]]; then
  echo -e "\n✅ \033[1;32mSend this command to your friend's Termux:\033[0m \n"
  echo -e "\033[1;33mwget -O numberinfo.py $LINK\033[0m\n"
  echo ""
  echo -e "\n📱 Public URL: \033[1;36m$LINK\033[0m\n"
  echo -e "🔗 You can also open this in browser\n"
else
  echo -e "\n❌ \033[1;31mCloudflared tunnel failed. Check cl.txt for details.\033[0m"
  echo "Debug: Checking cl.txt content..."
  cat cl.txt 2>/dev/null | head -10
  kill $PHP_PID $CF_PID 2>/dev/null
  exit 1
fi

# 🛑 Cleanup function
cleanup() {
  echo -e "\n🛑 Stopping services..."
  kill $PHP_PID $CF_PID 2>/dev/null 2>/dev/null
  echo "✅ Services stopped"
  exit 0
}

# 📱 Set trap for Ctrl+C
trap cleanup SIGINT

echo -e "Press Ctrl+C to stop the server\n"

# 🔁 Keep server alive
while true; do
  sleep 10
  # Check if processes are still running
  if ! kill -0 $PHP_PID 2>/dev/null; then
    echo "❌ Python server stopped unexpectedly"
    break
  fi
  if ! kill -0 $CF_PID 2>/dev/null; then
    echo "❌ Cloudflared stopped unexpectedly"
    break
  fi
  echo "✅ Services running... $(date)"
done

cleanup