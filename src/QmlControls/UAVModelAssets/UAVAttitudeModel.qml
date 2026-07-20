import QtQuick
import QtQuick3D

Node {
    id: node

    // Resources
    PrincipledMaterial {
        id: matte_warm_white_composite_material
        objectName: "Matte warm white composite"
        baseColor: "#fff1f3f4"
        roughness: 0.72
        metalness: 0.08
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Opaque
    }
    PrincipledMaterial {
        id: matte_carbon_fiber_dark_gray_material
        objectName: "Matte carbon fiber dark gray"
        baseColor: "#ff24282d"
        roughness: 0.86
        metalness: 0.02
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Opaque
    }
    PrincipledMaterial {
        id: black_sensor_glass_material
        objectName: "Black sensor glass"
        baseColor: "#ff05080c"
        roughness: 0.18
        metalness: 0.0
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Opaque
    }
    PrincipledMaterial {
        id: subtle_panel_line_gray_material
        objectName: "Subtle panel line gray"
        baseColor: "#ff4e5862"
        roughness: 0.78
        metalness: 0.04
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Opaque
    }
    PrincipledMaterial {
        id: slightly_raised_light_gray_access_panels_material
        objectName: "Slightly raised light gray access panels"
        baseColor: "#ffd3d8dc"
        roughness: 0.68
        metalness: 0.05
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Opaque
    }
    PrincipledMaterial {
        id: cool_gray_composite_accent_material
        objectName: "Cool gray composite accent"
        baseColor: "#ff7b8791"
        roughness: 0.74
        metalness: 0.06
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Opaque
    }
    PrincipledMaterial {
        id: satin_light_gray_inset_panels_material
        objectName: "Satin light gray inset panels"
        baseColor: "#ffbcc4ca"
        roughness: 0.62
        metalness: 0.06
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Opaque
    }

    // Nodes:
    Model {
        id: industrial_Fixed_Wing_UAV_Single_Entity
        objectName: "Industrial_Fixed_Wing_UAV_Single_Entity"
        source: "meshes/industrial_Fixed_Wing_UAV_Single_Entity_mesh.mesh"
        materials: [
            matte_warm_white_composite_material,
            matte_carbon_fiber_dark_gray_material,
            black_sensor_glass_material,
            subtle_panel_line_gray_material,
            slightly_raised_light_gray_access_panels_material,
            cool_gray_composite_accent_material,
            satin_light_gray_inset_panels_material
        ]
    }

    // Animations:
}
