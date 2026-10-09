#!/usr/bin/env bash
# 安装 Livox SDK2（livox_ros_driver2 的编译依赖，rosdep 里没有）
# 上游：https://github.com/Livox-SDK/Livox-SDK2   （本仓库 thirdparty/Livox-SDK2 为本地快照）
# 安装到 /usr/local（默认路径，driver 的 CMakeLists 就写死了找 /usr/local/lib）
set -e
cd "$(dirname "$0")/.."
SDK=thirdparty/Livox-SDK2
[ -d "$SDK" ] || { echo "[错误] 找不到 $SDK"; exit 1; }
mkdir -p "$SDK/build" && cd "$SDK/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
sudo make install
sudo ldconfig
echo "[完成] $(ls -la /usr/local/lib/liblivox_lidar_sdk_shared.so 2>/dev/null)"
