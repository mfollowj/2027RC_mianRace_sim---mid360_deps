#!/usr/bin/env bash
# 一键编译本仓库的全部外部依赖
#
# 重要：livox_ros_driver2 的 CMakeLists 靠 **-DHUMBLE_ROS=humble** 选择 ROS 2 分支，
# 不加这个参数会走老的 else() 分支并报
#   CMake Error: ... LIVOX_INTERFACES_INCLUDE_DIRECTORIES ... set to NOTFOUND
# 这是最容易卡住的一步（原工作空间的 build.sh 里也有同样注释）。
#
# 另外 livox_ros_driver2 链接 /usr/local/lib/liblivox_lidar_sdk_shared.so，
# 编译前必须先装 Livox SDK2：./scripts/install_livox_sdk2.sh
set -e
cd "$(dirname "$0")"
source /opt/ros/humble/setup.bash

if [ ! -f /usr/local/include/livox_lidar_api.h ]; then
    echo "[错误] 没找到 Livox SDK2（/usr/local/include/livox_lidar_api.h）"
    echo "       请先执行: ./scripts/install_livox_sdk2.sh   （需要 sudo）"
    exit 1
fi

colcon build --symlink-install \
    --parallel-workers "$(nproc)" \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DHUMBLE_ROS=humble
echo
echo "[完成] source install/setup.bash 后即可与仿真工程一起使用"
