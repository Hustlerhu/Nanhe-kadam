import {readFileSync,writeFileSync} from 'node:fs';
import {transform} from 'esbuild';
const files=['frontend/index.html','frontend/login.html','frontend/portal.html','frontend/style.css','frontend/public.js','frontend/login.js','frontend/portal.js','public/hero.jpg','public/about.jpg','public/logo.jpg','public/class1.jpg','public/class2.jpg','public/class3.jpg','public/class4.jpg','public/class5.jpg','public/class6.jpg','public/class7.jpg','public/class8.jpg','public/class9.jpg'];
const result={};for(const p of files){let text=readFileSync(p).toString(p.endsWith('.jpg')?'base64':'utf8');if(p.endsWith('.js'))text=(await transform(text,{minify:true,legalComments:'none',sourcemap:false,target:'es2022'})).code;result[p]=text}
writeFileSync('backend/src/assets.ts',`export const assets = ${JSON.stringify(result)} as const;\n`);
