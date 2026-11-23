// Generate a destructive clean reset from a fresh sqlite_schema inventory.
import {readFileSync,writeFileSync} from 'node:fs';
const [schemaPath,fkPath,outPath]=process.argv.slice(2);const schema=JSON.parse(readFileSync(schemaPath,'utf8'))[0].results;const fk=JSON.parse(readFileSync(fkPath,'utf8'))[0].results;const quote=s=>'"'+s.replaceAll('"','""')+'"';
const views=schema.filter(x=>x.type==='view');let tables=schema.filter(x=>x.type==='table').map(x=>x.name);const order=[];
// A child is removed before its parent. For cycles, prefer media, then any remaining node;
// defer_foreign_keys plus deleting rows before drops handles normal self/cyclic references.
while(tables.length){let leaf=tables.find(t=>!fk.some(x=>x.parent===t&&x.child!==t&&tables.includes(x.child)));if(!leaf)leaf=tables.includes('media')?'media':tables[0];order.push(leaf);tables=tables.filter(t=>t!==leaf)}
let sql='PRAGMA defer_foreign_keys = ON;\n'+views.map(x=>`DROP VIEW IF EXISTS ${quote(x.name)};`).join('\n')+'\n'+order.map(x=>`DELETE FROM ${quote(x)};`).join('\n')+'\n'+order.map(x=>`DROP TABLE IF EXISTS ${quote(x)};`).join('\n')+'\n'+readFileSync('migrations/0001_reset.sql','utf8');writeFileSync(outPath,sql);
console.log('Reset will remove:',order.join(', ')||'(no user tables)',views.map(x=>x.name).join(', '));
