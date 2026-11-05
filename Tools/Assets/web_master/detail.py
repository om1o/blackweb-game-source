# Original deterministic mesh authoring; prepend the strands() helper from blockout.py.
random.seed(51026)
for o in list(bpy.data.objects):
 if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
mat=bpy.data.materials['WebSilkRough'];p=mat.node_tree.nodes.get('Principled BSDF')
p.inputs['Base Color'].default_value=(.57,.585,.535,1);p.inputs['Roughness'].default_value=.84
mat.diffuse_color=(.57,.585,.535,1)

# Orb web: radial supports share an offset hub, with a broken spiral tied to them.
N=30
angles=[math.tau*i/N+.022*math.sin(i*2.7) for i in range(N)]
lengths=[.95+.10*math.sin(i*1.67)+.035*math.cos(i*4.3) for i in range(N)]
def radial_point(i,r):
 i=i%N;a=angles[i];scale=lengths[i]
 return Vector((-.075+r*1.08*scale*math.cos(a),.045*math.sin(a*2.2)*r*r,.035+r*.92*scale*math.sin(a)))
r=bpy.data.objects['WebRadialTorn'];supports=[];fine=[]
for i in range(N):
 end=1.16+.08*math.sin(i*2.1)
 supports.append([tuple(radial_point(i,end*j/7)) for j in range(8)])
# The cut-outs deliberately interrupt the spiral while retaining the radial frame.
for ring in range(1,19):
 line=[]
 for j in range(N+1):
  i=j%N;rr=(ring+(j/N)*.6)/20
  cut=(9<=i<=13 and ring>=10) or (23<=i<=25 and 5<=ring<=10)
  if cut:
   if len(line)>1:fine.append(line)
   line=[];continue
  v=radial_point(i,rr)
  v.y+=.0035*math.sin(j*4.5+ring)
  line.append(tuple(v))
 if len(line)>1:fine.append(line)
# Broken spiral ends sag under their last intact tie, rather than ending cleanly.
for i,ring in [(9,11),(13,13),(9,15),(13,17),(23,6),(25,9)]:
 p0=radial_point(i,ring/20);fine.append([tuple(p0),tuple(p0+Vector((.012,.018,-.045))),tuple(p0+Vector((.020,.032,-.105)))])
for k in range(14):
 i=random.randrange(N);a=radial_point(i,random.uniform(.80,1.08));b=radial_point(i+random.choice([-1,1]),random.uniform(.76,1.0))
 mid=(a+b)*.5+Vector((0,.014,-.017));fine.append([tuple(a),tuple(mid),tuple(b)])
strands('Radial_AnchorBundles',supports,r,.00135,3)
strands('Radial_TornSpiral',fine,r,.00085,3)

# Sheet web: individual tie lines cross a gravity-sagged surface at non-grid angles.
def canopy(u,v):
 z=-.51*(1-u*u)*(1-v*v)+.065*math.sin(3*u+2*v)*(1-u*u)+.025*math.sin(8*v)*(1-v*v)
 return Vector((1.35*u,.95*v,z))
def sheet_path(u0,v0,u1,v1,steps,phase=0):
 pts=[]
 for j in range(steps+1):
  t=j/steps;u=u0+(u1-u0)*t;v=v0+(v1-v0)*t
  v+=.018*math.sin(t*math.pi)*math.sin(7*t+phase)
  pt=canopy(u,v);pt.z-=.009*math.sin(t*math.pi);pts.append(tuple(pt))
 return pts
r=bpy.data.objects['WebSaggingCanopy'];supports=[];fine=[]
for i in range(13):
 v=-.98+1.96*i/12+.015*math.sin(i*3.7)
 supports.append(sheet_path(-1,v,1,max(-1,min(1,v+.18*math.sin(i*2))),20,i))
for i in range(11):
 u=-.98+1.96*i/10+.02*math.sin(i*2.7)
 supports.append(sheet_path(u,-1,max(-1,min(1,u+.22*math.cos(i*2))),1,18,i))
