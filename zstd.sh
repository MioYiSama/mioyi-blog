if [ ! -d "public" ]; then
  echo "public 目录不存在，请先运行 hugo 命令。"
  exit 1
fi

echo "开始使用 Zstd 压缩静态文件..."

find public -type f \( \
  -name "*.html" -o \
  -name "*.css"  -o \
  -name "*.js"   -o \
  -name "*.md"  -o \
  -name "*.xml"  -o \
  -name "*.json" -o \
  -name "*.svg"  -o \
  -name "*.webmanifest"  \
\) -exec zstd -k -19 -q {} \;

echo "Zstd 压缩完成！"