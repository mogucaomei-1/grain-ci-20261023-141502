# GRAIN 交付内容

- `GRAIN-1.1-unsigned.ipa`：1.1 版本、arm64、未签名的可重签 IPA。
- `GRAIN-1.1-unsigned.sha256`：对应 IPA 的校验值。
- `GRAIN-prototype.html`：可直接在浏览器打开的交互原型，支持拖动对比、胶片配方、参数滑杆、导出面板和定位开关。
- `GRAIN/`：可导入 Xcode 的 iPhone SwiftUI 工程源码。
- `GRAIN-demo.jpg`：网页预览使用用户提供的 Sony ZV-E10 JPEG 样片。
- `GRAIN-preview.png`：1.1 单页编辑器预览。
- `GRAIN-export-preview.png`：最高规格导出设置预览。

网页原型不能解码 Sony ARW，也不能真正写入 HEIC 元数据；这两部分由 Xcode 工程内的 Core Image RAW 与 ImageIO 管线实现。原始 ARW 应优先从“文件”导入。
