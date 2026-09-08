#!/usr/bin/env sh
set -eu

SCRIPT_PATH="$0"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || echo "$0")
elif command -v realpath >/dev/null 2>&1; then
  SCRIPT_PATH=$(realpath "$0" 2>/dev/null || echo "$0")
fi
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)
cd "$SCRIPT_DIR"

# 准备缓存目录
mkdir -p /tmp/pansou_cache /tmp/root_cache

# 如果存在 PanCheck 服务，自动后台启动
PANCHECK_DIR="${PANCHECK_DIR:-/root/PanCheck}"
if [ -d "$PANCHECK_DIR" ] && [ -f "$PANCHECK_DIR/pancheck" ]; then
  if ! pgrep -f "$PANCHECK_DIR/pancheck" >/dev/null 2>&1 && ! pgrep -x "pancheck" >/dev/null 2>&1; then
    chmod +x "$PANCHECK_DIR/pancheck" 2>/dev/null || true
    echo "正在后台启动 PanCheck 网盘检测服务..."
    (cd "$PANCHECK_DIR" && nohup ./pancheck >/dev/null 2>&1 &)
  fi
fi

# 基础配置
export PORT="${PORT:-8002}"
export AUTO_UPDATE="${AUTO_UPDATE:-true}"
export FORCE_UPDATE="${FORCE_UPDATE:-false}"

# GitHub 仓库与代理设置
# 如果在国内服务器上下载 GitHub Releases 较慢，可设置 GH_PROXY="https://ghproxy.net/"
export GH_PROXY="${GH_PROXY:-}"

# 搜索源设置 (TG频道)
export CHANNELS="${CHANNELS:-tgsearchers7,Aliyun_4K_Movies,bdbdndn11,yunpanx,bsbdbfjfjff,yp123pan,yunpanxunlei,tianyifc,BaiduCloudDisk,txtyzy,peccxinpd,gotopan,PanjClub,baicaoZY,MCPH01,MCPH02,MCPH03,bdwpzhpd,ysxb48,jdjdn1111,MCPH086,zaihuayun,Q66Share,ucwpzy,shareAliyun,alyp_1,dianyingshare,Quark_Movies,XiangxiuNBB,ydypzyfx,ucquark,xx123pan,yingshifenxiang123,zyfb123,tyypzhpd,tianyirigeng,hdhhd21,Lsp115,oneonefivewpfx,taoxgzy,Channel_Shares_115,tyysypzypd,vip115hot,wp123zy,yunpan139,yunpan189,yunpanuc,yydf_hzl,leoziyuan,Q_dongman,yoyokuakeduanju,TG654TG,QukanMovie,yeqingjie_GJG666,movielover8888_film3,Baidu_netdisk,D_wusun,FLMdongtianfudi,KaiPanshare,QQZYDAPP,rjyxfx,PikPak_Share_Channel,btzhi,newproductsourcing,QuarkFree,yunpanNB,kkdj001,xxzlzn,pxyunpanxunlei,jxwpzy,kuakedongman,liangxingzhinan,xiangnikanj,solidsexydoll,guoman4K,zdqxm,kduanju,cilidianying,CBduanju,SharePanFilms,dzsgx,BooksRealm,Oscar_4Kmovies,douerpan,baidu_yppan,Q_jilupian,Netdisk_Movies,yunpanquark,ammmziyuan,ciliziyuanku,cili8888,jzmm_123pan,Q_dianying,domgmingapk,dianying4k,tgbokee,ucshare,godupan,gokuapan,gimy115,WFYSFX03,peccxin,Movie888035,gimy100,gimy115iso,aliyunys,clouddriveresources,XunLeiPinDao,a123fxme,WPpindao,kuyupan,djya5,pan_guangya,wpan8,mqte5,regengguangya,yunpanguangya,regeng115,regeng123,yoyokuakeduanjujiaoliuqun,yy80986098,guangyapan_episode,AV688,xxziliao,quark_res}"

