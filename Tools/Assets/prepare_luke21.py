"""Build Luke's custom age-21 design on the validated Rocketbox rig.

Blender --background --python this.py -- BODY_SOURCE HEAD_SOURCE HAIR_SOURCE OUTPUT_GLB [REFINED_HEAD]
Pass Tools/Assets/References/luke21_head_albedo.png as REFINED_HEAD for the final design.
Inputs: MIT Microsoft Rocketbox Male_Adult_02 and Male_Adult_12 folders.
All bone transforms remain the same as the validated gameplay rig. Only visible
geometry, material assignment and the authored short curl mesh change.
"""
import bpy, bmesh, sys, math, json, hashlib
from pathlib import Path
from mathutils import Vector

arguments=sys.argv[sys.argv.index('--')+1:]
body_dir,head_dir,hair_dir,output=map(Path,arguments[:4])
refined_head=Path(arguments[4]) if len(arguments)>4 else None
scratch=output.parent
scratch.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def load_character(folder,name):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(folder/f'{name}.fbx'),use_anim=False)
    imported=set(bpy.data.objects)-before
    rig=next(o for o in imported if o.type=='ARMATURE')
    mesh=next(o for o in imported if o.type=='MESH' and 'hipoly' in o.name.lower())
    for o in imported:
        if o!=mesh and o!=rig: bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return rig,mesh

rig,body=load_character(body_dir,'Male_Adult_02')
head_rig,head=load_character(head_dir,'Male_Adult_12')
rest_error=max((rig.data.bones[b.name].matrix_local.translation-b.matrix_local.translation).length
               for b in head_rig.data.bones if b.name in rig.data.bones)
assert rest_error < 0.00001,rest_error

