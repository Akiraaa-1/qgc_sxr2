import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector


MODEL_PATH = "/home/btfw/BlenderModels/industrial_fixed_wing_uav_clean_nose.glb"
OUTPUT_DIR = "/home/btfw/桌面/qgc_sxr2/src/AutoPilotPlugins/PX4/Images"
RESOLUTION_X = 792
RESOLUTION_Y = 640
DISPLAY_YAW_OFFSET_DEG = 180


POSES = {
    "VehicleDown.png": (0, 0, 0),
    "VehicleDownRotate.png": (0, 0, 25),
    "VehicleUpsideDown.png": (180, 0, 0),
    "VehicleUpsideDownRotate.png": (180, 0, 25),
    "VehicleNoseDown.png": (0, 90, 0),
    "VehicleNoseDownRotate.png": (0, 90, 25),
    "VehicleTailDown.png": (0, -90, 0),
    "VehicleTailDownRotate.png": (0, -90, 25),
    "VehicleLeft.png": (-90, 0, 0),
    "VehicleLeftRotate.png": (-90, 0, 25),
    "VehicleRight.png": (90, 0, 0),
    "VehicleRightRotate.png": (90, 0, 25),
}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_model():
    bpy.ops.import_scene.gltf(filepath=MODEL_PATH)
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not objects:
        raise RuntimeError("No mesh objects found in GLB")

    root = bpy.data.objects.new("CalibrationUAVRoot", None)
    bpy.context.collection.objects.link(root)
    for obj in objects:
        obj.parent = root

    bpy.context.view_layer.update()
    min_v = Vector((float("inf"), float("inf"), float("inf")))
    max_v = Vector((float("-inf"), float("-inf"), float("-inf")))
    for obj in objects:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_v.x = min(min_v.x, world.x)
            min_v.y = min(min_v.y, world.y)
            min_v.z = min(min_v.z, world.z)
            max_v.x = max(max_v.x, world.x)
            max_v.y = max(max_v.y, world.y)
            max_v.z = max(max_v.z, world.z)

    center = (min_v + max_v) * 0.5
    for obj in objects:
        obj.location -= center

    root.location = (0, 0, 0)
    return root


def style_materials():
    for material in bpy.data.materials:
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue

        name = material.name.lower()
        if "black" in name or "sensor" in name or "glass" in name:
            color = (0.015, 0.02, 0.025, 1.0)
            roughness = 0.25
            metallic = 0.0
        elif "carbon" in name or "dark" in name:
            color = (0.10, 0.12, 0.14, 1.0)
            roughness = 0.78
            metallic = 0.05
        elif "panel" in name or "gray" in name:
            color = (0.68, 0.72, 0.74, 1.0)
            roughness = 0.62
            metallic = 0.08
        else:
            color = (0.88, 0.90, 0.90, 1.0)
            roughness = 0.58
            metallic = 0.05

        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_camera_and_lights():
    bpy.ops.object.light_add(type="AREA", location=(0, -4.5, 5.5))
    key = bpy.context.object
    key.name = "large soft key"
    key.data.energy = 560
    key.data.size = 4.5

    bpy.ops.object.light_add(type="POINT", location=(-3.8, 3.5, 3.0))
    fill = bpy.context.object
    fill.name = "cool fill"
    fill.data.energy = 95

    bpy.ops.object.camera_add(location=(-5.4, -6.4, 4.4))
    camera = bpy.context.object
    look_at(camera, (0, 0, 0))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 7.7
    bpy.context.scene.camera = camera


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 96
    scene.render.resolution_x = RESOLUTION_X
    scene.render.resolution_y = RESOLUTION_Y
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1

    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"


def attitude_quaternion(roll, pitch, yaw):
    # Blender's glTF importer brings this GLB in with the wings on local Z.
    # Rotate the raw model into QGC/body axes first: nose +X, wings Y, height Z.
    q_model_to_body = Quaternion((1, 0, 0), math.radians(-90))
    q_roll = Quaternion((1, 0, 0), math.radians(roll))
    q_pitch = Quaternion((0, 1, 0), math.radians(pitch))
    q_yaw = Quaternion((0, 0, 1), math.radians(yaw + DISPLAY_YAW_OFFSET_DEG))
    return q_yaw @ q_pitch @ q_roll @ q_model_to_body


def render_pose(root, filename, angles):
    roll, pitch, yaw = angles
    root.rotation_mode = "QUATERNION"
    root.rotation_quaternion = attitude_quaternion(roll, pitch, yaw)
    bpy.context.view_layer.update()

    bpy.context.scene.render.filepath = os.path.join(OUTPUT_DIR, filename)
    bpy.ops.render.render(write_still=True)


def main():
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(MODEL_PATH)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    clear_scene()
    root = import_model()
    style_materials()
    setup_camera_and_lights()
    setup_render()

    for filename, angles in POSES.items():
        print(f"Rendering {filename}: roll={angles[0]} pitch={angles[1]} yaw={angles[2]}")
        render_pose(root, filename, angles)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
