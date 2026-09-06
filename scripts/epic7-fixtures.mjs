// Synthetic local test content; not production seeds or approved lesson media.
export const id = n => `97000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
export const admin = id(1), studentA=id(2), studentB=id(3), teacher=id(4), creator=id(5), superAdmin=id(6);
export const course=id(10), map=id(11), version=id(12), version2=id(13);
export const quote = value => `'${String(value).replaceAll("'","''")}'`;
export const json = value => `${quote(JSON.stringify(value))}::jsonb`;
export const auth = (actor,body) => `begin;set local role authenticated;select set_config('request.jwt.claim.sub',${quote(actor)},true);set local statement_timeout='15s';${body};commit;`;
export const structure = {
  levels:[
    {id:id(20),slug:'level-1',position:1,title:'我可以把一首歌完整彈完'},
    {id:id(21),slug:'level-2',position:2,title:'我的伴奏不再只有一種'}],
  modules:[
    {id:id(30),slug:'steady-rhythm',stage_id:id(20),position:1,title:'穩定節奏'},
    {id:id(31),slug:'whole-song',stage_id:id(20),position:2,title:'完整歌曲'},
    {id:id(32),slug:'accompaniment-change',stage_id:id(21),position:1,title:'伴奏變化'}],
  nodes:[
    {id:id(40),slug:'pulse',module_id:id(30),position:1,title:'保持穩定拍點',guidance:'Learn: 四拍。Practice: 拍手四小節。Apply: 跟著節拍器。Verify: 自我檢查不中斷。'},
    {id:id(41),slug:'chord-change',module_id:id(30),position:2,title:'不中斷換和弦',guidance:'Learn: 換和弦。Practice: 慢速四小節。Apply: 兩和弦段落。Verify: 自我檢查。'},
    {id:id(42),slug:'complete-song',module_id:id(31),position:1,title:'完整彈奏一首歌',guidance:'Learn: 歌曲段落。Practice: 接段。Apply: 完整歌曲。Verify: 對照標準；此內容不授予正式成果。'},
    {id:id(43),slug:'vary-accompaniment',module_id:id(32),position:1,title:'嘗試第二種伴奏',guidance:'代表性的下一 Level 樣本。'}]
};
export const content = {
  resources:structure.nodes.map((n,k)=>({id:id(100+k),slug:`guide-${k}`,revision_id:id(110+k),kind:'text',title:n.title,content:n.guidance})),
  links:structure.nodes.map((n,k)=>({id:id(120+k),node_id:n.id,resource_revision_id:id(110+k),position:1,purpose:'learn-practice-apply-self-check'})),
  objectives:structure.nodes.map((n,k)=>({id:id(130+k),node_id:n.id,objective:`能展示：${n.title}`})),
  skills:[{id:id(140),code:'steady-pulse',definition:'在指定段落保持均勻拍點'}],
  mappings:[{objective_id:id(130),skill_id:id(140)},{objective_id:id(131),skill_id:id(140)}],
  prerequisites:[{dependent_node_id:id(41),prerequisite_node_id:id(40),rationale:'建議先穩定拍點；不是 access gate。'}],
  contributors:[{id:id(150),display_credit:'Synthetic Teacher',auth_user_id:teacher},{id:id(151),display_credit:'Synthetic Creator',auth_user_id:creator}],
  credits:[{id:id(160),contributor_id:id(150),resource_revision_id:id(110),contribution:'author',position:1},{id:id(161),contributor_id:id(151),resource_revision_id:id(110),contribution:'editor',position:2}],
  capabilities:[{id:id(170),node_id:id(42),code:'async_review',description:'Future support only; no entitlement or workflow'}]
};
content.resources.push({id:id(104),slug:'rhythm-audio',revision_id:id(114),kind:'audio',title:'Synthetic rhythm reference',content:'Local fixture metadata only',provider_ref:'fixture:rhythm-audio-v1'});
content.links.push({id:id(124),node_id:id(40),resource_revision_id:id(114),position:2,purpose:'practice-reference'});
export const setupUsers = `insert into auth.users(id,email) values ${[admin,studentA,studentB,teacher,creator,superAdmin].map((a,k)=>`(${quote(a)},'epic7-local-${k}@example.invalid')`).join(',')};
 insert into public.user_roles(user_id,role) values(${quote(admin)},'admin'),(${quote(teacher)},'teacher'),(${quote(superAdmin)},'super_admin');`;
export const setupCourse = `select public.learning_create_course(${quote(course)},'guitar-roadmap-fixture','Guitar Roadmap fixture',${quote(map)},'main');
 select public.learning_create_draft(${quote(map)},${quote(version)});
 select public.learning_put_structure(${quote(version)},0,${quote(id(200))},${json(structure)});`;
