# Contributing to AI Translator / 贡献指南

Thank you for your interest in contributing to AI Translator! / 感谢您对 AI Translator 做出贡献的兴趣！

[English](#english) | [中文](#中文)

---

## English

### 📋 Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

### 🐛 Reporting Bugs

Before creating a bug report, please check the existing issues to avoid duplicates.

**When reporting a bug, include:**
- macOS version
- App version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Console logs (if applicable)

### 💡 Suggesting Features

Feature requests are welcome! Please provide:
- Clear description of the feature
- Use cases and benefits
- Potential implementation approach (if you have ideas)
- Mockups or examples (if applicable)

### 🔧 Development Process

#### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/AITranslator.git
cd AITranslator
```

#### 2. Setup Development Environment

```bash
make setup
```

This will install SwiftLint and other required dependencies.

#### 3. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation updates
- `test/` - Test additions or modifications

#### 4. Make Your Changes

**Before you start:**
- Read the codebase architecture in README.md
- Understand the existing code style
- Check related issues and PRs

**While coding:**
- Follow Swift API Design Guidelines
- Write clear, self-documenting code
- Add comments for complex logic
- Maintain consistent naming conventions
- Keep functions focused and concise

**Code Style:**
- Maximum line length: 150 characters (warning at 150, error at 200)
- Use 4 spaces for indentation (no tabs)
- End files with a single newline
- No trailing whitespace
- Sort imports alphabetically
- Use `// MARK:` to organize code sections

#### 5. Test Your Changes

```bash
# Build the project
make build

# Run tests
make test

# Run the app
make run
```

**Testing checklist:**
- App builds without errors
- All existing tests pass
- New functionality works as expected
- No regressions in existing features
- UI is responsive and accessible
- VoiceOver works correctly (for UI changes)

#### 6. Run Linter

```bash
# Check for issues
make lint

# Auto-fix issues
make lint-fix
```

**Fix all SwiftLint warnings and errors before committing.**

#### 7. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git commit -m "Add feature: language detection caching"
# or
git commit -m "Fix: proxy authentication not working for SOCKS5"
```

**Commit message format:**
```
<type>: <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic changes)
- `refactor`: Code refactoring
- `test`: Test additions or modifications
- `chore`: Build process or auxiliary tool changes

Example:
```
feat: Add Google language detection engine

- Implement Google Translate API integration
- Add error handling for network failures
- Update settings UI with new detection option

Closes #123
```

#### 8. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

**PR Description should include:**
- What changes were made
- Why these changes were necessary
- How to test the changes
- Screenshots (for UI changes)
- Related issues (use "Closes #123" to auto-close)

### 📝 Code Review Process

1. **Automated checks** run on all PRs:
   - SwiftLint
   - Build verification
   - Tests (if configured)

2. **Manual review** by maintainers:
   - Code quality
   - Architecture consistency
   - Performance impact
   - Accessibility compliance

3. **Feedback and iteration**:
   - Address review comments
   - Update PR as needed
   - Engage in constructive discussion

4. **Merge**:
   - PRs are typically squash-merged
   - Branch will be deleted after merge

### 🎨 UI/UX Guidelines

- Follow Apple's Human Interface Guidelines
- Maintain consistency with existing UI
- Support both light and dark mode
- Test with different display scales
- Ensure keyboard navigation works
- Provide VoiceOver labels and hints
- Use SF Symbols for icons
- Respect user's accessibility settings

### 🌐 Localization

When adding or modifying UI text:

1. Add English and Chinese translations to `Localization.swift`
2. Use `L10n.tr()` for all user-facing strings
3. Test with both language settings
4. Ensure text fits in UI at different lengths

Example:
```swift
// Add to L10n.en and L10n.zhHans
"feature.title": "Feature Title"
"feature.title": "功能标题"

// Use in code
Text(L10n.tr("feature.title", lang: viewModel.preferences.appLanguage))
```

### 🧪 Testing Guidelines

While this project doesn't have extensive test coverage yet, contributions that add tests are highly valued:

- Unit tests for business logic
- Integration tests for service interactions
- UI tests for critical workflows
- Accessibility tests

### 📚 Documentation

Update documentation when you:
- Add new features
- Change existing behavior
- Modify configuration options
- Add dependencies

### ⚠️ Common Pitfalls

1. **Forgetting to run SwiftLint** - Always run before committing
2. **Not testing with VoiceOver** - Accessibility is important
3. **Hardcoding strings** - Use localization system
4. **Ignoring memory management** - Be careful with retain cycles
5. **Not handling errors** - Always handle potential failures
6. **Breaking existing features** - Test thoroughly

### 🙋 Getting Help

- **Questions**: Open a Discussion on GitHub
- **Issues**: Create an Issue with details
- **Urgent**: Contact maintainers directly

### 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## 中文

### 📋 行为准则

参与此项目即表示您同意为所有贡献者维护一个尊重和包容的环境。

### 🐛 报告错误

在创建错误报告之前，请检查现有问题以避免重复。

**报告错误时，请包含：**
- macOS 版本
- 应用版本
- 重现步骤
- 预期行为
- 实际行为
- 截图（如适用）
- 控制台日志（如适用）

### 💡 功能建议

欢迎功能请求！请提供：
- 功能的清晰描述
- 使用场景和好处
- 潜在的实现方法（如果您有想法）
- 模型或示例（如适用）

