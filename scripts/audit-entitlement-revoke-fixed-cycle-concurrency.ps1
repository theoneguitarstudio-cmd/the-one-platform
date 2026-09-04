# LOCAL-only true multi-session audit for P1-6C Fixed Cycle revoke consistency.
[CmdletBinding()]param([ValidatePattern('^supabase_db_[A-Za-z0-9_-]+$')][string]$ContainerName)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$docker=(Get-Command docker -ErrorAction Stop).Source
if(-not $ContainerName){
  $names=@(& $docker --host 'npipe:////./pipe/docker_engine' ps --format '{{.Names}}' |
    Where-Object{$_ -like 'supabase_db_*'})
  if($names.Count-ne 1){throw "Expected one local Supabase DB container; found $($names.Count)."}
  $ContainerName=$names[0]
}
function Invoke-Db([string]$Sql){
  $out=& $docker --host 'npipe:////./pipe/docker_engine' exec $ContainerName psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -At -c $Sql 2>&1 | Out-String
  [pscustomobject]@{ExitCode=$LASTEXITCODE;Output=$out.Trim()}
}
function Start-Db([string]$Sql){
  $i=[Diagnostics.ProcessStartInfo]::new();$i.FileName=$docker
  $i.Arguments="--host npipe:////./pipe/docker_engine exec -i $ContainerName psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -At"
  $i.UseShellExecute=$false;$i.RedirectStandardInput=$true;$i.RedirectStandardOutput=$true;$i.RedirectStandardError=$true
  $p=[Diagnostics.Process]::new();$p.StartInfo=$i;[void]$p.Start();$p.StandardInput.Write($Sql);$p.StandardInput.Close();$p
}
function Wait-Db($Process){
  $o=$Process.StandardOutput.ReadToEndAsync();$e=$Process.StandardError.ReadToEndAsync()
  if(-not $Process.WaitForExit(30000)){$Process.Kill();throw 'DB session timeout'}
  [pscustomobject]@{ExitCode=$Process.ExitCode;Output=(($o.Result+[Environment]::NewLine+$e.Result).Trim())}
}
function Race([string[]]$Sql){$ps=@($Sql|ForEach-Object{Start-Db $_});@($ps|ForEach-Object{Wait-Db $_})}
function Auth([string]$User,[string]$Body){"begin;set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','$User',true);set local statement_timeout='15s';$Body commit;"}
function Must($Result,[string]$Name){if($Result.ExitCode-ne 0){throw "$Name failed: $($Result.Output)"}}
function Scalar([string]$Sql){$r=Invoke-Db $Sql;Must $r 'scalar query';($r.Output-split'[\r\n]+')[-1]}
function Inspect($Results){foreach($r in $Results){if($r.Output-match'ERROR:\s+40P01'){$script:stats.Deadlock++};if($r.Output-match'ERROR:\s+23505'){$script:stats.UniqueViolation++};if($r.Output-match'ERROR:\s+23P01'){$script:stats.ExclusionViolation++};if($r.Output-match'ERROR:\s+P0001'){$script:stats.Domain++};if($r.Output-match'ERROR:\s+23[0-9A-Z]{3}'-and$r.Output-notmatch'ERROR:\s+(23505|23P01)'){$script:stats.UnexpectedIntegrity++}}}
function Assert-NoLeak($Results,[string]$Name){if(@($Results|Where-Object{$_.ExitCode-ne 0-and$_.Output-notmatch'ERROR:\s+P0001'}).Count-ne 0){throw "$Name leaked non-domain error: $($Results.Output-join' | ')"}}

