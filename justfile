# AI Translator - Justfile
# 使用 just 管理开发任务

# 默认命令：显示所有可用命令
default:
    @just --list

# 安装开发依赖
setup:
    @echo "📦 安装开发依赖..."
    @if ! command -v asdf &> /dev/null; then \
        echo "❌ asdf 未安装，请先安装 asdf"; \
        echo "   参考: https://asdf-vm.com/guide/getting-started.html"; \
        exit 1; \
    fi
    @echo "安装 asdf 插件..."
    -asdf plugin add swift
    -asdf plugin add swiftlint
    @echo "安装工具版本..."
    asdf install
    @echo "✅ 开发环境设置完成"

# 构建项目（Debug）
# xcode-select -p
## /Library/Developer/CommandLineTools
# sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
build:
    @echo "🔨 构建项目 (Debug)..."
    xcodebuild -project AITranslator.xcodeproj \
        -scheme AITranslator \
        -configuration Debug \
        build
    @echo "✅ 构建完成"
    @echo "📂 产物位置: ~/Library/Developer/Xcode/DerivedData/AITranslator-*/Build/Products/Debug/"

# 构建并打开产物文件夹
build-open:
    @just build
    @echo "📂 打开产物文件夹..."
    @open ~/Library/Developer/Xcode/DerivedData/AITranslator-*/Build/Products/Debug/AITranslator.app

# 构建项目（Release）
build-release:
    @echo "🔨 构建项目 (Release)..."
    xcodebuild -project AITranslator.xcodeproj \
        -scheme AITranslator \
        -configuration Release \
        build
    @echo "✅ 构建完成"
    @echo "📂 产物位置: ~/Library/Developer/Xcode/DerivedData/AITranslator-*/Build/Products/Release/"

# 构建 Release 并打开产物文件夹
build-release-open:
    @just build-release
    @echo "📂 打开产物文件夹..."
    @open ~/Library/Developer/Xcode/DerivedData/AITranslator-*/Build/Products/Release/

# 运行测试
test:
    @echo "🧪 运行测试..."
    xcodebuild test \
        -project AITranslator.xcodeproj \
        -scheme AITranslator

# 运行 SwiftLint 检查
lint:
    @echo "🔍 运行 SwiftLint..."
    swiftlint lint

# 运行 SwiftLint 自动修复
lint-fix:
    @echo "🔧 运行 SwiftLint 自动修复..."
    swiftlint --fix

# 运行 SwiftLint 并显示详细信息
lint-verbose:
    @echo "🔍 运行 SwiftLint (详细模式)..."
    swiftlint lint --verbose

# 修复文件末尾换行符
fix-newlines:
    @echo "🔧 修复文件末尾换行符..."
    @find AITranslator -name "*.swift" -type f -exec sh -c \
        'tail -c1 "$1" | read -r _ || echo "" >> "$1"' _ {} \;
    @echo "✅ 修复完成"

# 清理构建产物
clean:
    @echo "🧹 清理构建产物..."
    xcodebuild clean \
        -project AITranslator.xcodeproj \
        -scheme AITranslator
    @echo "✅ 清理完成"

# 彻底清理（包括 DerivedData）
clean-all:
    @echo "🧹 彻底清理构建产物..."
    xcodebuild clean \
        -project AITranslator.xcodeproj \
        -scheme AITranslator
    @echo "🗑️  删除 DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/AITranslator-*
    rm -rf build/
    rm -rf DerivedData/
    @echo "✅ 彻底清理完成"

# 构建并运行应用
run: build
    @echo "🚀 运行应用..."
    @open ~/Library/Developer/Xcode/DerivedData/AITranslator-*/Build/Products/Debug/AITranslator.app

# 打开产物文件夹（Debug）
open-build:
    @echo "📂 打开 Debug 产物文件夹..."
    @open ~/Library/Developer/Xcode/DerivedData/AITranslator-*/Build/Products/Debug/AITranslator.app

