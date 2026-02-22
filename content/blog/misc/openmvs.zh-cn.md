---
title: OpenMVS 上手体验
tags: [杂项]
---

## 环境准备

1. 安装 Docker（后续以Windows平台举例）
2. 拉取镜像

```bash
docker pull colmap/colmap
docker pull openmvs/openmvs-ubuntu
```

3. 准备若干张照片 (可以使用 <https://github.com/cdcseacave/openMVS_sample/tree/master/images>)
4. 建立项目文件夹

{{< filetree/container >}}
{{< filetree/folder name="C:\Users\mioyi\project" >}}
{{< filetree/folder name="images" >}}
{{< filetree/file name="00000.jpg" >}}
{{< filetree/file name="00001.jpg" >}}
{{< filetree/file name="..." >}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< /filetree/container >}}

## 步骤

1. 用COLMAP生成稀疏点云

```bash
# 启动 Docker 容器
docker run -it --rm \
	--gpus=all \ # 挂载GPU，可选
	-v C:\Users\mioyi\project:/data \ # 挂载项目文件夹
	colmap/colmap # colmap容器

# 重建
cd /data
colmap automatic_reconstructor \
	--workspace_path . \
	--image_path ./images \
	--sparse 1 --dense 0

# 运行去畸变（适配OpenMVS）
mkdir dense
colmap image_undistorter \
    --image_path /data/images \
    --input_path /data/sparse/0 \
    --output_path /data/dense \
    --output_type COLMAP \
    --max_image_size 2000

# 转换为TXT格式（适配OpenMVS）
colmap model_converter \
    --input_path /data/dense/sparse \
    --output_path /data/dense/sparse \
    --output_type TXT

# 退出容器
exit
```

2. 用OpenMVS生成纹理

```bash
# 启动 Docker 容器
docker run -it --rm \
	-v C:\Users\mioyi\project:/data \ # 挂载项目文件夹
	openmvs/openmvs-ubuntu

cd /data/dense
# 转换为 OpenMVS 格式
/openMVS_build/bin/InterfaceCOLMAP -i . -o scene.mvs --image-folder images
# 1. 加密点云
/openMVS_build/bin/DensifyPointCloud scene.mvs
# 2. 生成网格
/openMVS_build/bin/ReconstructMesh scene_dense.mvs
# 3. 优化网格（可选）
/openMVS_build/bin/RefineMesh scene_dense_mesh.mvs
# 4. 纹理贴图
/openMVS_build/bin/TextureMesh scene_dense_mesh.mvs

# 退出容器
exit
```

纹理结果为`C:\Users\mioyi\project\dense\scene_dense_mesh_texture.png`
