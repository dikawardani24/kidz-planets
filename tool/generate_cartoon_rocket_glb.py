#!/usr/bin/env python3
import json
import math
import struct
import sys

def build_rocket_glb(out_path):
    # Separate mesh data per material so primitive vertex counts match accessor counts
    # Materials: 0: RedBody, 1: WhiteNose, 2: YellowFins, 3: CyanPorthole
    m_positions = [[] for _ in range(4)]
    m_normals = [[] for _ in range(4)]
    m_indices = [[] for _ in range(4)]

    def add_vert(mat_id, pos, norm):
        idx = len(m_positions[mat_id]) // 3
        m_positions[mat_id].extend(pos)
        m_normals[mat_id].extend(norm)
        return idx

    # 1. Smooth Rocket Body & Nose Cone & Engine Nozzle
    profile = [
        (-0.24, 0.07, 1), # Nozzle bottom (White)
        (-0.20, 0.08, 1), # Nozzle top
        (-0.19, 0.12, 0), # Body bottom (Red)
        (-0.10, 0.16, 0), # Lower body
        ( 0.00, 0.17, 0), # Mid belly
        ( 0.10, 0.16, 0), # Upper body
        ( 0.12, 0.15, 1), # Nosecone base (White)
        ( 0.20, 0.11, 1), # Mid nosecone
        ( 0.26, 0.05, 1), # Upper nosecone
        ( 0.28, 0.00, 1), # Tip
    ]

    segments = 24
    # Generate profile vertices per material section
    for i in range(len(profile) - 1):
        y0, r0, mat0 = profile[i]
        y1, r1, _    = profile[i+1]
        mat = mat0

        # Ring vertices for step i and i+1
        ring0 = []
        ring1 = []

        dy = y1 - y0
        dr = r1 - r0
        slope = -dr / dy if dy != 0 else 0

        for j in range(segments):
            a = (j / segments) * 2.0 * math.pi
            ca, sa = math.cos(a), math.sin(a)

            # Normals
            nx, ny, nz = ca, slope, sa
            length = math.sqrt(nx*nx + ny*ny + nz*nz)
            nx, ny, nz = nx/length, ny/length, nz/length

            if r0 == 0:
                p0 = [0.0, y0, 0.0]
                n0 = [0.0, -1.0 if y0 < 0 else 1.0, 0.0]
            else:
                p0 = [r0 * ca, y0, r0 * sa]
                n0 = [nx, ny, nz]

            if r1 == 0:
                p1 = [0.0, y1, 0.0]
                n1 = [0.0, 1.0, 0.0]
            else:
                p1 = [r1 * ca, y1, r1 * sa]
                n1 = [nx, ny, nz]

            v0 = add_vert(mat, p0, n0)
            v1 = add_vert(mat, p1, n1)
            ring0.append(v0)
            ring1.append(v1)

        for j in range(segments):
            j_next = (j + 1) % segments
            v0 = ring0[j]
            v1 = ring0[j_next]
            v2 = ring1[j_next]
            v3 = ring1[j]

            if r1 == 0:
                m_indices[mat].extend([v0, v2, v3])
            elif r0 == 0:
                m_indices[mat].extend([v0, v1, v2])
            else:
                m_indices[mat].extend([v0, v1, v2])
                m_indices[mat].extend([v0, v2, v3])

    # 2. Add 3 Curved Wings/Fins (Yellow, mat=2)
    fin_angles = [0.0, math.pi * 2 / 3, math.pi * 4 / 3]
    for fa in fin_angles:
        cos_f, sin_f = math.cos(fa), math.sin(fa)
        rx, rz = -sin_f, cos_f

        fin_shape = [
            (0.14, -0.15),
            (0.28, -0.20),
            (0.29, -0.16),
            (0.15,  0.02),
        ]
        thick = 0.018

        f_left, f_right = [], []
        for rad, y in fin_shape:
            px = rad * cos_f
            pz = rad * sin_f
            nl = [-rx, 0.0, -rz]
            nr = [rx, 0.0, rz]

            p_l = [px - rx * thick, y, pz - rz * thick]
            p_r = [px + rx * thick, y, pz + rz * thick]

            vl = add_vert(2, p_l, nl)
            vr = add_vert(2, p_r, nr)
            f_left.append(vl)
            f_right.append(vr)

        for k in range(len(fin_shape) - 1):
            kn = k + 1
            m_indices[2].extend([f_left[k], f_left[kn], f_right[kn]])
            m_indices[2].extend([f_left[k], f_right[kn], f_right[k]])

    # 3. Add Glowing Cyan Porthole Window (Cyan, mat=3)
    p_cy, p_cz, p_rad = 0.06, -0.165, 0.065
    p_segs = 16
    c_idx = add_vert(3, [0.0, p_cy, p_cz - 0.005], [0.0, 0.0, -1.0])
    p_ring = []
    for j in range(p_segs):
        a = (j / p_segs) * 2.0 * math.pi
        px = p_rad * math.cos(a)
        py = p_cy + p_rad * math.sin(a)
        pz = p_cz - 0.005
        v_i = add_vert(3, [px, py, pz], [0.0, 0.0, -1.0])
        p_ring.append(v_i)

    for j in range(p_segs):
        jn = (j + 1) % p_segs
        m_indices[3].extend([c_idx, p_ring[jn], p_ring[j]])

    # Build binary buffer and glTF structures
    bin_buffer = bytearray()
    buffer_views = []
    accessors = []
    primitives = []

    for mat_id in range(4):
        pos_list = m_positions[mat_id]
        norm_list = m_normals[mat_id]
        idx_list = m_indices[mat_id]

        if not pos_list or not idx_list:
            continue

        num_v = len(pos_list) // 3
        min_p = [min(pos_list[i::3]) for i in range(3)]
        max_p = [max(pos_list[i::3]) for i in range(3)]

        # Pos bytes
        pos_bytes = bytearray()
        for v in pos_list:
            pos_bytes.extend(struct.pack('<f', v))
        pos_bv_idx = len(buffer_views)
        pos_acc_idx = len(accessors)
        pos_offset = len(bin_buffer)
        bin_buffer.extend(pos_bytes)
        while len(bin_buffer) % 4 != 0: bin_buffer.extend(b'\x00')

        buffer_views.append({ "buffer": 0, "byteOffset": pos_offset, "byteLength": len(pos_bytes), "target": 34962 })
        accessors.append({
            "bufferView": pos_bv_idx, "byteOffset": 0, "componentType": 5126,
            "count": num_v, "type": "VEC3", "max": max_p, "min": min_p
        })

        # Norm bytes
        norm_bytes = bytearray()
        for n in norm_list:
            norm_bytes.extend(struct.pack('<f', n))
        norm_bv_idx = len(buffer_views)
        norm_acc_idx = len(accessors)
        norm_offset = len(bin_buffer)
        bin_buffer.extend(norm_bytes)
        while len(bin_buffer) % 4 != 0: bin_buffer.extend(b'\x00')

        buffer_views.append({ "buffer": 0, "byteOffset": norm_offset, "byteLength": len(norm_bytes), "target": 34962 })
        accessors.append({
            "bufferView": norm_bv_idx, "byteOffset": 0, "componentType": 5126,
            "count": num_v, "type": "VEC3"
        })

        # Idx bytes
        idx_bytes = bytearray()
        for idx in idx_list:
            idx_bytes.extend(struct.pack('<H', idx))
        idx_bv_idx = len(buffer_views)
        idx_acc_idx = len(accessors)
        idx_offset = len(bin_buffer)
        bin_buffer.extend(idx_bytes)
        while len(bin_buffer) % 4 != 0: bin_buffer.extend(b'\x00')

        buffer_views.append({ "buffer": 0, "byteOffset": idx_offset, "byteLength": len(idx_bytes), "target": 34963 })
        accessors.append({
            "bufferView": idx_bv_idx, "byteOffset": 0, "componentType": 5123, # UNSIGNED_SHORT
            "count": len(idx_list), "type": "SCALAR",
            "max": [max(idx_list)], "min": [min(idx_list)]
        })

        primitives.append({
            "attributes": { "POSITION": pos_acc_idx, "NORMAL": norm_acc_idx },
            "indices": idx_acc_idx,
            "material": mat_id
        })

    gltf_json = {
        "asset": { "version": "2.0", "generator": "kidz_planets_cartoon_rocket_builder" },
        "scene": 0,
        "scenes": [ { "nodes": [0] } ],
        "nodes": [ { "name": "CartoonRocket", "mesh": 0 } ],
        "materials": [
            {
                "name": "RedBody",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.95, 0.22, 0.25, 1.0],
                    "metallicFactor": 0.15,
                    "roughnessFactor": 0.30
                }
            },
            {
                "name": "WhiteNose",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.97, 0.98, 1.0, 1.0],
                    "metallicFactor": 0.10,
                    "roughnessFactor": 0.25
                }
            },
            {
                "name": "YellowFins",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.98, 0.82, 0.15, 1.0],
                    "metallicFactor": 0.15,
                    "roughnessFactor": 0.40
                }
            },
            {
                "name": "CyanPorthole",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.12, 0.75, 0.98, 1.0],
                    "metallicFactor": 0.0,
                    "roughnessFactor": 0.10
                }
            }
        ],
        "meshes": [ { "name": "RocketMesh", "primitives": primitives } ],
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [ { "byteLength": len(bin_buffer) } ]
    }

    json_str = json.dumps(gltf_json, separators=(',', ':'))
    json_bytes = json_str.encode('utf-8')
    while len(json_bytes) % 4 != 0: json_bytes += b' '

    total_len = 12 + (8 + len(json_bytes)) + (8 + len(bin_buffer))

    glb = bytearray()
    glb.extend(struct.pack('<I', 0x46546C67)) # 'glTF'
    glb.extend(struct.pack('<I', 2))          # version 2
    glb.extend(struct.pack('<I', total_len))

    # Chunk 0 JSON
    glb.extend(struct.pack('<I', len(json_bytes)))
    glb.extend(struct.pack('<I', 0x4E4F534A)) # 'JSON'
    glb.extend(json_bytes)

    # Chunk 1 BIN
    glb.extend(struct.pack('<I', len(bin_buffer)))
    glb.extend(struct.pack('<I', 0x004E4942)) # 'BIN\0'
    glb.extend(bin_buffer)

    with open(out_path, 'wb') as f:
        f.write(glb)

    print(f"Successfully generated 3D Cartoon Rocket GLB at {out_path} ({len(glb)} bytes)")

if __name__ == '__main__':
    out_path = sys.argv[1] if len(sys.argv) > 1 else 'rocket.glb'
    build_rocket_glb(out_path)
