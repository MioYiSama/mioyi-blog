---
title: OpenMVS Hands-on Experience
tags: [misc]
---

## Environment Preparation

1. Install Docker (Windows platform will be used as an example below)

2. Pull images

```bash
docker pull colmap/colmap
docker pull openmvs/openmvs-ubuntu
```

3. Prepare several photos (You can use <https://github.com/cdcseacave/openMVS_sample/tree/master/images>)
4. Create a project folder

{{< filetree/container >}}
{{< filetree/folder name="C:\Users\mioyi\project" >}}
{{< filetree/folder name="images" >}}
{{< filetree/file name="00000.jpg" >}}
{{< filetree/file name="00001.jpg" >}}
{{< filetree/file name="..." >}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< /filetree/container >}}

## Steps

1. Use COLMAP to generate sparse point clouds

```bash
# Start Docker container
docker run -it --rm \
	--gpus=all \ # Mount GPU, optional
	-v C:\Users\mioyi\project:/data \ # Mount project folder
	colmap/colmap # colmap container

# Reconstruction
cd /data
colmap automatic_reconstructor \
	--workspace_path . \
	--image_path ./images \
	--sparse 1 --dense 0

# Run undistortion (to adapt for OpenMVS)
mkdir dense
colmap image_undistorter \
    --image_path /data/images \
    --input_path /data/sparse/0 \
    --output_path /data/dense \
    --output_type COLMAP \
    --max_image_size 2000

# Convert to TXT format (to adapt for OpenMVS)
colmap model_converter \
    --input_path /data/dense/sparse \
    --output_path /data/dense/sparse \
    --output_type TXT

# Exit container
exit
```

2. Use OpenMVS to generate textures

```bash
# Start Docker container
docker run -it --rm \
	-v C:\Users\mioyi\project:/data \ # Mount project folder
	openmvs/openmvs-ubuntu

cd /data/dense
# Convert to OpenMVS format
/openMVS_build/bin/InterfaceCOLMAP -i . -o scene.mvs --image-folder images
# 1. Densify point cloud
/openMVS_build/bin/DensifyPointCloud scene.mvs
# 2. Reconstruct mesh
/openMVS_build/bin/ReconstructMesh scene_dense.mvs
# 3. Refine mesh (optional)
/openMVS_build/bin/RefineMesh scene_dense_mesh.mvs
# 4. Texture mesh
/openMVS_build/bin/TextureMesh scene_dense_mesh.mvs

# Exit container
exit
```

The texture result is located at `C:\Users\mioyi\project\dense\scene_dense_mesh_texture.png`