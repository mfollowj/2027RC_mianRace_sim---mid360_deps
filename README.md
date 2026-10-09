# 2027RC 女娲补天 · 仿真外部依赖包（Mid-360）

本仓库是 [`2027RC_mianRace_sim---mid360`](https://github.com/mfollowj/2027RC_mianRace_sim---mid360)
仿真工程的**外部依赖补齐包**。



1. **Mid-360 在 Gazebo 里的仿真**（`libros2_livox.so` 插件 + 真实扫描花样 `mid360.csv`）；
2. **Livox 自定义消息 `livox_ros_driver2/msg/CustomMsg`**（仿真雷达与 LIO 都靠它通信）；
3. **FAST-LIO2（LiDAR-惯性里程计，3D 建图 + 抗丢定位）**。

因此把这些包源码一并放在这里，clone 下来即可编译使用，不需要再去满世界找仓库/改 CMake。

---

## 一、包含的包

| 目录 | ROS 包名 | 作用（在仿真里干什么） | 上游来源 | 许可证 |
| --- | --- | --- | --- | --- |
| [`src/ros2_livox_simulation`](src/ros2_livox_simulation) | `ros2_livox_simulation` | **Mid-360 仿真插件**：`libros2_livox.so` 按真实扫描花样发射射线，发布 `/livox/lidar`(`CustomMsg`) 与 `/livox/lidar/pointcloud`；含 16.8 MB 的真实 `scan_mode/mid360.csv` | [stm32f303ret6/livox_laser_simulation_RO2](https://github.com/stm32f303ret6/livox_laser_simulation_RO2)（原版 [Livox-SDK/livox_laser_simulation](https://github.com/Livox-SDK/livox_laser_simulation) 的 ROS 2 移植） | MIT |
| [`src/livox_ros_driver2`](src/livox_ros_driver2) | `livox_ros_driver2` | **消息定义**（`CustomMsg`/`CustomPoint`）＋真实雷达驱动。仿真只需其消息，但消息与驱动同包，一起编译最省事；自带 Livox SDK（`3rdparty/`） | [Livox-SDK/livox_ros_driver2](https://github.com/Livox-SDK/livox_ros_driver2) | MIT |
| [`src/fast_lio`](src/fast_lio) | `fast_lio` | **3D 建图 + 抗丢定位**：吃 `/livox/lidar` + `/livox/imu` 做 LiDAR-惯性紧耦合里程计，输出 `/Odometry`、`odom→base_link`、`/Laser_map`、`/cloud_registered` | ROS 2 分支由 [Ericsii](https://github.com/Ericsii/FAST_LIO) 维护，原始算法 [hku-mars/FAST_LIO](https://github.com/hku-mars/FAST_LIO) | **GPL-2.0**（注意：其 `package.xml` 里写的是 BSD，实际 LICENSE 文件是 GPLv2） |
| [`src/my_gazebo_plugins`](src/my_gazebo_plugins) | `my_gazebo_plugins` | **可选**：`libcmd_vel_z_plugin.so`，即"支持 `linear.z` 的 planar_move"变体（源自 `gazebo_ros_pkgs` 的 `gazebo_ros_planar_move`）。本项目仿真默认用 `libgazebo_ros_planar_move.so`，**不装也能跑** | 本地修改版，衍生自 `gazebo_ros_pkgs`（BSD-3-Clause / Apache-2.0） | 见上游 gazebo_ros_pkgs |
| [`thirdparty/Livox-SDK2`](thirdparty/Livox-SDK2) | （不是 ROS 包） | **`livox_ros_driver2` 的编译前置**：其 `CMakeLists.txt` 里写死 `find_library(... /usr/local/lib REQUIRED)` 找 `liblivox_lidar_sdk_shared.so`，所以必须先装 SDK2 到 `/usr/local` | [Livox-SDK/Livox-SDK2](https://github.com/Livox-SDK/Livox-SDK2)（本地快照，已剔除 build 产物：126 MB → 2.5 MB） | MIT |

> 与仿真仓库的对应关系（实测引用点）：`ros2_livox_simulation` 7 处、`fast_lio` 5 处、
> `livox_ros_driver2` 4 处。`my_gazebo_plugins` 未被引用，属于备选。

---

## 二、编译

本仓库本身就是标准的 colcon 工作空间布局（`src/` 下放包）。

### 第一步：装 Livox SDK2（必须，且需要 sudo）

```bash
./scripts/install_livox_sdk2.sh          # cmake + make + sudo make install 到 /usr/local
# 装好后应存在：/usr/local/lib/liblivox_lidar_sdk_shared.so
```

### 第二步：一键编译

```bash
./build.sh
```

`build.sh` 实际等价于：

```bash
source /opt/ros/humble/setup.bash
colcon build --symlink-install --parallel-workers $(nproc) \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DHUMBLE_ROS=humble
source install/setup.bash
```

> ⚠️ **最容易卡住的一步：`-DHUMBLE_ROS=humble` 不能省。**
> `livox_ros_driver2` 的 CMakeLists 用 `if(HUMBLE_ROS STREQUAL "humble")` 选择 ROS 2 分支，
> 而这个变量在文件里**从未被赋值**，只能从命令行传。不加它就会走老的 `else()` 分支并报：
>
> ```
> CMake Error: The following variables are used in this project, but they are set to NOTFOUND.
>   .../livox_ros_driver2/LIVOX_INTERFACES_INCLUDE_DIRECTORIES
> ```
>
> （原工作空间的 `build.sh` 里也有同样注释，说明这个坑踩过。）

编译期依赖（apt）：`ros-humble-gazebo-ros-pkgs ros-humble-pcl-ros ros-humble-tf2-ros`。

单个包自检：

```bash
ros2 pkg prefix livox_ros_driver2 ros2_livox_simulation fast_lio   # 三个都要能定位到
ls $(ros2 pkg prefix ros2_livox_simulation)/lib/libros2_livox.so
ls $(ros2 pkg prefix ros2_livox_simulation)/share/ros2_livox_simulation/scan_mode/mid360.csv
```

> `mid360.csv` 由插件在启动时读取，路径写在各包的 xacro 里
> （`$(find ros2_livox_simulation)/scan_mode/mid360.csv`），所以**必须 source 本工作空间**
> 后仿真才能找到它。

---

## 三、与仿真仓库配合使用

```bash
# 终端里 source 顺序：ROS → 本依赖工作空间 → 仿真仓库工作空间
source /opt/ros/humble/setup.bash
source ~/rc_deps_ws/install/setup.bash          # ← 本仓库（livox 消息/插件 + fast_lio）
source ~/rc_sim_ws/install/setup.bash           # ← 仿真包（2027RC_mianRace_sim---mid360）

ros2 launch <仿真包> lio_map.launch.py gui:=true   # 3D 建图（用到 fast_lio + Mid-360 插件）
ros2 launch <仿真包> slam.launch.py   gui:=true   # 2D 建图（只需 Mid-360 插件 + 消息）
```

若只想跑 2D 建图/导航，`fast_lio` 可以暂时不装；但 `livox_ros_driver2`（消息）与
`ros2_livox_simulation`（插件）两者是**必需**的 —— 仿真雷达的话题类型就是
`livox_ros_driver2/msg/CustomMsg`。

### 可以贴到仿真仓库 README 里的三行

```bash
git clone https://github.com/mfollowj/2027RC_mianRace_sim_deps.git ~/rc_deps
cd ~/rc_deps && ./scripts/install_livox_sdk2.sh && ./build.sh     # 首次需 sudo 装 SDK2
source ~/rc_deps/install/setup.bash                               # 再 source 仿真工作空间
```

> 若你的仿真工作空间是**在 source 过别的第三方工作空间的情况下**编译的，
> 它自己的 `install/setup.bash` 会在 source 时把那些"父工作空间"一起带进来，
> 可能出现同名包被覆盖的告警。此时把本依赖仓库放在**最后** source 即可（后者优先），
> 或干脆重新 `colcon build` 一次。

---

## 四、本地改动说明（相对上游）

这些包是为本项目的 Mid-360 仿真就地调过的，**不是上游原封拷贝**：

* `ros2_livox_simulation`
  * `urdf/mid360.xacro`：视觉 mesh 路径改为 `package://pangolin_simulation/meshes/mid360.stl`
    （上游用 `model://mid360.stl`，Gazebo 无法解析，会导致 gzserver 退出）；
  * 传感器强制 `<always_on>true</always_on>` + `<visualize>false</visualize>`：
    插件靠 `OnNewLaserScans()` 回调取数据，缺 `always_on` 时雷达一帧都不更新；
    `visualize=true` 在无 OGRE 渲染场景的 gzserver 里会让射线传感器不工作；
  * 附带中文注释记录了上述踩坑。
* `fast_lio`
  * `config/sim_mid360.yaml`：仿真专用配置（外参 `extrinsic_T=[0,0,0.05]`、关闭外参在线估计、
    关闭 `pcd_save` 防止长时间仿真吃爆内存）；本项目的仿真包里另有一份按自己车体几何
    调整过的 `fastlio_field_mid360*.yaml`；
  * `launch/mapping.launch.py`：ROS 2 启动文件（含 `use_sim_time`、`config_path/config_file` 参数）。
* `my_gazebo_plugins`
  * `src/cmd_vel_z_plugin.cpp`：在 `gazebo_ros_planar_move` 基础上让 `linear.z` 也生效，
    并保留 `publish_odom` / `publish_odom_tf` / `odometry_frame` / `robot_base_frame` 参数。

---

## 五、不需要放进本仓库的依赖（用 apt / rosdep 装）

以下都是 rosdep 可解析的标准包，**不在本仓库内**：

```bash
sudo apt install \
  ros-humble-gazebo-ros-pkgs ros-humble-gazebo-plugins \
  ros-humble-xacro ros-humble-robot-state-publisher ros-humble-joint-state-publisher \
  ros-humble-pointcloud-to-laserscan ros-humble-pcl-ros \
  ros-humble-slam-toolbox ros-humble-nav2-bringup ros-humble-nav2-* \
  ros-humble-octomap-server ros-humble-octomap-msgs ros-humble-octomap-rviz-plugins \
  ros-humble-joy ros-humble-teleop-twist-joy ros-humble-teleop-twist-keyboard \
  ros-humble-rviz2 ros-humble-tf2-ros ros-humble-sensor-msgs-py
```

---

## 六、许可证提醒（重要）

* `ros2_livox_simulation`、`livox_ros_driver2`：**MIT**，可自由使用/修改，保留版权声明即可；
* `fast_lio`：**GPL-2.0**。如果你的整体工程要分发（尤其是二进制分发或与闭源代码链接），
  需要考虑 GPL 的义务；只在校内自用/开源分发则按 GPL 保留声明即可。
  各包原始的 `LICENSE` / `LICENSE.txt` 均已随源码保留，请勿删除。

---

## 七、用 vcstool 从上游拉取（可选）

如果不使用本仓库内的源码快照，也可以用 [`deps.repos`](deps.repos) 从上游直接拉：

```bash
sudo apt install python3-vcstool
vcs import src < deps.repos
```

注意：上游版本会随时间变化，且**不含**上面第四节列出的本地适配改动，
`mid360.xacro` 的 mesh 路径与 `always_on/visualize` 等问题需要自行处理。

---

## 八、目录结构

```
2027RC_mianRace_sim_deps/
├── build.sh                     # 一键编译（已含 -DHUMBLE_ROS=humble）
├── scripts/install_livox_sdk2.sh# 装 Livox SDK2 到 /usr/local（需 sudo）
├── deps.repos                   # 可选：用 vcstool 从上游拉取
├── thirdparty/Livox-SDK2/       # SDK2 源码快照（MIT，2.5 MB）
└── src/
    ├── livox_ros_driver2/       # 消息 + 驱动（MIT）
    ├── ros2_livox_simulation/   # Mid-360 仿真插件 + mid360.csv（MIT）
    ├── fast_lio/                # FAST-LIO2 3D 建图（GPL-2.0）
    └── my_gazebo_plugins/       # 可选 planar_move 变体
```


