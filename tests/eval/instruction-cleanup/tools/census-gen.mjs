import fs from 'node:fs';
const old='The assignment is resolved by the runner: the role line names `opencode/deepseek-v4.1-flash-free` first and `deepseek/deepseek-flash` second.';
const pin='The assignment is pinned by the runner to `deepseek/deepseek-flash` at thinking level `high`, so that both arms of this comparison run on one model and a difference between their reports cannot be a difference of model.';
const carriers={
  kelsey:'.agents/audits/kelsey-code-reviewer.skill.md',
  archdoc:'.agents/audits/architecture-doc-reviewer.skill.md',
  dhh:'.agents/audits/dhh-code-audit.skill.md',
  bashaudit:'.agents/audits/bash-audit.skill.md',
  tqc:'.agents/audits/test-quality-campaign.md',
  tasb:'.agents/audits/test-assertion-sweep-brief.md',
};
for (const arm of ['a','b']) {
  let t=fs.readFileSync(`.scratchpad/cmp/brief-${arm}.md`,'utf8');
  if (t.split(old).length-1!==1) throw new Error('attribution sentence not found in arm '+arm);
  t=t.replace(old,pin);
  for (const [name,path] of Object.entries(carriers)) {
    const surface=`One file, in the repository at /home/agentuser/sandbox: \`.agents/audits/kelsey-code-reviewer.skill.md\`. Read it before judging anything.`;
    if(t.split(surface).length-1!==1) throw new Error('surface line not found');
    const out=t.replace(surface,`One file, in the repository at /home/agentuser/sandbox: \`${path}\`. Read it before judging anything.`);
    fs.writeFileSync(`.scratchpad/census/briefs/${arm}-${name}.md`,out);
  }
}
console.log('briefs:', fs.readdirSync('.scratchpad/census/briefs').length);
