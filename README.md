# fiber-lightpanda

A [Fiber](https://github.com/aakshintala/fiber) extension that adds one tool, `web_render`. It loads a page in [Lightpanda](https://github.com/lightpanda-io/browser), a headless browser that runs the page's JavaScript, waits until the network goes quiet, and returns the rendered page as Markdown. Use it when `web_fetch` returns a page without its content, such as a client-side rendered app.

```
fiber extension install github.com/aakshintala/fiber-lightpanda
```

The install downloads the Lightpanda binary for your platform and checks its sha256.

## Licences and where the binary comes from

- This extension's own code is MIT (`LICENSE`).
- Lightpanda is licensed AGPL-3.0. This repository holds no Lightpanda code and never commits the binary.
- `extension.json` pins Lightpanda 1.0.1 and, for each of Fiber's four platforms, the URL of the binary on Lightpanda's own releases page (`https://github.com/lightpanda-io/browser/releases/download/1.0.1/`) with its sha256. Lightpanda publishes no checksum files, so the hashes were computed from the downloaded assets. Fiber downloads only the binary for the platform it runs on and refuses one whose hash differs.

| Fiber platform | Lightpanda asset |
|---|---|
| `darwin-arm64` | `lightpanda-aarch64-macos` |
| `darwin-x64` | `lightpanda-x86_64-macos` |
| `linux-arm64` | `lightpanda-aarch64-linux` |
| `linux-x64` | `lightpanda-x86_64-linux` |

## What `web_render` does

- Argument: `url`, an `http` or `https` URL. Anything else is refused before Lightpanda starts.
- Runs `bin/fiber-lightpanda fetch --dump markdown --wait-until networkidle --terminate-ms 60000 --dump-max-bytes 1048576 --block-private-networks <url>` through `host.exec`. Private and loopback addresses are blocked, which `web_fetch` allows.
- Sets `LIGHTPANDA_DISABLE_TELEMETRY=true` on every run. Lightpanda sends usage data by default.
- Declares the effects `network` and `executes`, so the reviewer judges each call until you approve the tool for the session or add a standing allow. It declares no `hosts` yet: Fiber does not let a Lua tool declare them (see the tracking issue in this repository).
- The result is bounded as `web_fetch`'s is: Fiber cuts it at 16 KiB, keeps the start, and puts the whole page in the session's `artifacts/`.
- Timeouts: Lightpanda aborts the page after 60 s, and the tool call has a 90 s timeout, after which Fiber stops the process group.

## Tests

```
fiber extension test .
```

Five cases script `host.exec`: the rendered Markdown comes back as the result, the telemetry variable is set, a long page is cut at the cap, a failing run is a failed call, and a non-http URL never starts Lightpanda. A case cannot script a hung process, so the timeout path itself (Fiber stopping the process group) is Fiber's `host.exec`, not tested here.

## Live check

- Date: 2026-10-18, linux x86_64.
- Binary: the one `fiber extension install` put in a clean `FIBER_HOME` (sha256 `551747e3...bac5b918a7` matches the manifest's `linux-x64`).
- Command: `LIGHTPANDA_DISABLE_TELEMETRY=true bin/fiber-lightpanda fetch --dump markdown --wait-until networkidle --terminate-ms 60000 --dump-max-bytes 1048576 --block-private-networks https://hn.algolia.com/`
- Result: exit 0 in about 2 s, 19,824 characters of Markdown with 30 stories. First story: `[Stephen Hawking has died](https://news.ycombinator.com/item?id=16582136)`, 6015 points.
- For comparison, the page's raw HTML is 2,383 bytes with no stories, and Fiber's `web_fetch` measured 298 characters and no stories on this page (Fiber ticket 1293).
