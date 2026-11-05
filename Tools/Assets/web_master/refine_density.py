# Prepend imports plus strands() from blockout.py. Keep only two mesh surfaces per variant.
random.seed(51126)
def merge_into(target, extra):
 a=bpy.data.objects[target];old=a.data
 verts=[tuple(v.co) for v in old.vertices]+[tuple(v.co) for v in extra.data.vertices]
 offset=len(old.vertices);faces=[tuple(p.vertices) for p in old.polygons]+[tuple(offset+i for i in p.vertices) for p in extra.data.polygons]
 mesh=bpy.data.meshes.new(target+'DetailedMesh');mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(mat)
 for p in mesh.polygons:p.use_smooth=True
 a.data=mesh;bpy.data.objects.remove(extra,do_unlink=True)
 if old.users==0:bpy.data.meshes.remove(old)

def canopy(u,v):
 return Vector((1.35*u,.95*v,-.51*(1-u*u)*(1-v*v)+.065*math.sin(3*u+2*v)*(1-u*u)+.025*math.sin(8*v)*(1-v*v)))
paths=[]
for i in range(90):
 centre=random.choice([(-.45,-.25),(-.12,.35),(.50,.42)])
 u=centre[0]+random.uniform(-.28,.28);v=centre[1]+random.uniform(-.28,.28)
 du=random.uniform(-.32,.32);dv=random.uniform(-.40,.40)
 paths.append([tuple(canopy(max(-.98,min(.98,u+du*j/4)),max(-.98,min(.98,v+dv*j/4)))) for j in range(5)])
extra=strands('Canopy_ClusterTemp',paths,bpy.data.objects['WebSaggingCanopy'],.00065,3)
merge_into('Canopy_TangledSheet',extra)

def cocoon(a,h):
 ca=math.cos(a);sa=math.sin(a);taper=1-.19*max(0,(h-.45)/.55)
 return Vector((.64*math.copysign(abs(ca)**.55,ca)*taper,.45*math.copysign(abs(sa)**.55,sa)*taper+.065*h,.045+h*.94+.028*math.sin(3*a+h*8)+.017*math.sin(7*a+h*5)))
paths=[]
for i in range(100):
 a=random.uniform(0,math.tau);h=random.uniform(.07,.92)
 da=random.uniform(-.95,.95);dh=random.uniform(-.31,.31)
 paths.append([tuple(cocoon(a+da*j/4,max(.025,min(.99,h+dh*j/4)))) for j in range(5)])
extra=strands('Cocoon_ClusterTemp',paths,bpy.data.objects['WebFurnitureCocoon'],.00065,3)
merge_into('Cocoon_IrregularWrap',extra)
result={'triangles':{}}
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.calc_loop_triangles();result['triangles'][o.name]=len(o.data.loop_triangles)
result['total_triangles']=sum(result['triangles'].values())