$stats=[ordered]@{Deadlock=0;UniqueViolation=0;ExclusionViolation=0;UnexpectedIntegrity=0;Domain=0;Partial=0}
$student='7f000000-0000-0000-0000-000000000001';$teacher='7f000000-0000-0000-0000-000000000002';$admin='7f000000-0000-0000-0000-000000000003'
$relationship='7f000000-0000-0000-0000-000000000010';$product='7f000000-0000-0000-0000-000000000020'
$ents=@('7f000000-0000-0000-0000-000000000030','7f000000-0000-0000-0000-000000000031','7f000000-0000-0000-0000-000000000032')
$series=@('7f000000-0000-0000-0000-000000000040','7f000000-0000-0000-0000-000000000041','7f000000-0000-0000-0000-000000000042')
$cycles=@('7f000000-0000-0000-0000-000000000050','7f000000-0000-0000-0000-000000000051')
$orders=@('7f000000-0000-0000-0000-000000000060','7f000000-0000-0000-0000-000000000061','7f000000-0000-0000-0000-000000000062')
$items=@('7f000000-0000-0000-0000-000000000070','7f000000-0000-0000-0000-000000000071','7f000000-0000-0000-0000-000000000072')
$events=@('7f000000-0000-0000-0000-000000000080','7f000000-0000-0000-0000-000000000081','7f000000-0000-0000-0000-000000000082')
$cleanup="begin;set local session_replication_role='replica';delete from public.audit_logs where actor_user_id in('$student','$teacher','$admin');delete from public.fixed_entitlement_cycles where student_user_id='$student';delete from public.recurring_lesson_occurrences where student_user_id='$student';delete from public.recurring_lesson_series where student_user_id='$student';delete from public.lesson_credit_ledger where beneficiary_user_id='$student';delete from public.entitlements where beneficiary_user_id='$student';delete from public.order_item_fulfillment_snapshots where order_item_id in('$($items[0])','$($items[1])','$($items[2])');delete from public.order_fulfillment_events where order_id in('$($orders[0])','$($orders[1])','$($orders[2])');delete from public.order_items where order_id in('$($orders[0])','$($orders[1])','$($orders[2])');delete from public.orders where id in('$($orders[0])','$($orders[1])','$($orders[2])');delete from public.lesson_package_product_configs where product_id='$product';delete from public.products where id='$product';delete from public.teacher_scheduling_settings where teacher_user_id='$teacher';delete from public.student_teacher_relationships where id='$relationship';delete from public.teacher_public_profiles where public_slug='p16c-race-teacher';delete from public.teacher_profiles where user_id='$teacher';delete from public.public_profiles where user_id in('$student','$teacher','$admin');delete from public.user_roles where user_id in('$student','$teacher','$admin');delete from public.profiles where user_id in('$student','$teacher','$admin');delete from auth.users where id in('$student','$teacher','$admin');commit;"
$setup=$cleanup+"insert into auth.users(id,email)values('$student','p16c-race-student@example.invalid'),('$teacher','p16c-race-teacher@example.invalid'),('$admin','p16c-race-admin@example.invalid');insert into public.user_roles(user_id,role)values('$teacher','teacher'),('$admin','admin');insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd)values('$teacher','p16c-race-teacher','P1-6C race','active',true,array['online']::public.teaching_mode[],500);insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)values('$relationship','$student','$teacher','active','online');insert into public.teacher_scheduling_settings(teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes)values('$teacher','UTC',0,90,10);insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,is_public,is_purchasable,published_at)values('$product','lesson_package','active','p16c-race-product','P1-6C Race Product','TWD',1000,'platform',false,false,now());insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,booking_mode_eligibility)values('$product',1,6,'months',50,'fixed');"
for($i=0;$i-lt 3;$i++){
  $setup+="insert into public.orders(id,order_number,buyer_user_id,status,currency,subtotal_amount,total_amount,payment_status,source,idempotency_key,paid_at)values('$($orders[$i])','ONE-20260904-P16C00000$i','$student','paid','TWD',1000,1000,'paid','admin','p16c-race-order-000$i',now());insert into public.order_items(id,order_id,product_id,product_type_snapshot,product_name_snapshot,unit_price_amount,quantity,line_subtotal_amount,line_total_amount,seller_type)values('$($items[$i])','$($orders[$i])','$product','lesson_package','P1-6C Race Product',1000,1,1000,1000,'platform');insert into public.order_fulfillment_events(id,order_id,event_type,payload,status,processed_at)values('$($events[$i])','$($orders[$i])','order.paid','{}','processed',now());insert into public.entitlements(id,beneficiary_user_id,entitlement_type,status,starts_at,expires_at,source_order_id,source_order_item_id,source_fulfillment_event_id,product_id,product_name_snapshot,teacher_scope_user_id,booking_mode_eligibility,lesson_duration_minutes)values('$($ents[$i])','$student','lesson_package','active',now()-interval '1 day',now()+interval '6 months','$($orders[$i])','$($items[$i])','$($events[$i])','$product','P1-6C Race Product','$teacher','fixed',50);insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code)values('$($ents[$i])','$student','allocation',1,'p16c-race-allocation-$i','fixture');"
}
$setup+="insert into public.recurring_lesson_series(id,student_user_id,teacher_user_id,relationship_id,preferred_entitlement_id,weekday,local_start_time,timezone,duration_minutes,effective_from,status,created_by)values('$($series[0])','$student','$teacher','$relationship','$($ents[0])',extract(dow from current_date)::smallint,'08:00','UTC',50,current_date,'active','$teacher'),('$($series[1])','$student','$teacher','$relationship','$($ents[1])',extract(dow from current_date)::smallint,'10:00','UTC',50,current_date,'active','$teacher'),('$($series[2])','$student','$teacher','$relationship','$($ents[2])',extract(dow from current_date)::smallint,'12:00','UTC',50,current_date,'active','$teacher');insert into public.fixed_entitlement_cycles(id,series_id,entitlement_id,student_user_id,teacher_user_id,sequence_number,status,source_fulfillment_event_id,source_order_item_id,attached_by,attachment_actor_role,attachment_reason)values('$($cycles[0])','$($series[0])','$($ents[0])','$student','$teacher',1,'active','$($events[0])','$($items[0])','$admin','admin','P1-6C completion race'),('$($cycles[1])','$($series[2])','$($ents[2])','$student','$teacher',1,'active','$($events[2])','$($items[2])','$admin','admin','P1-6C repeated race');"

