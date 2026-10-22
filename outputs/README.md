# GRAIN 交付内容

- `GRAIN-prototype.html`：可直接在浏览器打开的交互原型，支持拖动对比、胶片配方、参数滑杆、导出面板和定位开关。
- `GRAIN/`：可导入 Xcode 的 iPhone SwiftUI 工程源码。
- `GRAIN-preview.png`：原型首屏预览。
- `GRAIN-export-preview.png`：最高规格导出设置预览。

网页原型不能解码 Sony ARW，也不能真正写入 HEIC 元数据；这两部分由 Xcode 工程内的 `CIRAWFilter` 和 ImageIO 管线实现。
