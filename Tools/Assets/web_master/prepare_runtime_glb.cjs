// Strip only studio nodes from the authorized hosted-Blender export. Mesh buffers stay untouched.
const fs = require('fs');
const path = require('path');
const base = __dirname;
const input = fs.readFileSync(path.join(base, 'web_masters_studio.glb'));
if (input.readUInt32LE(0) !== 0x46546c67 || input.readUInt32LE(4) !== 2) throw Error('Expected glTF 2 GLB');
const chunks = [];
for (let p = 12; p < input.length;) {
 const len = input.readUInt32LE(p), type = input.readUInt32LE(p + 4);
 chunks.push({type, body:input.subarray(p + 8, p + 8 + len)}); p += 8 + len;
}
const doc = JSON.parse(chunks.find(c=>c.type===0x4e4f534a).body.toString('utf8').trim());
const names = ['WebRadialTorn','WebSaggingCanopy','WebFurnitureCocoon'];
const roots = names.map(name=>doc.nodes.findIndex(n=>n.name===name));
if (roots.some(i=>i<0)) throw Error('Missing named web root');
const kept = [];
function visit(i) { if (kept.includes(i)) return; kept.push(i); for(const c of doc.nodes[i].children||[]) visit(c); }
roots.forEach(visit);
const map = new Map(kept.map((old,i)=>[old,i]));
doc.nodes = kept.map(old=>{
 const n = structuredClone(doc.nodes[old]);
 if (n.children) n.children=n.children.map(i=>map.get(i));
 if (roots.includes(old)) { delete n.translation; delete n.rotation; delete n.scale; delete n.matrix; }
 delete n.camera;
 if (n.extensions) { delete n.extensions.KHR_lights_punctual; if (!Object.keys(n.extensions).length) delete n.extensions; }
 return n;
});
doc.scenes = [{name:'OriginalWebMasters',nodes:roots.map(i=>map.get(i))}]; doc.scene=0;
delete doc.cameras;
if(doc.extensions) {delete doc.extensions.KHR_lights_punctual;if(!Object.keys(doc.extensions).length)delete doc.extensions;}
for(const key of ['extensionsUsed','extensionsRequired']) if(doc[key]) {doc[key]=doc[key].filter(v=>v!=='KHR_lights_punctual');if(!doc[key].length)delete doc[key];}
doc.asset.extras={...(doc.asset.extras||{}),source:'Original deterministic procedural mesh authored for Blackweb in Higgsfield hosted Blender 5.2',projectId:'d27bc245-6bad-46df-b021-f465408ffe17',revision:3,studioNodesRemoved:true};
const json = Buffer.from(JSON.stringify(doc),'utf8');
const padded = Buffer.alloc(Math.ceil(json.length/4)*4,0x20);json.copy(padded);
const outputChunks = [{type:0x4e4f534a,body:padded},...chunks.filter(c=>c.type!==0x4e4f534a)];
const total = 12+outputChunks.reduce((a,c)=>a+8+c.body.length,0);
const out=Buffer.alloc(total);out.writeUInt32LE(0x46546c67,0);out.writeUInt32LE(2,4);out.writeUInt32LE(total,8);
let offset=12;
for(const c of outputChunks) {out.writeUInt32LE(c.body.length,offset);out.writeUInt32LE(c.type,offset+4);c.body.copy(out,offset+8);offset+=8+c.body.length;}
const target=path.resolve(base,'../../../Godot/assets/generated/web_master/web_masters.glb');
fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,out);
const report={roots:names,nodes:doc.nodes.map(n=>n.name),materials:doc.materials,bytes:out.length,meshBuffersUnchanged:true};
fs.writeFileSync(path.join(base,'runtime_export.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({target,bytes:out.length,roots:names,meshCount:doc.meshes.length,materialCount:doc.materials.length}));
