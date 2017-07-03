# OfficeTown

## Run

Start Budo:

```
budo --ignore node_modules index.js
```

Start Chrome as kiosk window:

```
/c/Program\ Files\ \(x86\)/Google/Chrome/Application/chrome.exe --kiosk --user-data-dir=chrome-user-data --no-first-run http://localhost:9966
```

Start streamer:

```
KEY=abcd1234 ./stream.sh
```

Might be helpful to keep the focus on the streamer console window (makes it foreground thread).

@todo verify the above commands

## Re-deployment

```
git pull origin master
npm install
```

Budo should automatically recompile; then just refresh the Chrome window (`Ctrl+Shift+R`).
