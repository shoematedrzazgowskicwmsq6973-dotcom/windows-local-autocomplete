# Windows 本地代码补全：Continue + Ollama

一份面向初学者的 Windows / VS Code 本地补全配置指南，附带配置模板、启动脚本和验证脚本。

重点解决：把大体积程序、模型和插件放到自选目录；区分本地补全与 Copilot；发现服务、模型或编辑器配置的问题。

**当前状态：初版配置指南。已有 Windows 单机运行记录，尚未完成另一台电脑从零安装的验证。**

## 能做什么

- 在 VS Code 输入代码时显示灰色建议，用 Tab 接受。
- 模型请求使用本机 `http://127.0.0.1:11434`。
- 用 `qwen2.5-coder:1.5b-base` 作为轻量起点。
- 程序、模型、Continue 数据和 VS Code 插件目录可以分别指定。
- 检查模型是否安装、是否能生成内容，以及 Continue 是否实际发出了请求。

这个仓库提供集成说明与辅助脚本。Ollama、Continue、VS Code 和 Qwen 由各自项目维护。它不实现新模型，也未配置聊天、Agent 或 AI 编辑功能；小模型的补全质量需自己评估。

首次安装、下载模型与插件需要联网。模型下载后，请求指向本地服务；这不代表整个 VS Code 或其他插件都不会联网。本仓库未做完整断网验证。

## 先看目录安排

下表是示例，D 盘不是硬性要求。启动脚本支持改成自己的绝对路径。

| 内容 | 示例位置 |
| --- | --- |
| Ollama 程序 | `D:\Ollama` |
| 模型文件 | `D:\Ollama\Models` |
| Continue 配置与数据 | `D:\Continue` |
| VS Code 插件 | `D:\VSCodeExtensions` |

