"""Final material/face and continuous-gait pass; run after build_smiling_spider.py.
Blender --background --threads 4 --python Tools/Assets/refine_smiling_spider.py
"""
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Godot/assets/generated/smiling_spider'
WORK=Path('D:/GameProjects/Blackweb-BossWorkshop/SmilingSpider-v2')
bpy.ops.wm.open_mainfile(filepath=str(WORK/'smiling_spider_geometry.blend'))
model=bpy.data.objects['SmilingSpider_Sculpt'];arm=bpy.data.objects['SmilingSpiderRig']

# Independent connected pieces retain their physical positions and skin weights.
bm=bmesh.new();bm.from_mesh(model.data);remaining=set(bm.verts);remove=[]
while remaining:
    seed=remaining.pop();group={seed};stack=[seed]
    while stack:
        v=stack.pop()
        for edge in v.link_edges:
            other=edge.other_vert(v)
            if other in remaining:remaining.remove(other);group.add(other);stack.append(other)
    center=sum((v.co for v in group),Vector())/len(group)
    material=model.data.materials[next(iter(seed.link_faces)).material_index] if seed.link_faces else None
    if material and material.name.startswith('Black glass'):
        for v in group:v.co=center+(v.co-center)*.78
    if material and material.name.startswith('Raised carapace') and center.y>.75 and 1.3<center.z<1.85:
        for v in group:v.co=center+(v.co-center)*.82
    if material and material.name.startswith('Carved limestone') and center.z>2.15:
        dimensions=[max(v.co[i] for v in group)-min(v.co[i] for v in group) for i in range(3)]
        if max(dimensions)<.085:remove.extend(group)
if remove:bmesh.ops.delete(bm,geom=remove,context='VERTS')
bm.to_mesh(model.data);bm.free()

# Box-projected UVs give every leg, ridge and shell usable texture coordinates.
uv=model.data.uv_layers.new(name='ChitinDetail')
for face in model.data.polygons:
    axis=max(range(3),key=lambda i:abs(face.normal[i]));other=[i for i in range(3) if i!=axis]
    for li in face.loop_indices:
        v=model.data.vertices[model.data.loops[li].vertex_index].co
        uv.data[li].uv=(v[other[0]]*1.1,v[other[1]]*1.1)
model.data.uv_layers.active=uv
uv.active_render=True
image=bpy.data.images.load(str(ROOT/'Tools/Assets/References/SmilingSpiderChitin.png'),check_existing=True)
image.pack()
for m in model.data.materials:
    nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    if m.name.startswith(('Oxblood','Raised carapace')):
        tex=nodes.new('ShaderNodeTexImage');tex.image=image
        coordinates=nodes.new('ShaderNodeUVMap');coordinates.uv_map='ChitinDetail'
        links.new(coordinates.outputs['UV'],tex.inputs['Vector'])
        for link in list(p.inputs['Base Color'].links):links.remove(link)
        links.new(tex.outputs['Color'],p.inputs['Base Color'])
        p.inputs['Roughness'].default_value=.48
        bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.42;bump.inputs['Distance'].default_value=.03
        links.new(tex.outputs['Color'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])
    elif m.name.startswith('Graphite'):
        for link in list(p.inputs['Base Color'].links):links.remove(link)
        p.inputs['Base Color'].default_value=(.006,.004,.003,1);p.inputs['Roughness'].default_value=.75
    elif m.name.startswith('Mouth recess'):
        p.inputs['Base Color'].default_value=(.0002,.0001,.0001,1);p.inputs['Roughness'].default_value=1
        p.inputs['Specular IOR Level'].default_value=0
    elif m.name.startswith('Dark crimson'):
        p.inputs['Roughness'].default_value=.47
    elif m.name.startswith('Black glass'):
        p.inputs['Roughness'].default_value=.22

# Re-key all motions with a continuous swing/stance walk and downward jaw opening.
legs=[]
for side,suf in [(-1,'L'),(1,'R')]:
    for i in range(4):
        names=[f'LegSegment{letter}_{suf}_{i+1:03d}' for letter in 'ABC']
        a,b,c=[arm.data.bones[n] for n in names]
        legs.append((names,a.head_local.copy(),b.head_local.copy(),c.head_local.copy(),c.tail_local.copy(),i,side))
arm.animation_data.action=None
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
source=(ROOT/'Tools/Assets/build_smiling_spider.py').read_text()
exec(source[source.index('# Quaternion keying'):source.index('# Export conventional')])
output=OUT/'smiling_spider.glb'
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);model.select_set(True);bpy.context.view_layer.objects.active=arm
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_animations=True,
    export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
    export_def_bones=True,export_skins=True,export_materials='EXPORT',export_vertex_color='MATERIAL',export_image_format='JPEG',export_image_quality=92)
exec(source[source.index('def material('):source.index('chitin=material(')])
exec(source[source.index('# Editable master and a real Eevee'):])