### 🔧 开发流程

#### 1. Fork 和克隆

```bash
git clone https://github.com/YOUR_USERNAME/AITranslator.git
cd AITranslator
```

#### 2. 设置开发环境

```bash
make setup
```

这将安装 SwiftLint 和其他必需的依赖项。

#### 3. 创建分支

```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/your-bug-fix
```

分支命名约定：
- `feature/` - 新功能
- `fix/` - 错误修复
- `refactor/` - 代码重构
- `docs/` - 文档更新
- `test/` - 测试添加或修改

#### 4. 进行更改

**开始前：**
- 阅读 README.md 中的代码库架构
- 了解现有的代码风格
- 检查相关的 issues 和 PRs

**编码时：**
- 遵循 Swift API 设计指南
- 编写清晰、自我说明的代码
- 为复杂逻辑添加注释
- 保持一致的命名约定
- 保持函数专注和简洁

**代码风格：**
- 最大行长度：150 字符（150 处警告，200 处错误）
- 使用 4 个空格缩进（无制表符）
- 文件以单个换行符结束
- 无尾随空格
- 按字母顺序排序导入
- 使用 `// MARK:` 组织代码部分

#### 5. 测试更改

```bash
# 构建项目
make build

# 运行测试
make test

# 运行应用
make run
```

**测试清单：**
- 应用无错误构建
- 所有现有测试通过
- 新功能按预期工作
- 现有功能无回归
- UI 响应迅速且可访问
- VoiceOver 正常工作（对于 UI 更改）

#### 6. 运行代码检查

```bash
# 检查问题
make lint

# 自动修复问题
make lint-fix
```

**在提交前修复所有 SwiftLint 警告和错误。**

#### 7. 提交更改

编写清晰、描述性的提交消息：

```bash
git commit -m "Add feature: language detection caching"
# 或
git commit -m "Fix: proxy authentication not working for SOCKS5"
```

**提交消息格式：**
```
<type>: <subject>

<body>

<footer>
```

类型：
- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 文档更改
- `style`: 代码样式更改（格式化，无逻辑更改）
- `refactor`: 代码重构
- `test`: 测试添加或修改
- `chore`: 构建过程或辅助工具更改

示例：
```
feat: 添加 Google 语言检测引擎

- 实现 Google 翻译 API 集成
- 添加网络故障错误处理
- 使用新检测选项更新设置 UI

Closes #123
```

#### 8. 推送并创建 Pull Request

```bash
git push origin feature/your-feature-name
```

然后在 GitHub 上创建 Pull Request。

**PR 描述应包括：**
- 进行了哪些更改
- 为什么需要这些更改
- 如何测试更改
- 截图（对于 UI 更改）
- 相关问题（使用 "Closes #123" 自动关闭）

### 📝 代码审查流程

1. **自动检查** 在所有 PR 上运行：
   - SwiftLint
   - 构建验证
   - 测试（如已配置）

2. **手动审查** 由维护者进行：
   - 代码质量
   - 架构一致性
   - 性能影响
   - 无障碍合规性

3. **反馈和迭代**：
   - 处理审查意见
   - 根据需要更新 PR
   - 参与建设性讨论

4. **合并**：
   - PR 通常会被压缩合并
   - 合并后分支将被删除

### 🎨 UI/UX 指南

- 遵循 Apple 的人机界面指南
- 保持与现有 UI 的一致性
- 支持明暗模式
- 使用不同显示比例测试
- 确保键盘导航工作正常
- 提供 VoiceOver 标签和提示
- 使用 SF Symbols 作为图标
- 尊重用户的无障碍设置

### 🌐 本地化

添加或修改 UI 文本时：

1. 在 `Localization.swift` 中添加英文和中文翻译
2. 对所有面向用户的字符串使用 `L10n.tr()`
3. 使用两种语言设置进行测试
4. 确保文本在不同长度下适合 UI

示例：
```swift
// 添加到 L10n.en 和 L10n.zhHans
"feature.title": "Feature Title"
"feature.title": "功能标题"

// 在代码中使用
Text(L10n.tr("feature.title", lang: viewModel.preferences.appLanguage))
```

### 🧪 测试指南

虽然此项目还没有广泛的测试覆盖，但添加测试的贡献非常有价值：

- 业务逻辑的单元测试
- 服务交互的集成测试
- 关键工作流程的 UI 测试
- 无障碍测试

### 📚 文档

在以下情况下更新文档：
- 添加新功能
- 更改现有行为
- 修改配置选项
- 添加依赖项

### ⚠️ 常见陷阱

1. **忘记运行 SwiftLint** - 提交前务必运行
2. **不使用 VoiceOver 测试** - 无障碍很重要
3. **硬编码字符串** - 使用本地化系统
4. **忽略内存管理** - 小心保留循环
5. **不处理错误** - 始终处理潜在失败
6. **破坏现有功能** - 彻底测试

### 🙋 获取帮助

- **问题**：在 GitHub 上开启讨论
- **Issues**：创建详细的 Issue
- **紧急**：直接联系维护者

### 📜 许可证

通过贡献，您同意您的贡献将根据 MIT 许可证进行许可。

---

<p align="center">感谢您的贡献！ / Thank you for your contributions!</p>