def keep_materials(obj,keyword):
    bm=bmesh.new();bm.from_mesh(obj.data)
    unwanted=[f for f in bm.faces if keyword not in obj.material_slots[f.material_index].name.lower()]
    bmesh.ops.delete(bm,geom=unwanted,context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(obj.data);bm.free()
keep_materials(body,'body');keep_materials(head,'head')

# Shape the fictional young adult's face. Localised, symmetric deformations are
# deliberately modest; neck attachment and eye positions remain compatible.
def bell(value,center,width):return math.exp(-((value-center)/width)**2)
for v in head.data.vertices:
    x,y,z=v.co
    front=bell(y,-.105,.060)
    jaw=bell(z,1.611,.045)*front
    cheek=bell(z,1.687,.036)*front
    # A less square lower face and a little more youthful cheek volume.
    v.co.x *= 1-.065*jaw+.035*cheek
    v.co.y -= .0035*cheek*bell(abs(x),.047,.027)
    # Shorten the chin slightly and soften the brow ridge.
    v.co.z += .003*bell(z,1.597,.022)*front
    v.co.y += .0025*bell(z,1.723,.019)*front
head.data.update()

def texture_material(name,folder,prefix,tint,roughness):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    ns=mat.node_tree.nodes;ns.clear()
    bs=ns.new('ShaderNodeBsdfPrincipled');out=ns.new('ShaderNodeOutputMaterial')
    mat.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    bs.inputs['Roughness'].default_value=roughness
    bs.inputs['Specular IOR Level'].default_value=.28
    for kind in ['color','normal']:
        path=folder/f'{prefix}_{kind}.tga'
        if prefix=='m007_head' and kind=='color' and refined_head:path=refined_head
        if not path.exists():continue
        img=bpy.data.images.load(str(path),check_existing=False);img.scale(1024,1024)
        img.file_format='JPEG';img.filepath_raw=str(scratch/f'{prefix}_{kind}.jpg');img.save()
        tex=ns.new('ShaderNodeTexImage');tex.image=img
        if kind=='color':
            bs.inputs['Base Color'].default_value=(*tint,1)
            mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
            # The multiplier is applied as glTF material factor below, retaining
            # authored texture pixels and avoiding a whole-face flat skin colour.
            mat['albedo_factor']=list(tint)
        else:
            img.colorspace_settings.name='Non-Color';normal=ns.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value=.18 if 'head' in prefix else .75
            mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    return mat

body_mat=texture_material('Luke21_Clothes',body_dir,'m003_body',(.12,.15,.12),.86)
hand_mat=texture_material('Luke21_Hands',body_dir,'m003_body',(.58,.44,.34),.71)
head_mat=texture_material('Luke21_Head',head_dir,'m007_head',(1.16,1.12,1.04),.68)
body.data.materials.clear();body.data.materials.append(body_mat);body.data.materials.append(hand_mat)
for p in body.data.polygons:
    # The two hand islands occupy the bottom corners of this authored atlas.
    # A world-coordinate split also selects folded cuffs, making beige patches.
    uv=sum((body.data.uv_layers.active.data[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
    p.material_index=1 if uv.y<.168 and (uv.x<.25 or uv.x>.75) else 0
head.data.materials.clear();head.data.materials.append(head_mat)
for p in head.data.polygons:p.material_index=0

# Fit MakeHuman's CC0 afro01 cards as a short crop. The artist-authored cards
# contain curly strand texture and cost only 2,192 triangles, with no particles.
before=set(bpy.data.objects)
bpy.ops.wm.obj_import(filepath=str(hair_dir/'afro01.obj'),forward_axis='NEGATIVE_Z',up_axis='Y')
hair=next(o for o in set(bpy.data.objects)-before if o.type=='MESH')
bpy.context.view_layer.objects.active=hair
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for v in hair.data.vertices:
    x,y,z=v.co
    height=(z-6.6145)*.071+1.661
    # Narrow the high crown and front corners into a rounded short crop.
    crown=bell(height,1.802,.040)
    front=bell(y,-1.12,.55)
    v.co=(x*.089*(1-.12*crown-.035*front),y*.087+.015,height-.008*bell(abs(x),.85,.30)*crown)
hair.name='Luke21ShortCurls'
hairmat=bpy.data.materials.new('Luke21_Curls');hairmat.use_nodes=True
bs=hairmat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1.0
bs.inputs['Specular IOR Level'].default_value=.03
hair_image=bpy.data.images.load(str(hair_dir/'afro_diffuse.png'));hair_image.scale(1024,1024)
hair_image.file_format='PNG';hair_image.filepath_raw=str(scratch/'luke21_curls.png');hair_image.save()
tex=hairmat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=hair_image
hairmat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
hairmat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
hairmat.surface_render_method='DITHERED'
hair.data.materials.clear();hair.data.materials.append(hairmat)
group=hair.vertex_groups.new(name='Bip01 Head');group.add(list(range(len(hair.data.vertices))),1,'REPLACE')
for p in hair.data.polygons:p.use_smooth=True
hair_vertices=len(hair.data.vertices);hair_triangles=sum(len(p.vertices)-2 for p in hair.data.polygons)

for obj in [head,hair]:
    obj.parent=rig
    for mod in obj.modifiers:
        if mod.type=='ARMATURE':mod.object=rig
    if not any(m.type=='ARMATURE' for m in obj.modifiers):obj.modifiers.new('Armature','ARMATURE').object=rig
bpy.data.objects.remove(head_rig,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in [body,head,hair]:
    # FBX and OBJ importers name UV sets differently. Joining without unifying
    # them leaves the hair material sampling the body's empty primary UV set.
    if obj.data.uv_layers.active:obj.data.uv_layers.active.name='BlackwebUV'
    obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
body.name='Luke21_hipoly';body.data.name='Luke21_CharacterMesh'
for p in body.data.polygons:p.use_smooth=True
rig.name='Bip01'
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_animations=False,export_image_format='AUTO',export_materials='EXPORT')

# Patch only glTF material factors; image data, authored UVs and skin weights stay
# untouched. Blender's exporter does not retain a disconnected shader multiplier.
import struct
raw=output.read_bytes();json_size=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+json_size])
factors={'Luke21_Clothes':[.12,.15,.12,1],'Luke21_Hands':[.58,.44,.34,1],'Luke21_Head':[1.0,.96,.89,1]}
for mat in gltf.get('materials',[]):
    if mat.get('name') in factors:mat['pbrMetallicRoughness']['baseColorFactor']=factors[mat['name']]
payload=json.dumps(gltf,separators=(',',':')).encode();payload+=b' '*((-len(payload))%4)
tail=raw[20+json_size:];output.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(payload)+len(tail))+struct.pack('<I4s',len(payload),b'JSON')+payload+tail)
bpy.ops.wm.save_as_mainfile(filepath=str(scratch/'luke21-preview.blend'))
report={'model':str(output),'vertices':len(body.data.vertices),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'hair_vertices':hair_vertices,'hair_triangles':hair_triangles,'bones':len(rig.data.bones),'max_source_rest_difference_m':rest_error,'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
(scratch/'build-report.json').write_text(json.dumps(report,indent=2))
print('LUKE21_READY',json.dumps(report),flush=True)
