用 SwiftUI 重写的 [E-Hentai](https://e-hentai.org) / [ExHentai](https://exhentai.org) 画廊客户端，支持 iPhone、iPad 和 Mac。

功能与交互对齐 Android 端的 [EhViewer_CN_SXJ](https://github.com/xiaojieonly/Ehviewer_CN_SXJ)，网络层、解析器、下载引擎均为对照其实现重写，而非套壳。

### iPhone / iPad

**本项目不收集设备 UDID。** 请用你自己的 Apple ID 给安装包签名——你的设备信息不需要
交给任何人，也不受开发者账号每年 100 台设备的限制。

常用工具，任选其一：

| 工具 | 运行环境 | 说明 |
|------|----------|------|
| [Sideloadly](https://sideloadly.io) | Windows / macOS | 连数据线，填 Apple ID，选 IPA，点开始 |
| [AltStore](https://altstore.io) / [SideStore](https://sidestore.io) | Windows / macOS | 装一次后可在设备上自助续签，不必每周接电脑 |

签名用的 Apple ID 建议单独注册一个，不要用主力账号。

免费账号签出的 App **7 天后失效**，重签即可，数据不会丢。付费开发者账号（$99/年）为 1 年。
---

## 项目结构

App 层只放视图，业务逻辑全部下沉到 `Packages/` 下的本地 Swift Package，各模块可独立编译和测试。

```
EhViewer-Apple/
├── ehviewer apple/              # 主 App：SwiftUI 视图层
├── Packages/
│   ├── EhCore/
│   │   ├── EhModels/            # 数据模型、URL 构建器
│   │   ├── EhDatabase/          # GRDB 持久化
│   │   └── EhSettings/          # 全局配置、标签数据库
│   ├── EhNetwork/
│   │   ├── EhAPI/               # 请求引擎，对照 Android EhEngine
│   │   ├── EhCookie/            # Cookie 管理
│   │   └── EhDNS/               # 内置 Hosts 与域名前置
│   ├── EhParser/                # HTML / JSON 解析器
│   ├── EhSpider/                # 图片抓取与本地存储
│   ├── EhDownload/              # 下载队列
│   └── EhUI/                    # 复用组件
└── ehviewer apple.xcodeproj/
```