try{
  Must (Invoke-Db $setup) 'setup'

  $race=Race @(
    (Auth $teacher "select pg_sleep(.2);select public.complete_fixed_entitlement_cycle('$($cycles[0])','Concurrent completion A');"),
    (Auth $admin "select pg_sleep(.2);select public.admin_revoke_entitlement('$($ents[0])','Concurrent revoke A','p16c-race-revoke-a-0001');")
  );Inspect $race;Assert-NoLeak $race 'cycle completion vs revoke'
  $state=Scalar "select e.status||'|'||c.status||'|'||coalesce(s.preferred_entitlement_id::text,'null')||'|'||s.status from public.fixed_entitlement_cycles c join public.entitlements e on e.id=c.entitlement_id join public.recurring_lesson_series s on s.id=c.series_id where c.id='$($cycles[0])'"
  if($state-eq'revoked|invalidated|null|active'){"A [PASS P1-6C] cycle completion vs revoke has one authoritative outcome; final=$state"}else{$stats.Partial++;throw "A inconsistent state $state"}

  $race=Race @(
    (Auth $admin "select pg_sleep(.2);select public.attach_fixed_entitlement_cycle('$($series[1])','$($ents[1])','$($events[1])','Concurrent attachment B');"),
    (Auth $admin "select pg_sleep(.2);select public.admin_revoke_entitlement('$($ents[1])','Concurrent revoke B','p16c-race-revoke-b-0001');")
  );Inspect $race;Assert-NoLeak $race 'cycle attach vs revoke'
  $active=[int](Scalar "select count(*) from public.fixed_entitlement_cycles where entitlement_id='$($ents[1])' and status='active'")
  $state=Scalar "select status||'|'||coalesce((select preferred_entitlement_id::text from public.recurring_lesson_series where id='$($series[1])'),'null') from public.entitlements where id='$($ents[1])'"
  if($state-eq'revoked|null'-and$active-eq 0){"B [PASS P1-6C] cycle attach vs revoke leaves no active revoked cycle; final=$state"}else{$stats.Partial++;throw "B inconsistent state $state active=$active"}

  $race=Race @(
    (Auth $admin "select pg_sleep(.2);select public.admin_revoke_entitlement('$($ents[2])','Concurrent repeated revoke C','p16c-race-revoke-c-0001');"),
    (Auth $admin "select pg_sleep(.2);select public.admin_revoke_entitlement('$($ents[2])','Concurrent repeated revoke C','p16c-race-revoke-c-0002');")
  );Inspect $race;Assert-NoLeak $race 'repeated revoke'
  $counts=Scalar "select count(*) filter(where action='entitlement.revoked')||'|'||count(*) filter(where action='fixed_cycle.invalidated')||'|'||count(*) filter(where action='recurring_series.preferred_entitlement_cleared') from public.audit_logs where target_id in('$($ents[2])','$($cycles[1])','$($series[2])')"
  $state=Scalar "select e.status||'|'||c.status||'|'||coalesce(s.preferred_entitlement_id::text,'null') from public.fixed_entitlement_cycles c join public.entitlements e on e.id=c.entitlement_id join public.recurring_lesson_series s on s.id=c.series_id where c.id='$($cycles[1])'"
  if($state-eq'revoked|invalidated|null'-and$counts-eq'1|1|1'){"C [PASS P1-6C] repeated revoke is state-idempotent; audits=$counts"}else{$stats.Partial++;throw "C inconsistent state $state audits=$counts"}

  if($stats.Deadlock-ne 0-or$stats.UniqueViolation-ne 0-or$stats.ExclusionViolation-ne 0-or$stats.UnexpectedIntegrity-ne 0-or$stats.Partial-ne 0){throw "Unexpected result: 40P01=$($stats.Deadlock) 23505=$($stats.UniqueViolation) 23P01=$($stats.ExclusionViolation) unexpected23xxx=$($stats.UnexpectedIntegrity) partial=$($stats.Partial)"}
  "SUMMARY 40P01=$($stats.Deadlock) 23505=$($stats.UniqueViolation) 23P01=$($stats.ExclusionViolation) unexpected23xxx=$($stats.UnexpectedIntegrity) domain=$($stats.Domain) partial=$($stats.Partial)"
}finally{Must (Invoke-Db $cleanup) 'cleanup'}
