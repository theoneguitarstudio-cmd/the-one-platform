# Manual LOCAL-only two-session validation for P1-5B Makeup Right authority.
[CmdletBinding()]
param(
  [ValidatePattern('^supabase_db_[A-Za-z0-9_-]+$')]
  [string]$ContainerName
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$docker=(Get-Command docker -ErrorAction Stop).Source
if(-not $ContainerName){
  $names=@(& $docker --host 'npipe:////./pipe/docker_engine' ps --format '{{.Names}}' |
    Where-Object { $_ -like 'supabase_db_*' })
  if($names.Count-ne 1){throw "Expected one local Supabase DB container; found $($names.Count)."}
  $ContainerName=$names[0]
}

function Invoke-Db([string]$Sql){
  $out=& $docker --host 'npipe:////./pipe/docker_engine' exec $ContainerName psql -X -U postgres -d postgres `
    -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -At -c $Sql 2>&1 | Out-String
  [pscustomobject]@{ExitCode=$LASTEXITCODE;Output=$out.Trim()}
}
function Start-Db([string]$Sql){
  $i=[Diagnostics.ProcessStartInfo]::new()
  $i.FileName=$docker
  $i.Arguments="--host npipe:////./pipe/docker_engine exec -i $ContainerName psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -At"
  $i.UseShellExecute=$false;$i.RedirectStandardInput=$true
  $i.RedirectStandardOutput=$true;$i.RedirectStandardError=$true
  $p=[Diagnostics.Process]::new();$p.StartInfo=$i;[void]$p.Start()
  $p.StandardInput.Write($Sql);$p.StandardInput.Close();$p
}
function Wait-Db($Process){
  $stdout=$Process.StandardOutput.ReadToEndAsync();$stderr=$Process.StandardError.ReadToEndAsync()
  if(-not $Process.WaitForExit(30000)){$Process.Kill();throw 'DB session timeout'}
  [pscustomobject]@{ExitCode=$Process.ExitCode;Output=(($stdout.Result+"`n"+$stderr.Result).Trim())}
}
function Race([string[]]$Sql){$processes=@($Sql|ForEach-Object{Start-Db $_});@($processes|ForEach-Object{Wait-Db $_})}
function Auth([string]$User,[string]$Body){
  "begin;set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','$User',true);set local statement_timeout='15s';$Body commit;"
}
function Must($Result,[string]$Name){if($Result.ExitCode-ne 0){throw "$Name failed: $($Result.Output)"}}
function One-Winner($Results,[string]$Name){
  $wins=@($Results|Where-Object{$_.ExitCode-eq 0}).Count
  $unexpected=@($Results|Where-Object{$_.ExitCode-ne 0-and$_.Output-notmatch'ERROR:\s+P0001'}).Count
  if($wins-ne 1-or$unexpected-ne 0){throw "$Name expected one success and one domain rejection: $($Results.Output-join' | ')"}
}
function Count([string]$Sql,[int]$Expected,[string]$Name){
  $result=Invoke-Db $Sql;Must $result $Name
  $actual=[int](($result.Output-split"`r?`n")[-1])
  if($actual-ne$Expected){throw "$Name expected $Expected got $actual"}
}

$student='69000000-0000-0000-0000-000000000001'
$teacher='69000000-0000-0000-0000-000000000002'
$relationship='69000000-0000-0000-0000-000000000010'
$rightA='69000000-0000-0000-0000-000000000020'
$rightB='69000000-0000-0000-0000-000000000021'
$lessonA='69000000-0000-0000-0000-000000000030'
$lessonB='69000000-0000-0000-0000-000000000031'
$cleanup="begin;set local session_replication_role='replica';delete from public.makeup_right_operations where makeup_right_id in('$rightA','$rightB');delete from public.audit_logs where target_id in('$rightA','$rightB');delete from public.makeup_rights where id in('$rightA','$rightB');delete from public.lessons where id in('$lessonA','$lessonB');delete from public.student_teacher_relationships where id='$relationship';delete from public.teacher_profiles where user_id='$teacher';delete from public.user_roles where user_id='$teacher';delete from public.profiles where user_id in('$student','$teacher');delete from auth.users where id in('$student','$teacher');commit;"
$setup=$cleanup+"insert into auth.users(id,email)values('$student','makeup-race-student@example.invalid'),('$teacher','makeup-race-teacher@example.invalid');insert into public.user_roles(user_id,role)values('$teacher','teacher');insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url)values('$teacher','makeup-race-teacher','Race fixture','active',true,array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij');insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)values('$relationship','$student','$teacher','active','online');insert into public.lessons(id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url)values('$lessonA','$student','$teacher','$relationship','flexible','online',now()-interval '2 days',now()-interval '2 days'+interval '50 minutes',50,'Asia/Taipei','teacher_cancelled','manual_google_meet','https://meet.google.com/abc-defg-hij'),('$lessonB','$student','$teacher','$relationship','flexible','online',now()-interval '1 day',now()-interval '1 day'+interval '50 minutes',50,'Asia/Taipei','teacher_cancelled','manual_google_meet','https://meet.google.com/abc-defg-hij');insert into public.makeup_rights(id,student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,source,source_operation_key,status,valid_until,reason,created_by)values('$rightA','$student','$lessonA','$teacher','$teacher','teacher_cancellation','p15b-race-create-a-001','available',now()+interval '10 days','Reserve race fixture','$teacher');insert into public.makeup_rights(id,student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,source,source_operation_key,status,valid_until,reason,created_by,reserved_at,reserved_by)values('$rightB','$student','$lessonB','$teacher','$teacher','teacher_cancellation','p15b-race-create-b-001','reserved',now()+interval '10 days','Consume restore race fixture','$teacher',now(),'$student');"

try{
  Must (Invoke-Db $setup) 'setup'
  $reserveRace=Race @(
    (Auth $student "select pg_sleep(.2);select public.reserve_makeup_right('$rightA','$student','$teacher','p15b-race-reserve-a-01','Concurrent reserve A');"),
    (Auth $student "select pg_sleep(.2);select public.reserve_makeup_right('$rightA','$student','$teacher','p15b-race-reserve-b-01','Concurrent reserve B');")
  )
  One-Winner $reserveRace 'Same Right reserve race'
  Count "select count(*) from public.makeup_rights where id='$rightA' and status='reserved'" 1 'One reserved state'
  Count "select count(*) from public.makeup_right_operations where makeup_right_id='$rightA' and operation_type='reserve'" 1 'One reserve operation'
  'A [PASS] Same available Right concurrent reserve has exactly one winner'

  $terminalRace=Race @(
    (Auth $teacher "select pg_sleep(.2);select public.consume_makeup_right('$rightB','p15b-race-consume-001','Concurrent consume');"),
    (Auth $student "select pg_sleep(.2);select public.restore_makeup_right('$rightB','p15b-race-restore-001','Concurrent restore');")
  )
  One-Winner $terminalRace 'Consume vs restore race'
  Count "select count(*) from public.makeup_rights where id='$rightB' and status in('used','available')" 1 'One valid final state'
  Count "select count(*) from public.makeup_right_operations where makeup_right_id='$rightB' and operation_type in('consume','restore')" 1 'One terminal operation'
  'B [PASS] Consume versus restore has one authoritative outcome'
  'SUMMARY deadlock=0 integrity_leak=0 partial=0'
} finally {
  Must (Invoke-Db $cleanup) 'cleanup'
}
