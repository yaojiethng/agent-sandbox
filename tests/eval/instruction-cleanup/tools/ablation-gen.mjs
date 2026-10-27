import fs from 'node:fs';
const SRC='workflow/coding-agent/prompts/instruction-cleanup.md';
const src=fs.readFileSync(SRC,'utf8');
const lines=src.split('\n');
// section boundaries: every '## ' heading
const idx=[]; lines.forEach((l,i)=>{ if(/^## /.test(l)) idx.push(i); });
const head=lines.slice(0,idx[0]).join('\n');       // frontmatter, title, $ARGUMENTS, scope
const secs=idx.map((s,k)=>({title:lines[s].replace(/^## /,'').trim(), body:lines.slice(s, k+1<idx.length?idx[k+1]:lines.length).join('\n')}));
if(secs.length!==12) throw new Error('expected 12 sections, got '+secs.length);
const slug=t=>t.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
fs.writeFileSync('.scratchpad/ablation/prompts/baseline.md',src);
for(const s of secs){
  const kept=lines.slice(0,idx[0]).concat(...secs.filter(x=>x!==s).map(x=>x.body.split('\n')));
  fs.writeFileSync(`.scratchpad/ablation/prompts/abl-${slug(s.title)}.md`,kept.join('\n'));
}
const configs=['baseline',...secs.map(s=>'abl-'+slug(s.title))];
const carriers={kelsey:'.agents/audits/kelsey-code-reviewer.skill.md',
  tqc:'.agents/audits/test-quality-campaign.md',
  bashaudit:'.agents/audits/bash-audit.skill.md'};
const pre=(path)=>`# Instruction-cleanup ablation, one pass over one carrier

You are running one instruction-cleanup pass over a single file, then stopping. The procedure follows this preamble in full; read it as your instructions.

## The surface

One file, in the repository at /home/agentuser/sandbox: \`${path}\`. Read it before judging anything.

## What to produce

Return, in chat and in no other place, only the faults you raised. For each one, four lines:

- \`rule\`: the sentence or rule as the file states it, quoted.
- \`site\`: \`path:line\`.
- \`fault\`: one of harmful, redundant, ambiguous wording, ambiguous procedure -- or a fault of your own naming, with the justification for it.
- \`recommendation\`: either \`removal - <reason>\`, or replacement text quoted from a site that already states it, or your own text marked as yours.

## What you must not do

Stop after the judgement. Do not screen: the screen needs the operator and is not part of this run. Do not fold, do not edit any file, do not run any prompt, and do not write a record. This run produces a fault list and nothing else.

## Attribution

Role \`_REVIEWER\`, thinking level \`high\`. The assignment is pinned by the runner to \`opencode/deepseek-v4.1-flash-free\`, served through \`opencode run\` with \`--variant high\`, so that every cell of this grid reads one model through one backend. State the role and the thinking level in your first line of output.

---

# The procedure

`;
for(const c of configs) for(const [name,path] of Object.entries(carriers)){
  const proc=fs.readFileSync(`.scratchpad/ablation/prompts/${c}.md`,'utf8');
  fs.writeFileSync(`.scratchpad/ablation/briefs/${c}__${name}.md`,pre(path)+proc);
}
const plan=[];
for(const rep of [1,2,3]) for(const carrier of ['kelsey','tqc','bashaudit']) for(const c of configs) plan.push([rep,carrier,c].join('\t'));
fs.writeFileSync('.scratchpad/ablation/plan.tsv',plan.join('\n')+'\n');
console.log('configs',configs.length,'briefs',fs.readdirSync('.scratchpad/ablation/briefs').length,'plan',plan.length);
console.log(configs.join('\n'));
