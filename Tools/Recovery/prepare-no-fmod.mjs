// Modified source build: omit FMOD bank decoding entirely. No security settings or blocked binaries are changed.
import fs from 'node:fs/promises';
import path from 'node:path';
const source=path.resolve(process.argv[2] || "D:/CodexTemp/Arachnophobia-Blackweb-20261103/work/cue4parse-source/CUE4Parse-e76778c10ed25860e11ec488750753224d067d87");
const core=path.join(source,'CUE4Parse','CUE4Parse.csproj');
let xml=await fs.readFile(core,'utf8');
if(!xml.includes('Blackweb: omit optional FMOD')) {
 if(!xml.includes('<PackageReference Include="Fmod5Sharp" />')) throw new Error('Pinned source dependency not found');
 xml=xml.replace('    <PackageReference Include="Fmod5Sharp" />\n','');
 xml=xml.replace('</Project>','  <!-- Blackweb: omit optional FMOD bank decoding; no blocked library is used. -->\n  <ItemGroup>\n    <Compile Remove="UE4/FMod/**/*.cs" />\n    <Compile Remove="UE4/Assets/Exports/FMod/**/*.cs" />\n  </ItemGroup>\n</Project>');
 await fs.writeFile(core,xml);
}
const converters=path.join(source,'CUE4Parse','JsonConverters.cs');
let code=await fs.readFile(converters,'utf8');
if(!code.includes('Blackweb: FMOD converters omitted')) {
 code=code.replace(/^using (?:CUE4Parse\.UE4\.FMod(?:\.Objects)?|Fmod5Sharp\.FmodTypes);\r?\n/gm,'');
 const start=code.indexOf('public class FModConverter :');
 const end=code.indexOf('public class AcbReaderConverter :',start);
 if(start<0 || end<start) throw new Error('Pinned FMOD converter boundaries missing');
 code=code.slice(0,start)+'// Blackweb: FMOD converters omitted together with optional audio implementation.\n\n'+code.slice(end);
 await fs.writeFile(converters,code);
}
console.log('Optional FMOD source and reference excluded. ObjectTypeRegistry and all non-FMOD code unchanged.');

// NAudio.Core is an independent dependency needed by retained CriWare/HCA code; it was previously transitive through FMOD.
let coreXml2=await fs.readFile(core,'utf8');
if(!coreXml2.includes('Include="NAudio.Core"')) await fs.writeFile(core,coreXml2.replace('<PackageReference Include="GenericReader" />','<PackageReference Include="GenericReader" />\n    <PackageReference Include="NAudio.Core" />'));
const pkg=path.join(source,'Directory.Packages.props');
let pkgXml=await fs.readFile(pkg,'utf8');
if(!pkgXml.includes('Include="NAudio.Core"')) await fs.writeFile(pkg,pkgXml.replace('<PackageVersion Include="Newtonsoft.Json"','<PackageVersion Include="NAudio.Core" Version="2.2.1" />\n    <PackageVersion Include="Newtonsoft.Json"'));