for i in range(33):
 v=random.uniform(-.95,.95);u=random.uniform(-.95,.95)
 if i%2:fine.append(sheet_path(-1,v,1,random.uniform(-.95,.95),18,i))
 else:fine.append(sheet_path(u,-1,random.uniform(-.95,.95),1,18,i))
# Local connecting fibres leave open tears, with density concentrated around low pockets.
for i in range(70):
 u=random.uniform(-.88,.88);v=random.uniform(-.86,.86)
 if (u-.35)**2+(v+.20)**2<.05:continue
 du=random.uniform(-.19,.19);dv=random.uniform(-.25,.25)
 fine.append(sheet_path(u,v,max(-1,min(1,u+du)),max(-1,min(1,v+dv)),3,i))
for i in range(8):
 a=canopy(-.9+i*.24,random.choice([-.96,.96]));fine.append([tuple(a),tuple(a+Vector((.018,0,-.10))),tuple(a+Vector((.028,.008,-.19-random.random()*.12)))])
strands('Canopy_LoadThreads',supports,r,.0014,3)
strands('Canopy_TangledSheet',fine,r,.00085,3)

# Cocoon: uneven wrapping passes follow a rounded, lopsided furniture volume.
def cocoon(a,h):
 ca=math.cos(a);sa=math.sin(a)
 taper=1-.19*max(0,(h-.45)/.55)
 x=.64*math.copysign(abs(ca)**.55,ca)*taper
 y=.45*math.copysign(abs(sa)**.55,sa)*taper+.065*h
 z=.045+h*.94+.028*math.sin(3*a+h*8)+.017*math.sin(7*a+h*5)
 return Vector((x,y,z))
r=bpy.data.objects['WebFurnitureCocoon'];supports=[];fine=[]
for i in range(20):
 h=.05+.90*i/19
 line=[]
 for j in range(37):
  a=math.tau*j/36;hh=h+.024*math.sin(a*2+i*.8)+.018*math.sin(a*5+i)
  line.append(tuple(cocoon(a,hh)))
 fine.append(line)
for i in range(12):
 a=math.tau*i/12;line=[]
 for j in range(15):
  h=j/14;line.append(tuple(cocoon(a+.22*math.sin(h*3+i),h)))
 supports.append(line)
# Diagonal binding crosses side faces and folds over the crown. Irregular negative space stays open.
for i in range(17):
 a=random.uniform(0,math.tau);h=random.uniform(.04,.85)
 fine.append([tuple(cocoon(a+.85*j/11,min(.98,h+.35*j/11))) for j in range(12)])
for i in range(12):
 a=math.tau*i/12;start=cocoon(a,.98);end=cocoon(a+math.pi,.97);line=[]
 for j in range(10):
  t=j/9;pt=start.lerp(end,t);pt.z-=.13*math.sin(math.pi*t);line.append(tuple(pt))
 fine.append(line)
for i in range(8):
 a=math.tau*i/8;pt=cocoon(a,.05)
 fine.append([tuple(pt),tuple(pt+Vector((.04*math.cos(a),.04*math.sin(a),-.025))),tuple(pt+Vector((.15*math.cos(a),.12*math.sin(a),-.07)))])
strands('Cocoon_AnchorThreads',supports,r,.00125,3)
strands('Cocoon_IrregularWrap',fine,r,.0009,3)

# Source scene is a reusable studio; runtime export removes studio nodes and resets root placement.
scene=bpy.context.scene
scene.render.resolution_x=1200;scene.render.resolution_y=700
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
result={'triangles':{},'material':'WebSilkRough'}
for o in scene.objects:
 if o.type=='MESH':
  o.data.calc_loop_triangles();result['triangles'][o.name]=len(o.data.loop_triangles)
result['total_triangles']=sum(result['triangles'].values())
