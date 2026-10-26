# Photo → meal proxy

A tiny Cloudflare Worker that holds the Anthropic API key for the app's photo logging. The app sends a food photo; the Worker asks Claude (`claude-opus-5-5`, structured JSON output) what's on the plate and returns dish, meal type, health score and per-item grams, calories and macros. The key never ships inside the APK.

## Deploy (one time, about 5 minutes)

You need a free Cloudflare account and an Anthropic API key (console.anthropic.com → API keys).

```sh
cd proxy
npm install
npx wrangler login                        # opens the browser
npx wrangler secret put ANTHROPIC_API_KEY # paste the sk-ant-... key
npx wrangler secret put APP_TOKEN         # any long random string, e.g. from a password manager
npx wrangler deploy                       # prints https://calorie-photo-proxy.<you>.workers.dev
```

Then build the app with the URL and the same token:

```sh
flutter build apk --release \
  --dart-define=PHOTO_PROXY_URL=https://calorie-photo-proxy.<you>.workers.dev \
  --dart-define=PHOTO_PROXY_TOKEN=<the APP_TOKEN>
```

Without those two defines the app hides photo logging.

## Try it

```sh
curl -s https://calorie-photo-proxy.<you>.workers.dev/analyze \
  -H "Authorization: Bearer <APP_TOKEN>" -H "X-Install-Id: test" \
  -H "content-type: application/json" \
  -d "{\"image\":\"$(base64 -w0 plate.jpg)\",\"localTime\":\"13:05\"}"
```

## Notes

- **Cost:** each photo is one Claude request with one image. Watch usage in the Anthropic console and set a monthly spend limit there.
- **Abuse:** `APP_TOKEN` lives in the APK, so treat it as a speed bump, not a secret. Rotate it with `wrangler secret put APP_TOKEN` (and rebuild the app) if it leaks. Each install is limited to 20 photos a minute (`wrangler.toml`).
- **Privacy:** photos pass through the Worker to Anthropic's API and are not stored by the Worker.
- `npm run check` type-checks; `npm run dev` runs it locally (put secrets in `.dev.vars`).
