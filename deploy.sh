#!/bin/bash
set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 开始部署博客...${NC}"

# 获取提交信息
if [ -z "$1" ]; then
    MSG="update: $(date '+%Y-%m-%d %H:%M:%S')"
else
    MSG="$1"
fi

echo -e "${YELLOW}📦 提交信息: ${MSG}${NC}"

# 1. 构建 Hugo
echo -e "${BLUE}🔨 构建 Hugo 站点...${NC}"
hugo --minify

# 2. 推送源码到 source 分支
echo -e "${BLUE}📤 推送源码到 source 分支...${NC}"
git add -A
git commit -m "$MSG" || echo -e "${YELLOW}⚠️ 源码无变更，跳过提交${NC}"
git push origin source

# 3. 推送构建产物到 main 分支
echo -e "${BLUE}🌐 推送构建产物到 main 分支...${NC}"
cd public
git add -A
git commit -m "deploy: $MSG" || echo -e "${YELLOW}⚠️ 构建产物无变更，跳过提交${NC}"
git push -f origin main
cd ..

echo -e "${GREEN}✅ 部署完成！${NC}"
echo -e "${GREEN}🌍 访问地址: https://collensong.github.io/${NC}"
echo -e "${YELLOW}⏳ GitHub Pages 通常需要 1-3 分钟生效${NC}"