Windows 用户设置、快捷方式、部分更新、日志及临时文件仍可能留在 C 盘。**这里不承诺零 C 盘占用。** Ollama 官方说明程序安装约需至少 4 GB，模型另占空间；本例模型约 986 MB。[安装目录说明](https://docs.ollama.com/windows)、[模型页面](https://ollama.com/library/qwen2.5-coder:1.5b-base)

## 安装与配置

在 PowerShell 中执行下面的命令。仓库里的脚本面向 Windows PowerShell 5.1 和 PowerShell 7。

### 1. 安装 Ollama，指定模型目录

从 [Ollama 官网](https://ollama.com/download/windows) 下载安装器，在下载目录执行：

```powershell
.\OllamaSetup.exe /DIR="D:\Ollama"
```

创建所需目录，并保存模型目录环境变量：

```powershell
New-Item -ItemType Directory -Force -Path 'D:\Ollama\Models', 'D:\Continue', 'D:\VSCodeExtensions'
[Environment]::SetEnvironmentVariable('OLLAMA_MODELS', 'D:\Ollama\Models', 'User')
$env:OLLAMA_MODELS = 'D:\Ollama\Models'
```

如果 Ollama 已经启动，从托盘正常退出并重新打开，使它读取新环境。环境变量影响后续下载位置，不会自动搬走已存在的模型。[官方说明](https://docs.ollama.com/windows#changing-model-location)

### 2. 下载用于补全的模型

```powershell
& 'D:\Ollama\ollama.exe' pull qwen2.5-coder:1.5b-base
& 'D:\Ollama\ollama.exe' list
```

选择 Base 版是为了补全任务。不要把它直接当作已经配置好的聊天助手。Qwen 官方说明 Base 模型适用于续写及填空等任务，不建议直接用于对话。[Qwen 模型说明](https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B)

### 3. 安装 Continue，处理插件目录

确保 `code` 命令可用：

```powershell
code --version
code --extensions-dir 'D:\VSCodeExtensions' --install-extension Continue.continue
```

如果命令未找到，把 `code` 换成自己的 `code.cmd` 完整路径，例如：

```powershell
& 'D:\Apps\Microsoft VS Code\bin\code.cmd' --extensions-dir 'D:\VSCodeExtensions' --install-extension Continue.continue
```

`--extensions-dir` 指向的是这次 VS Code 使用的整个插件目录。已有 Python 等插件在另一处时，不会自动出现在新目录里。可以重新安装所需插件，或关闭 VS Code 后，把原插件复制过去；保留原目录，复制不会自动回收 C 盘空间。[VS Code CLI 文档](https://code.visualstudio.com/docs/configure/command-line#advanced-cli-options)

可选复制示例，仅适用于默认旧插件目录确实存在、目标目录尚未存放同名插件的情况。目标已有内容时先比较版本；不要直接执行复制命令覆盖它们。

```powershell
Copy-Item -Path "$env:USERPROFILE\.vscode\extensions\*" -Destination 'D:\VSCodeExtensions' -Recurse
```

### 4. 放入 Continue 配置

已有 `config.yaml` 时，先保存副本并合并配置，避免替换自己原来的模型设置。下面的命令发现已有配置时会停止。在本仓库根目录运行：

```powershell
if (Test-Path -LiteralPath 'D:\Continue\config.yaml') {
    throw 'Config already exists. Back it up and merge the example manually.'
}
Copy-Item -LiteralPath '.\config\continue.config.yaml' -Destination 'D:\Continue\config.yaml'
```

打开 VS Code 用户设置 JSON，把 [设置示例](config/vscode.settings.example.json) 中的四个字段合并进去，保留原有设置。设置示例是一个片段，不应直接覆盖整个用户设置文件。

`CONTINUE_GLOBAL_DIR` 用于让 Continue 读取这个自选目录；它是本指南在 Continue 2.0.0 安装源码中核对的环境变量，不保证所有未来版本保持相同实现。模型字段见 [Continue 官方配置参考](https://docs.continue.dev/reference)。

### 5. 启动自己的项目

正常关闭已经打开的 VS Code 窗口，再运行：

```powershell
.\scripts\Start-LocalAutocomplete.ps1 -Workspace 'D:\MyProject'
```

路径不同可显式传入：

```powershell
.\scripts\Start-LocalAutocomplete.ps1 `
  -Workspace 'E:\Projects\My App' `
  -CodeCommand 'E:\Apps\Microsoft VS Code\bin\code.cmd' `
  -OllamaExecutable 'E:\Apps\Ollama\ollama.exe' `
  -ModelsDirectory 'E:\Models\Ollama' `
  -ContinueDirectory 'E:\Config\Continue' `
  -ExtensionsDirectory 'E:\Extensions\VSCode'
```

启动脚本会校验路径和配置，设置当前进程及子进程环境，在必要时后台启动本地服务，再打开项目。它不安装软件或插件，不下载模型，不写入永久用户环境变量，不停止已有进程，也不合并用户设置。如果 Ollama 已在运行，它保留启动时的模型目录；需要改目录时正常退出并重新打开它。

只查看解析后的路径、不启动任何程序：

```powershell
.\scripts\Start-LocalAutocomplete.ps1 -Workspace 'D:\MyProject' -CheckOnly
```

脚本执行被策略阻止时，可以检查脚本后，用单次 PowerShell 进程的 `-ExecutionPolicy Bypass -File` 执行。无需永久修改系统执行策略。

## 怎样确认真正走了本地模型？

### A. 验证服务与模型

```powershell
.\scripts\Test-LocalAutocomplete.ps1
.\scripts\Test-LocalAutocomplete.ps1 -Generate
```

第一条检查本机服务和模型清单；第二条实际请求一段固定示例补全，报告耗时、返回文字和加载到显存的字节数。首次模型加载可能更慢。

**这只验证 Ollama 后端，不能证明编辑器已经显示或接受建议。**

### B. 验证 Continue 与编辑器

1. 在 Copilot 状态菜单中关闭自动内联建议和下一步编辑建议；确保 Continue 的 Tab Autocomplete 开启。需要彻底隔离时，可在扩展管理里停用 Copilot（若当前版本允许）。
2. 开始观察新的 Continue 请求：

   ```powershell
   .\scripts\Watch-ContinueRequests.ps1
   ```

3. 在一个新 `.py` 文件中自己输入 `def square(number):`，下一行缩进并输入 `return `，光标放在空格后。
4. 按 `Ctrl+Alt+空格` 请求 Continue 补全，观察灰色文字，按 Tab 接受。
5. 查看新记录是否包含 `provider: ollama` 与 `model: qwen2.5-coder:1.5b-base`。

日志事件证明 Continue 生成过内容；隔离其他来源并实际看到、接受建议，才是编辑器检查。缓存命中可能不产生新生成事件；没有新日志不能直接判定故障，可改用新的函数名和输入。

`Watch-ContinueRequests.ps1` 只显示时间、模型、供应商和 token 数，不输出提示词或代码。日志路径基于 Continue 2.0.0 的实际文件，升级后路径或格式可能改变。

普通变量与函数候选下拉列表通常由语言插件提供，不能用它判断 Copilot 或本地模型是否运行。

## 快捷键

| 快捷键 | 用途 |
| --- | --- |
| Tab | 接受灰色建议 |
| Esc | 忽略建议 |
| Ctrl+Alt+空格 | 手动请求 Continue 补全 |
| Ctrl+I | VS Code 默认 AI 编辑入口 |

Continue 的编辑入口也可能占用 `Ctrl+I`。[可选按键配置](config/vscode.keybindings.example.json) 移除这条 Continue 默认绑定，将其编辑入口改成 `Ctrl+Shift+Alt+I`；把这两条规则合并到用户 `keybindings.json`，不要覆盖已有规则。这套模板只配置补全模型，改快捷键不会新增编辑能力。

参考：[Continue 补全快捷键](https://docs.continue.dev/ide-extensions/autocomplete/quick-start)、[VS Code 内联聊天](https://code.visualstudio.com/docs/chat/inline-chat)、[按键配置](https://code.visualstudio.com/docs/configure/keybindings)。

## 已验证的范围

见 [验证记录](docs/verification.md)。它区分旧安装记录、本次脚本检查与尚未验证的环境。历史单次预热请求约 38 ms 不是编辑器端到端延迟，也不是其他机器的性能承诺。

## 常见问题与下一步

- [故障排查](docs/troubleshooting.md)：服务没启动、模型缺失、Copilot 混用、目录环境没生效、下载失败。
- 当前最值得补充的是另一台电脑的从零复现，以及脱敏后的编辑器演示。
- 通用自动安装、断点下载与环境回滚工具尚未实现；先通过独立复现，再决定是否增加维护成本。

安装器、模型权重、日志、个人项目、用户配置备份与私人学习材料均不属于仓库内容。

## 许可

本仓库原创指南、模板与脚本采用 [MIT License](LICENSE)。第三方软件和模型各自遵循其原项目许可；本仓库不分发这些软件或模型。
