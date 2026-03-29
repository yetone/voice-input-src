```bash
claude \
  --dangerously-skip-permissions \
  --output-format=stream-json \
  --verbose \
  -p "请实现一个语音输入法：按住快捷键录音，松开后将转录的文字注入到输入框中。优先使用流式转录。需要支持中文输入。macOS 下使用 Fn 键，Windows 下使用 F2 键。"
```