# 插件配置
export ENABLED_PLUGINS="${ENABLED_PLUGINS:-dyyjpro,duoduo,djgou,feikuai,gaoqing888,gying,hdmoli,haitunsou,hunhepan,ikantv,jutoushe,kkv,dy4k,libvio,lingjisp,lou1,melost,meitizy,miosou,nyaa,ouge,panlian,pansearch,qqpd,quark4k,quarksoo,quarktv,qupanshe,sousou,thepiratebay,ting77,wanou,weibo,xb6v,xiaokupan,xiaozhang,xiaoyu,yingso,yulinshufa,yunso,yunsou,zlxapp,zxzj,rrbt,quarkres,diduan,erxiao,huban,labi,muou,shandian,zhizhen,clxiong,cyg,jsnoteclub,duanjuw,dyyj,jupansou,nsgame,cldi,clmao,susu,u3c3,5266ys,dygang,leso}"

# 异步搜索与超时设置
export ASYNC_RESPONSE_TIMEOUT="${ASYNC_RESPONSE_TIMEOUT:-10}"
export ASYNC_LOG_ENABLED="${ASYNC_LOG_ENABLED:-false}"

APP_BIN="${APP_BIN:-$SCRIPT_DIR/pansou}"
VERSION_FILE="$SCRIPT_DIR/.version"

