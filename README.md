# GRAIN

iPhone RAW 胶片工作台。应用源码位于 `outputs/GRAIN`，交互原型为 `outputs/GRAIN-prototype.html`。

## 在 GitHub 生成企业签名 IPA

仓库提供两个 Actions：

- `Validate iOS Build`：无需签名，自动编译 iOS Simulator 版本，用于发现 Swift/Xcode 编译问题。
- `Build Enterprise IPA`：导入企业签名证书与描述文件，Archive 后导出企业分发 IPA。

签名文件不会提交到仓库。运行 [`Build Enterprise IPA`](.github/workflows/build-enterprise-ipa.yml) 前，需要在 GitHub 仓库的 `Settings > Secrets and variables > Actions` 中添加：

| Secret | 内容 |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID，通常是 10 位大写字符 |
| `BUILD_CERTIFICATE_BASE64` | 包含私钥的企业签名 `.p12` 文件，经 Base64 编码 |
| `P12_PASSWORD` | `.p12` 导出密码 |
| `PROVISIONING_PROFILE_BASE64` | 企业 In-House `.mobileprovision` 文件，经 Base64 编码 |
| `SIGNING_IDENTITY` | 可选。例如 `Apple Distribution: Company Name`；留空时由 Xcode 从证书中选择 |
| `KEYCHAIN_PASSWORD` | 可选。CI 临时钥匙串密码；留空时由构建脚本随机生成 |

本地生成 Base64 内容：

```bash
base64 -i enterprise-certificate.p12 | pbcopy
base64 -i enterprise-profile.mobileprovision | pbcopy
```

两次命令分别粘贴到对应的 GitHub Secret。不要把证书、密码或描述文件提交到 Git。

## 重要匹配条件

- 描述文件中的 Team ID 必须等于 `APPLE_TEAM_ID`。
- 描述文件必须是 In-House/Enterprise 分发类型。
- 描述文件对应的 App ID 必须是 `BUNDLE_ID`，或该 Team 的 Wildcard App ID。
- 默认 Bundle ID 是 `studio.grain.rawfilm`；如企业描述文件使用其他 App ID，请在手动运行 Workflow 时填写 Workflow 输入 `bundle_identifier`。
- 企业证书与描述文件都必须未过期。

构建成功后，从 Actions 运行记录的 `Artifacts` 下载 `GRAIN-enterprise-ipa`。解压后得到 `GRAIN-enterprise-<build>.ipa`。

## 本地手动构建

在安装了完整 Xcode 且已导入企业证书的 Mac 上：

```bash
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export BUNDLE_ID="YOUR_ENTERPRISE_BUNDLE_ID"
export BUILD_CERTIFICATE_BASE64="$(base64 -i certificate.p12)"
export P12_PASSWORD="P12_PASSWORD"
export PROVISIONING_PROFILE_BASE64="$(base64 -i profile.mobileprovision)"
./scripts/build_enterprise_ipa.sh
```

输出位置为 `ci/artifacts/`。

## Sony RAW 支持

Sony ARW 由 iOS Core Image RAW 解码器处理。主流 Sony 机型通常可用，但新机身、新压缩 RAW 格式或新固件可能需要更新 iOS。App 在系统不支持时会明确报错，不会把内嵌 JPEG 预览冒充为原始尺寸导出。

