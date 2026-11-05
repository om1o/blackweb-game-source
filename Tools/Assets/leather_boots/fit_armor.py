"""Fit credited MakeHuman garments to Rocketbox Luke; run with Blender 4.5 LTS.

Source packs remain outside the project. Runtime export contains only clothing,
not a duplicate Luke body. Artist UVs and geometry detail are retained.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

ROOT = Path('D:/GameProjects/BlackwebHouseRebuild-20261103')
WORK = Path('D:/CodexTemp/Blackweb-RealArmor-20261105')
OUT = ROOT / 'Godot/assets/third_party/makehuman_armor'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(WORK / 'luke_boots_reference.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
rig.data.pose_position = 'REST'
world_points = [body.matrix_world @ v.co for v in body.data.vertices]
tree = KDTree(len(world_points))
for i, p in enumerate(world_points):
    tree.insert(p, i)
tree.balance()
body_groups = {g.index: g.name for g in body.vertex_groups}

def import_obj(path, name, deform):
    points, uvs, faces, face_uvs = [], [], [], []
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == 'v':
            points.append(deform(Vector(tuple(map(float, fields[1:4])))))
        elif fields[0] == 'vt':
            uvs.append(tuple(map(float, fields[1:3])))
        elif fields[0] == 'f':
            tokens = [f.split('/') for f in fields[1:]]
            faces.append([int(t[0])-1 for t in tokens])
            face_uvs.append([int(t[1])-1 if len(t)>1 and t[1] else 0 for t in tokens])
    mesh = bpy.data.meshes.new(name + 'Mesh')
    mesh.from_pydata(points, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name='UVMap')
    for poly, indices in zip(mesh.polygons, face_uvs):
        for loop, index in zip(poly.loop_indices, indices):
            uv.data[loop].uv = uvs[index]
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def boot_fit(v):
    side = 1 if v.x >= 0 else -1
    return Vector((side * (.13 + (abs(v.x)-1.55)*.087),
                   -.105 * v.z + .024,
                   (v.y + 8.4273)*.102 - .001))

def pants_fit(v):
    return Vector((v.x*.087, -v.z*.099 + .015, (v.y+8.3)*.103))

def shirt_fit(v):
    x, depth, z = v.x*.1, -v.z*.1, (v.y+8.3)*.1
    side = 1 if x >= 0 else -1
    ax = abs(x)
    # Raise the source's lowered sleeves by 15 degrees into Luke's A rest pose. A smooth blend
    # near the shoulder avoids a hard deformation seam through the underarm.
    blend = max(0., min(1., (ax - (.18 + max(0., 1.3-z)*.10)) / .085))
    blend = blend*blend*(3.-2.*blend)
    dx, dz = ax-.185, z-1.315
    a = math.radians(15)
    raised_x = .185 + dx*math.cos(a)-dz*math.sin(a)
    raised_z = 1.315 + dx*math.sin(a)+dz*math.cos(a)
    ax = ax*(1-blend)+raised_x*blend
    z = z*(1-blend)+raised_z*blend
    # Broaden torso for Luke; reduce the source garment's bust projection.
    torso = 1.-blend
    depth *= 1.-.14*torso
    waist = max(0., min(1., (1.32-z)/.30)) * torso
    ax *= 1.+.12*waist
    if torso > .4 and .98 < z < 1.42:
        ellipse_depth = .132*math.sqrt(max(.08, 1.-(ax/.245)**2))
        target_depth = math.copysign(ellipse_depth, depth)
        edge = min(1., (z-.98)/.08, (1.42-z)/.08)
        amount = .25*torso*max(0.,edge)
        depth = depth*(1.-amount)+target_depth*amount
    return Vector((side*ax*1.07, depth+.012, z+.13))

def hood_fit(v):
    depth = -v.z*.105+.067
    if depth > .09: depth = .09+(depth-.09)*.43
    return Vector((v.x*.122, depth, (v.y-6.1615)*.112+1.515))

def fit_sleeve_sections(obj):
    # Map smooth source sections onto the actual shoulder/elbow/wrist axis.
    # Body X slices also contain torso points near the shoulder, so sampling
    # their extrema creates discontinuities and must not be used for sleeve fit.
    original=[v.co.copy() for v in obj.data.vertices]
    for side in (-1,1):
        side_name='L' if side>0 else 'R'
        joints=[rig.matrix_world @ rig.data.bones[f'Bip01 {side_name} {bone}'].head_local
                for bone in ('UpperArm','Forearm','Hand')]
        # Cover the original jacket cuff up to the palm base, with a small
        # overlap so wrist rotation cannot reveal a strip of the old garment.
        hand_x=abs(joints[2].x)+.016
        source=[p for p in original if p.x*side>.22]
        source_end=max(p.x*side for p in source)
        bins=[]
        for index in range(24):
            x=.22+(source_end-.22)*index/23
            section=[p for p in source if abs(p.x*side-x)<.035]
            bins.append([(min(p[a] for p in section)+max(p[a] for p in section))*.5
                         for a in (1,2)]+[(max(p[a] for p in section)-min(p[a] for p in section))*.5
                         for a in (1,2)])
        for _ in range(5):
            bins=[bins[0]]+[[sum(bins[i+j][a] for j in (-1,0,1))/3 for a in range(4)]
                            for i in range(1,23)]+[bins[-1]]
        for vertex, old in zip(obj.data.vertices, original):
            ax=old.x*side
            if ax<=.22: continue
            t=(ax-.22)/(source_end-.22)
            target_x=.22+t*(hand_x-.22)
            index=min(22,int(t*23))
            frac=t*23-index
            section=[bins[index][a]*(1-frac)+bins[index+1][a]*frac for a in range(4)]
            joint_index=0 if target_x<abs(joints[1].x) else 1
            a,b=joints[joint_index:joint_index+2]
            along=max(0.,min(1.,(target_x-abs(a.x))/(abs(b.x)-abs(a.x))))
            center=a.lerp(b,along)
            direction=(b-a).normalized()
            outward=Vector((-direction.z*side,0,abs(direction.x)))
            depth=max(-1.15,min(1.15,(old.y-section[0])/max(.02,section[2])))
            height=max(-1.15,min(1.15,(old.z-section[1])/max(.02,section[3])))
            radius_depth=.063*(1-t)+.040*t
            radius_height=.070*(1-t)+.043*t
            new=center+Vector((0,depth*radius_depth,0))+outward*(height*radius_height)
            blend=min(1.,max(0.,(ax-.22)/.08))
            blend=blend*blend*(3.-2.*blend)
            vertex.co=old.lerp(new,blend)
    obj.data.update()

def fit_hood_clearance(obj):
    # A 3-D clearance envelope preserves a rounded crown. Horizontal-only
    # expansion incorrectly stretches top rings into a flat cylinder.
    head=[p for p in world_points if p.z>1.61]
    low=Vector(tuple(min(p[a] for p in head) for a in range(3)))
    high=Vector(tuple(max(p[a] for p in head) for a in range(3)))
    center=(low+high)*.5
    radius=(high-low)*.5+Vector((.015,.015,.018))
    for vertex in obj.data.vertices:
        p=vertex.co
        if p.z<1.61: continue
        delta=p-center
        normalized=Vector(tuple(delta[a]/radius[a] for a in range(3)))
        if .001<normalized.length<1.:
            blend=min(1.,(p.z-1.61)/.035)
            vertex.co=p.lerp(center+delta/normalized.length,blend)
    obj.data.update()

def material(name, color_file, normal_file, tint, roughness=.64):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*tint, 1)
    nodes, links = m.node_tree.nodes, m.node_tree.links
    p = nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = 0.
    p.inputs['Base Color'].default_value = (*tint, 1)
    if color_file and color_file.exists():
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(color_file), check_existing=True)
        # Keep source image unchanged; PBR tinting is applied by runtime material.
        links.new(tex.outputs['Color'], p.inputs['Base Color'])
    if normal_file and normal_file.exists():
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(normal_file), check_existing=True)
        tex.image.colorspace_settings.name = 'Non-Color'
        normal = nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = .65
        links.new(tex.outputs['Color'], normal.inputs['Color'])
        links.new(normal.outputs['Normal'], p.inputs['Normal'])
    return m

boots_dir = WORK/'boots-selected/clothes/mindfront_shoes_biker_boots_male'
pants_dir = WORK/'pants-selected/clothes/mindfront_male_trousers_1'
shirt_dir = WORK/'shirts-selected/clothes/elvs_hooded_sweat_jacket1'
hood_dir = WORK/'suits-selected/clothes/donitz_monk_robe_hood'
specs = [
    ('Boots', boots_dir/'shoes_biker_boots_male.obj', boot_fit, boots_dir/'Shoes_Biker_Boots.png', boots_dir/'Shoes_Biker_Boots_NRM.png', (.14,.09,.055), .56),
    ('Pants', pants_dir/'m_trousers_01.obj', pants_fit, pants_dir/'M_Trousers_01.png', pants_dir/'M_Trousers_01_NRM.png', (.16,.09,.045), .62),
    ('Shirt', shirt_dir/'ladieshoodiedown1.obj', shirt_fit, shirt_dir/'hoodietex1.png', shirt_dir/'normalshoodie.png', (.19,.10,.045), .58),
    ('Hood', hood_dir/'Monks_Hood.obj', hood_fit, hood_dir/'robe_brown__diffuse.png', hood_dir/'robe__normal_gl.png', (.15,.075,.035), .65),
]
garments=[]
report={}
for name, path, deform, color, normal, tint, roughness in specs:
    obj = import_obj(path, name, deform)
    if name == 'Shirt': fit_sleeve_sections(obj)
    if name == 'Hood': fit_hood_clearance(obj)
    obj.data.materials.append(material(name+'Leather', color, normal, tint, roughness))
    # Smooth nearest-surface transfer from Luke, bounded to the nearest 4
    # reference vertices, then normalize to the 4 strongest deform bones.
    groups={b.name:obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
    for v in obj.data.vertices:
        weights={}
        nearest=tree.find_n(v.co,4)
        for _, index, distance in nearest:
            factor=1./max(distance,.004)**3
            for g in body.data.vertices[index].groups:
                bone=body_groups[g.group]
                if bone in groups:
                    weights[bone]=weights.get(bone,0)+g.weight*factor
        if name=='Shirt' and abs(v.co.x)>.23:
            # Smooth, shared arm weights avoid adjacent sleeve rings binding
            # to unrelated torso vertices or opposite sides of the elbow.
            side='L' if v.co.x>0 else 'R'
            ax=abs(v.co.x)
            forearm=max(0.,min(1.,(ax-.365)/.095))
            forearm=forearm*forearm*(3-2*forearm)
            blend=max(0.,min(1.,(ax-.23)/.07))
            total_old=sum(weights.values())
            weights={k:w/max(total_old,.000001)*(1-blend) for k,w in weights.items()}
            for bone,w in [(f'Bip01 {side} UpperArm',1-forearm),(f'Bip01 {side} Forearm',forearm)]:
                weights[bone]=weights.get(bone,0)+w*blend
        elif name=='Shirt' and v.co.z>1.43 and abs(v.co.x)<.23:
            weights={'Bip01 Spine2':1.0}
        elif name=='Hood':
            head_weight=max(0.,min(1.,(v.co.z-1.52)/.12))
            weights={'Bip01 Head':head_weight,'Bip01 Neck':1-head_weight}
        strongest=sorted(weights.items(), key=lambda q:q[1],reverse=True)[:4]
        total=sum(w for _,w in strongest)
        for bone,w in strongest:
            groups[bone].add([v.index],w/total,'REPLACE')
    mod=obj.modifiers.new('LukeSkin','ARMATURE')
    mod.object=rig
    world=obj.matrix_world.copy()
    obj.parent=rig
    obj.matrix_world=world
    obj.data.calc_loop_triangles()
    report[name]={'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),
                 'bounds_blender':{'min':[min(v.co[i] for v in obj.data.vertices) for i in range(3)],
                                   'max':[max(v.co[i] for v in obj.data.vertices) for i in range(3)]}}
    garments.append(obj)

# Keep the reference body only in editable source for fitting review.
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'luke_fitted_armor.blend'))
runtime_textures=WORK/'runtime_textures'
runtime_textures.mkdir(exist_ok=True)
used_paths={str(p.resolve()) for spec in specs for p in (spec[3],spec[4])}
for image in bpy.data.images:
    if image.source != 'FILE':
        continue
    if str(Path(bpy.path.abspath(image.filepath)).resolve()) not in used_paths:
        continue
    image.reload()
    if len(image.pixels) == 0: raise RuntimeError('Cannot decode image: '+image.filepath)
    # Resize through Blender's image datablock only for standard runtime source
    # conversion; originals are retained in the external acquisition directory.
    if max(image.size) > 2048:
        factor=2048/max(image.size)
        image.scale(round(image.size[0]*factor), round(image.size[1]*factor))
    image.filepath_raw=str(runtime_textures/(image.name+'.png'))
    image.file_format='PNG'
    image.save()

# Export a single GLB with skins. No body geometry, lights or animation included.
bpy.ops.object.select_all(action='DESELECT')
for obj in garments+[rig]:
    obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'luke_fitted_armor.glb'), export_format='GLB',
    use_selection=True, export_animations=False, export_skins=True,
    export_all_influences=False, export_materials='EXPORT', export_yup=True)
(OUT/'fitting-report.json').write_text(json.dumps(report,indent=2))
if '--no-render' in sys.argv:
    print('ARMOR_FITTING_REPORT',json.dumps(report),flush=True)
    raise SystemExit(0)

# Workbench silhouette review is intentionally small and does not claim PBR QA.
body.hide_render=True
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=900
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.world.color=(.12,.12,.12)
cam_data=bpy.data.cameras.new('ArmorReviewCamera')
camera=bpy.data.objects.new('ArmorReviewCamera',cam_data)
bpy.context.collection.objects.link(camera)
camera.location=(2.5,-4.,2.)
direction=Vector((0,0,1.))-camera.location
camera.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO'
cam_data.ortho_scale=2.3
scene.camera=camera
scene.render.filepath=str(WORK/'armor-fit-front.png')
bpy.ops.render.render(write_still=True)
print('ARMOR_FITTING_REPORT',json.dumps(report),flush=True)
