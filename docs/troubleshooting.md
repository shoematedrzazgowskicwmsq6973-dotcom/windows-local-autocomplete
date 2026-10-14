# 故障排查

先运行 `scripts/Test-LocalAutocomplete.ps1`，再检查编辑器，避免把后端和界面问题混在一起。

## 本机服务连接失败

在终端运行实际安装路径下的 `ollama.exe serve`，读取报错。如果托盘应用已经启动了服务，不要再启动第二个服务。

```powershell
& 'D:\Ollama\ollama.exe' serve
```

正常本地接口为 `http://127.0.0.1:11434`。脚本不暴露远程监听接口。

## 模型未安装

```powershell
& 'D:\Ollama\ollama.exe' list
& 'D:\Ollama\ollama.exe' pull qwen2.5-coder:1.5b-base
```

先确认服务启动时使用了期望的 `OLLAMA_MODELS`。看到空清单不一定是文件消失，也可能是目录不同。

## 修改目录后没有生效

- 用户环境变量影响新启动的进程；已经运行的应用不会自动切换模型目录。
- 正常退出 Ollama 托盘应用并重新启动。
- 使用仓库启动脚本前，正常关闭 VS Code 窗口。旧进程可能复用之前的 Continue 目录。
- 本仓库没有自动修改用户环境变量、迁移旧模型或恢复旧设置的脚本。需要恢复时按之前保存的变量值和配置副本手动处理。

## 补全来源分不清

暂时关闭 Copilot 的自动内联建议和下一步编辑建议，确认 Continue 的 Tab Autocomplete 已开启。观察新的 Continue 日志，再输入一个新的小函数并实际用 Tab 接受。

Continue 请求日志只证明请求发生，不证明屏幕上的任意一条建议属于它。直接调用 `/api/generate` 也不能证明编辑器流程正常。

## 插件换到 D 盘后，Python 插件不见了

`--extensions-dir` 切换整个插件目录。检查新目录里是否有语言插件；重新安装或按 README 的方法复制旧插件。旧目录会保留，因此复制不会释放旧目录占用。

## 冷启动很慢

模型首次加载、驱动初始化与 GPU 库准备会增加耗时。模型已经在内存时再次请求，才是预热状态。两种结果分别记录。查看：

```powershell
& 'D:\Ollama\ollama.exe' ps
```

GPU 部分加载与完全加载的性能不同；模型生成速度也不等于灰色文字显示的端到端延迟。这个初版没有做 CPU、不同显卡与长上下文的对比测试。

## 下载报 non-public IP 或出现 198.18.x.x 地址

在原安装过程中，代理的 Fake-IP DNS 曾把模型下载地址解析为 `198.18.x.x`，与 Ollama 对非公网重定向的检查冲突。

优先检查代理/DNS 配置，让官方下载域名使用真实 DNS 解析后重试官方 `ollama pull`。不同代理软件的具体设置不同，需要按其文档处理。保留服务的重定向保护与文件完整性校验。

原机器曾通过官方 registry 下载并核对每个 SHA256 后恢复缓存；那是一次机器相关的修复，仓库未把它包装成通用下载器。该替代流程尚未完成通用化与独立复现。

## PowerShell 脚本被执行策略阻止

查看脚本内容后，可以只对本次进程设置执行策略：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Test-LocalAutocomplete.ps1' -Generate
```

执行策略与文件签名不是同一回事；本仓库脚本未签名。无需更改全局策略。

## 请求成功，补全质量不好

先用短函数检查，再逐步增加上下文。保存可公开的输入例子、实际输出和模型版本，而不是只报告“感觉不好”。1.5B 是轻量起点，这里没有证明它与大型云端模型质量相当。更换模型前先记录当前结果和资源占用。

## 升级后日志或配置改变

Continue 自选全局目录环境变量与开发日志路径依据 2.0.0 实现核对。新版本可能改变它们；检查版本、配置加载结果和模型选择，再核对 [Continue 文档](https://docs.continue.dev/reference)。

官方参考：[Ollama Windows](https://docs.ollama.com/windows)、[Ollama FAQ](https://docs.ollama.com/faq)、[Continue 配置](https://docs.continue.dev/reference)。
