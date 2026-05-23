# DoomLike Web 部署指南

## 必需 HTTP 响应头

Godot 4.x Web 导出使用 **SharedArrayBuffer**（多线程支持），需要以下响应头：

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

不设置这些头，游戏会静默加载失败（控制台报 `SharedArrayBuffer is not defined`）。

## 平台配置

### itch.io

在 Game Settings → Embed Options：
- **SharedArrayBuffer support**: Enabled（勾选启用 COOP/COEP 头）

无需其他配置，itch.io 自动处理。

### GitHub Pages

不支持自定义 HTTP 头，需使用 **coi-serviceworker** 方案：

1. 下载 `coi-serviceworker.min.js` 放入 `build/web/`
2. 在 `index.html` 的 `<head>` 中添加：
```html
<script src="coi-serviceworker.min.js"></script>
```

### Cloudflare Pages

在项目根目录创建 `_headers` 文件：

```
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
```

### Netlify

在项目根目录创建 `netlify.toml`：

```toml
[[headers]]
  for = "/*"
  [headers.values]
    Cross-Origin-Opener-Policy = "same-origin"
    Cross-Origin-Embedder-Policy = "require-corp"
```

### 本地测试

```bash
npx serve build/web --no-clipboard --cors
```

`serve` 不支持自定义头，可用 `--cors` 临时绕过 CORS，但 SharedArrayBuffer 仍需服务端头。推荐用 Live Server 或 Python 简单服务器 + 自定义脚本。

## 文件清单

导出后 `build/web/` 应包含：

| 文件 | 说明 |
|------|------|
| `index.html` | 主页面 |
| `index.js` | JS 胶水代码 |
| `index.wasm` | WASM 二进制 |
| `index.pck` | 游戏资源包 |
| `index.audio.worklet.js` | 音频 Worklet |
| `index.icon-192.png` | PWA 小图标 |
| `index.icon-512.png` | PWA 大图标 |
| `manifest.json` | PWA 清单 |
| `service_worker.js` | Service Worker |