# 自动识别仓库所有者与名称
detect_repo() {
  if [ -n "${GITHUB_REPO:-}" ]; then
    echo "$GITHUB_REPO"
    return
  fi
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _remote_url=$(git remote get-url origin 2>/dev/null || true)
    if [ -n "$_remote_url" ]; then
      _parsed=$(echo "$_remote_url" | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
      if [ -n "$_parsed" ]; then
        echo "$_parsed"
        return
      fi
    fi
  fi
  echo "linruofei/pansou"
}

# 检测系统架构
detect_arch() {
  _arch=$(uname -m)
  case "$_arch" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      echo ""
      ;;
  esac
}

# 通用下载工具函数
download_file() {
  _url="$1"
  _dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 300 "$_url" -o "$_dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 10 -t 2 "$_url" -O "$_dest"
  else
    echo "[WARN] 未找到 curl 或 wget，无法下载文件。" >&2
    return 1
  fi
}

# 自动检查并拉取最新版本
check_and_update() {
  GOARCH=$(detect_arch)
  if [ -z "$GOARCH" ]; then
    echo "[WARN] 当前系统架构 ($(uname -m)) 暂无对应预编译包，跳过自动更新。"
    return 0
  fi

  REPO=$(detect_repo)
  DOWNLOAD_URL="${GH_PROXY}https://github.com/${REPO}/releases/latest/download/pansou-linux-${GOARCH}.tar.gz"
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"

  echo "[INFO] 正在检查 GitHub 仓库 ($REPO) 最新版本..."

  # 获取远程 Release 元数据 (tag_name 与 published_at)
  REMOTE_META=""
  if command -v curl >/dev/null 2>&1; then
    REMOTE_META=$(curl -fsSL --connect-timeout 5 "$API_URL" 2>/dev/null || true)
  elif command -v wget >/dev/null 2>&1; then
    REMOTE_META=$(wget -qO- -T 5 -t 1 "$API_URL" 2>/dev/null || true)
  fi

  # 提取版本特征指纹（兼容 latest 滚动更新及版本标签）
  REMOTE_SIGNATURE=""
  if [ -n "$REMOTE_META" ]; then
    REMOTE_TAG=$(echo "$REMOTE_META" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)
    REMOTE_DATE=$(echo "$REMOTE_META" | grep '"published_at":' | head -n 1 | sed -E 's/.*"published_at": *"([^"]+)".*/\1/' || true)
    REMOTE_SIGNATURE="${REMOTE_TAG}_${REMOTE_DATE}"
  fi

  LOCAL_SIGNATURE=""
  if [ -f "$VERSION_FILE" ]; then
    LOCAL_SIGNATURE=$(cat "$VERSION_FILE" 2>/dev/null || true)
  fi

  # 检查是否已是最新版本且可执行程序完好
  if [ "$FORCE_UPDATE" != "true" ] && [ -n "$REMOTE_SIGNATURE" ] && [ "$REMOTE_SIGNATURE" = "$LOCAL_SIGNATURE" ] && [ -x "$APP_BIN" ]; then
    echo "[INFO] 当前已是最新版本 ($REMOTE_TAG)，无需更新。"
    return 0
  fi

  echo "[INFO] 发现新版本或本地未初始化，正在拉取: $DOWNLOAD_URL ..."
  TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'pansou')
  TMP_TAR="$TMP_DIR/pansou.tar.gz"

  if ! download_file "$DOWNLOAD_URL" "$TMP_TAR"; then
    # 备用下载地址 (兼容直接使用 tag 名字路径)
    FALLBACK_URL="${GH_PROXY}https://github.com/${REPO}/releases/download/${REMOTE_TAG:-latest}/pansou-linux-${GOARCH}.tar.gz"
    echo "[INFO] 尝试备用下载地址: $FALLBACK_URL ..."
    if ! download_file "$FALLBACK_URL" "$TMP_TAR"; then
      echo "[WARN] 拉取最新版本失败（网络超时或未发布 Release）。"
      rm -rf "$TMP_DIR"
      if [ -x "$APP_BIN" ]; then
        echo "[INFO] 本地已有可执行文件，继续使用当前版本启动。"
        return 0
      else
        echo "[ERROR] 本地不存在可执行文件 $APP_BIN，启动失败。" >&2
        exit 1
      fi
    fi
  fi

  echo "[INFO] 下载完成，正在解压更新..."
  if ! tar -zxf "$TMP_TAR" -C "$TMP_DIR" 2>/dev/null; then
    echo "[WARN] 解压失败，安装包可能损坏。"
    rm -rf "$TMP_DIR"
    return 0
  fi

  # 寻找解压目录中的 pansou 文件
  SRC_DIR=""
  if [ -f "$TMP_DIR/pansou" ]; then
    SRC_DIR="$TMP_DIR"
  else
    for d in "$TMP_DIR"/*; do
      if [ -d "$d" ] && [ -f "$d/pansou" ]; then
        SRC_DIR="$d"
        break
      fi
    done
  fi

  if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/pansou" ]; then
    echo "[WARN] 未在解压包中找到 pansou 可执行文件，跳过替换。"
    rm -rf "$TMP_DIR"
    return 0
  fi

  # 安全更新文件（通过 rm 解除旧 inode 避免 Linux "Text file busy" 报错）
  rm -f "$APP_BIN"
  cp -f "$SRC_DIR/pansou" "$APP_BIN"
  chmod +x "$APP_BIN"

  # 更新 web 前端资源
  if [ -d "$SRC_DIR/web" ]; then
    rm -rf "$SCRIPT_DIR/web"
    cp -rf "$SRC_DIR/web" "$SCRIPT_DIR/web"
  fi

  # 记录版本指纹
  if [ -n "$REMOTE_SIGNATURE" ]; then
    echo "$REMOTE_SIGNATURE" > "$VERSION_FILE"
  fi

  rm -rf "$TMP_DIR"
  echo "[INFO] 程序已成功更新到最新版本！"
}

# 如果启用了自动更新，先执行更新流程
if [ "$AUTO_UPDATE" = "true" ]; then
  check_and_update
fi

# 检查可执行文件是否存在
if [ ! -x "$APP_BIN" ]; then
  echo "pansou binary not found or not executable: $APP_BIN" >&2
  exit 1
fi

# 检查并优雅停止已在运行的旧实例
OLD_PID=$(pgrep -f "$APP_BIN" 2>/dev/null || pgrep -x "pansou" 2>/dev/null || true)
if [ -n "$OLD_PID" ]; then
  echo "[INFO] 发现正在运行的旧进程 (PID: $OLD_PID)，正在停止以重新加载..."
  kill $OLD_PID 2>/dev/null || true
  sleep 1
fi

# 后台启动并完全静默（无任何日志输出）
echo "正在后台启动 PanSou (端口: $PORT)..."
nohup "$APP_BIN" > /dev/null 2>&1 &
APP_PID=$!

sleep 1
if kill -0 "$APP_PID" 2>/dev/null; then
  echo "PanSou 已在后台成功启动！"
  echo "进程 PID: $APP_PID"
  echo "服务端口: $PORT"
  echo "健康检查: http://localhost:$PORT/api/health"
else
  echo "[ERROR] 后台启动失败，请检查端口 $PORT 是否被占用或文件执行权限。" >&2
  exit 1
fi