# 打开产物文件夹（Release）
open-release:
    @echo "📂 打开 Release 产物文件夹..."
    @open ~/Library/Developer/Xcode/DerivedData/AITranslator-*/Build/Products/Release/

# 打开 Xcode
xcode:
    @echo "🔨 打开 Xcode..."
    open AITranslator.xcodeproj

# 归档应用
archive:
    @echo "📦 创建归档..."
    xcodebuild archive \
        -project AITranslator.xcodeproj \
        -scheme AITranslator \
        -archivePath build/AITranslator.xcarchive

# 导出应用（需要先创建 exportOptions.plist）
export: archive
    @echo "📦 导出应用..."
    @if [ ! -f exportOptions.plist ]; then \
        echo "❌ 未找到 exportOptions.plist"; \
        exit 1; \
    fi
    xcodebuild -exportArchive \
        -archivePath build/AITranslator.xcarchive \
        -exportPath build/export \
        -exportOptionsPlist exportOptions.plist

# 统计代码行数
loc:
    @echo "📊 代码统计:"
    @echo ""
    @echo "Swift 文件:"
    @find AITranslator -name "*.swift" -type f | wc -l | xargs echo "  文件数:"
    @find AITranslator -name "*.swift" -type f -exec wc -l {} + | tail -1 | awk '{print "  代码行数: " $$1}'
    @echo ""
    @echo "按目录统计:"
    @find AITranslator -name "*.swift" -type f | xargs wc -l | sort -rn | head -20

# 格式化所有 Swift 文件（如果安装了 swift-format）
format:
    @if command -v swift-format &> /dev/null; then \
        echo "🎨 格式化代码..."; \
        find AITranslator -name "*.swift" -type f -exec swift-format -i {} \; ; \
        echo "✅ 格式化完成"; \
    else \
        echo "❌ swift-format 未安装"; \
        echo "   安装: brew install swift-format"; \
    fi

# 检查 Git 状态
status:
    @echo "📊 Git 状态:"
    @git status --short

# 显示当前工具版本
version:
    @echo "🔧 当前工具版本:"
    @echo "Swift: $(swift --version | head -1)"
    @if command -v swiftlint &> /dev/null; then \
        echo "SwiftLint: $(swiftlint version)"; \
    else \
        echo "SwiftLint: 未安装"; \
    fi
    @echo "Xcode: $(xcodebuild -version | head -1)"
    @if command -v asdf &> /dev/null; then \
        echo "asdf: $(asdf --version)"; \
    else \
        echo "asdf: 未安装"; \
    fi

# 完整的代码检查流程
check: lint test
    @echo "✅ 所有检查通过"

# 准备提交前的检查
pre-commit: fix-newlines lint-fix check
    @echo "✅ 准备就绪，可以提交"

# 生成 Xcode 文档
docs:
    @echo "📚 生成文档..."
    @if command -v jazzy &> /dev/null; then \
        jazzy \
            --clean \
            --author "AI Translator" \
            --module AITranslator \
            --source-directory AITranslator \
            --output docs; \
        echo "✅ 文档已生成到 docs/ 目录"; \
    else \
        echo "❌ jazzy 未安装"; \
        echo "   安装: gem install jazzy"; \
    fi

# 安装 Git hooks
install-hooks:
    @echo "🔧 安装 Git hooks..."
    @mkdir -p .git/hooks
    @echo '#!/bin/sh\njust lint-fix\njust lint' > .git/hooks/pre-commit
    @chmod +x .git/hooks/pre-commit
    @echo "✅ Git hooks 已安装"

# 显示项目信息
info:
    @echo "📦 AI Translator 项目信息"
    @echo ""
    @echo "项目路径: $(pwd)"
    @echo "Xcode 项目: AITranslator.xcodeproj"
    @echo ""
    @just version
    @echo ""
    @just loc

