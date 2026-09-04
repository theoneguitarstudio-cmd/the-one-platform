# LOCAL-only two-session validation for P1-5A Teacher cancellation value transfer.
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
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=$docker
  $info.Arguments="--host npipe:////./pipe/docker_engine exec -i $ContainerName psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -At"
  $info.UseShellExecute=$false
  $info.RedirectStandardInput=$true
  $info.RedirectStandardOutput=$true
  $info.RedirectStandardError=$true
  $process=[Diagnostics.Process]::new()
  $process.StartInfo=$info
  [void]$process.Start()
  $process.StandardInput.Write($Sql)
  $process.StandardInput.Close()
  $process
}
function Wait-Db($Process){
  $stdout=$Process.StandardOutput.ReadToEndAsync()
  $stderr=$Process.StandardError.ReadToEndAsync()
  if(-not $Process.WaitForExit(30000)){$Process.Kill();throw 'DB session timeout'}
  [pscustomobject]@{ExitCode=$Process.ExitCode;Output=(($stdout.Result+"`n"+$stderr.Result).Trim())}
}
function Race([string[]]$Sql){
  $processes=@($Sql|ForEach-Object{Start-Db $_})
  @($processes|ForEach-Object{Wait-Db $_})
}
function Auth([string]$User,[string]$Body){
  "begin;set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','$User',true);set local statement_timeout='15s';select pg_sleep(.2);$Body commit;"
}
function Must($Result,[string]$Name){
  if($Result.ExitCode-ne 0){throw "$Name failed: $($Result.Output)"}
}
function Valid-Race($Results,[string]$Name){
  $wins=@($Results|Where-Object{$_.ExitCode-eq 0}).Count
  $unexpected=@($Results|Where-Object{$_.ExitCode-ne 0-and$_.Output-notmatch'ERROR:\s+P0001'}).Count
  if($wins-lt 1-or$unexpected-ne 0){
    throw "$Name expected at least one success and only domain rejection for the loser: $($Results.Output-join' | ')"
  }
}
function Count([string]$Sql,[int]$Expected,[string]$Name){
  $result=Invoke-Db $Sql
  Must $result $Name
  $actual=[int](($result.Output-split"`r?`n")[-1])
  if($actual-ne$Expected){throw "$Name expected $Expected got $actual"}
}

$student='72000000-0000-0000-0000-000000000001'
$teacher='72000000-0000-0000-0000-000000000002'
$admin='72000000-0000-0000-0000-000000000003'
$relationship='72000000-0000-0000-0000-000000000010'
$entitlementA='72000000-0000-0000-0000-000000000020'
$entitlementB='72000000-0000-0000-0000-000000000021'
$entitlementC='72000000-0000-0000-0000-000000000022'
$lessonA='72000000-0000-0000-0000-000000000030'
$lessonB='72000000-0000-0000-0000-000000000031'
$lessonC='72000000-0000-0000-0000-000000000032'
$reservationA='72000000-0000-0000-0001-000000000040'
$reservationB='72000000-0000-0000-0001-000000000041'
$reservationC='72000000-0000-0000-0001-000000000042'
$bookingA='72000000-0000-0000-0000-000000000050'
$bookingB='72000000-0000-0000-0000-000000000051'
$bookingC='72000000-0000-0000-0000-000000000052'

$cleanup="begin;set local session_replication_role='replica';delete from public.audit_logs where actor_user_id in('$student','$teacher','$admin');delete from public.lesson_records where lesson_id in('$lessonA','$lessonB','$lessonC');delete from public.makeup_right_operations where makeup_right_id in(select id from public.makeup_rights where origin_lesson_id in('$lessonA','$lessonB','$lessonC'));delete from public.makeup_rights where origin_lesson_id in('$lessonA','$lessonB','$lessonC');delete from public.lesson_credit_ledger where entitlement_id in('$entitlementA','$entitlementB','$entitlementC');delete from public.bookings where id in('$bookingA','$bookingB','$bookingC');delete from public.lesson_credit_reservations where id in('$reservationA','$reservationB','$reservationC');delete from public.lessons where id in('$lessonA','$lessonB','$lessonC');delete from public.entitlements where id in('$entitlementA','$entitlementB','$entitlementC');delete from public.makeup_right_policies where source='teacher_cancellation';delete from public.student_teacher_relationships where id='$relationship';delete from public.teacher_profiles where user_id='$teacher';delete from public.user_roles where user_id in('$teacher','$admin');delete from public.profiles where user_id in('$student','$teacher','$admin');delete from auth.users where id in('$student','$teacher','$admin');commit;"
$setup=$cleanup+"insert into auth.users(id,email)values('$student','p15a-race-student@example.invalid'),('$teacher','p15a-race-teacher@example.invalid'),('$admin','p15a-race-admin@example.invalid');insert into public.user_roles(user_id,role)values('$teacher','teacher'),('$admin','admin');insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url)values('$teacher','p15a-race-teacher','Race fixture','active',true,array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij');insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)values('$relationship','$student','$teacher','active','online');insert into public.makeup_right_policies(source,validity_seconds,updated_by)values('teacher_cancellation',1209600,'$admin');insert into public.entitlements(id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes)values('$entitlementA','$student','$teacher','lesson_package','active',now()-interval '30 days',now()+interval '30 days','Race A','flexible',50),('$entitlementB','$student','$teacher','lesson_package','active',now()-interval '30 days',now()+interval '30 days','Race B','flexible',50),('$entitlementC','$student','$teacher','lesson_package','active',now()-interval '30 days',now()+interval '30 days','Race C','flexible',50);insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code)values('$entitlementA','$student','allocation',1,'p15a-race-allocation-a','test_fixture'),('$entitlementB','$student','allocation',1,'p15a-race-allocation-b','test_fixture'),('$entitlementC','$student','allocation',1,'p15a-race-allocation-c','test_fixture');insert into public.lessons(id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url)values('$lessonA','$student','$teacher','$relationship','flexible','online',now()-interval '1 day',now()-interval '1 day'+interval '50 minutes',50,'Asia/Taipei','scheduled','manual_google_meet','https://meet.google.com/abc-defg-hij'),('$lessonB','$student','$teacher','$relationship','flexible','online',now()-interval '2 days',now()-interval '2 days'+interval '50 minutes',50,'Asia/Taipei','scheduled','manual_google_meet','https://meet.google.com/abc-defg-hij'),('$lessonC','$student','$teacher','$relationship','flexible','online',now()-interval '3 days',now()-interval '3 days'+interval '50 minutes',50,'Asia/Taipei','scheduled','manual_google_meet','https://meet.google.com/abc-defg-hij');insert into public.lesson_credit_reservations(id,entitlement_id,beneficiary_user_id,reservation_key,lesson_id,booking_reference,status)values('$reservationA','$entitlementA','$student','p15a-race-reservation-a','$lessonA','$bookingA','reserved'),('$reservationB','$entitlementB','$student','p15a-race-reservation-b','$lessonB','$bookingB','reserved'),('$reservationC','$entitlementC','$student','p15a-race-reservation-c','$lessonC','$bookingC','reserved');insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,reservation_id,lesson_id,operation_key,reason_code)values('$entitlementA','$student','reservation',-1,1,'$reservationA','$lessonA','p15a-race-reserve-a','test_fixture'),('$entitlementB','$student','reservation',-1,1,'$reservationB','$lessonB','p15a-race-reserve-b','test_fixture'),('$entitlementC','$student','reservation',-1,1,'$reservationC','$lessonC','p15a-race-reserve-c','test_fixture');insert into public.bookings(id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,timezone_anchor,lesson_id,credit_reservation_id,created_by,idempotency_key)select '$bookingA',student_user_id,teacher_user_id,relationship_id,'flexible','confirmed',starts_at,ends_at,timezone_anchor,id,'$reservationA',student_user_id,'p15a-race-booking-a' from public.lessons where id='$lessonA';insert into public.bookings(id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,timezone_anchor,lesson_id,credit_reservation_id,created_by,idempotency_key)select '$bookingB',student_user_id,teacher_user_id,relationship_id,'flexible','confirmed',starts_at,ends_at,timezone_anchor,id,'$reservationB',student_user_id,'p15a-race-booking-b' from public.lessons where id='$lessonB';insert into public.bookings(id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,timezone_anchor,lesson_id,credit_reservation_id,created_by,idempotency_key)select '$bookingC',student_user_id,teacher_user_id,relationship_id,'flexible','confirmed',starts_at,ends_at,timezone_anchor,id,'$reservationC',student_user_id,'p15a-race-booking-c' from public.lessons where id='$lessonC';update public.lesson_credit_reservations set booking_id=case id when '$reservationA' then '$bookingA'::uuid when '$reservationB' then '$bookingB'::uuid else '$bookingC'::uuid end where id in('$reservationA','$reservationB','$reservationC');"

try{
  Must (Invoke-Db $setup) 'setup'

  $classificationRace=Race @(
    (Auth $teacher "select public.cancel_lesson_booking('$bookingA','unchanged','Concurrent Teacher cancellation');"),
    (Auth $student "select public.cancel_lesson_booking('$bookingA','released','Concurrent Student cancellation');")
  )
  Valid-Race $classificationRace 'Teacher versus Student cancellation'
  Count "select count(*) from public.bookings where id='$bookingA' and status='cancelled'" 1 'C1 terminal Booking'
  Count "select count(*) from public.lessons l where l.id='$lessonA' and ((l.status='teacher_cancelled' and (select count(*) from public.makeup_rights where origin_lesson_id=l.id)=1 and (select count(*) from public.lesson_credit_ledger where reservation_id='$reservationA' and entry_type='release')=0) or (l.status='student_cancelled' and (select count(*) from public.makeup_rights where origin_lesson_id=l.id)=0 and (select count(*) from public.lesson_credit_ledger where reservation_id='$reservationA' and entry_type='release')=1))" 1 'C1 exactly one compensation classification'
  'C1 [PASS] Teacher versus Student cancellation has one authoritative value outcome'

  $completionRace=Race @(
    (Auth $teacher "select public.cancel_lesson_booking('$bookingB','unchanged','Concurrent Teacher cancellation');"),
    (Auth $teacher "select public.complete_lesson_booking('$bookingB','Concurrent completion','','','','');")
  )
  Valid-Race $completionRace 'Teacher cancellation versus completion'
  Count "select count(*) from public.bookings b join public.lessons l on l.id=b.lesson_id where b.id='$bookingB' and ((b.status='cancelled' and l.status='teacher_cancelled' and (select count(*) from public.makeup_rights where origin_lesson_id=l.id)=1 and (select count(*) from public.lesson_credit_ledger where reservation_id='$reservationB' and reason_code='teacher_cancellation_makeup_transfer')=1 and (select count(*) from public.lesson_credit_ledger where reservation_id='$reservationB' and entry_type='consumption')=0) or (b.status='completed' and l.status='completed' and (select count(*) from public.makeup_rights where origin_lesson_id=l.id)=0 and (select count(*) from public.lesson_credit_ledger where reservation_id='$reservationB' and entry_type='consumption')=1))" 1 'C2 one terminal outcome'
  'C2 [PASS] Teacher cancellation versus completion has one terminal value outcome'

  $retryRace=Race @(
    (Auth $teacher "select public.cancel_lesson_booking('$bookingC','unchanged','Concurrent Teacher retry A');"),
    (Auth $teacher "select public.cancel_lesson_booking('$bookingC','unchanged','Concurrent Teacher retry B');")
  )
  Valid-Race $retryRace 'Concurrent Teacher cancellation retries'
  Count "select count(*) from public.makeup_rights where origin_lesson_id='$lessonC'" 1 'C3 one Makeup Right'
  Count "select count(*) from public.lesson_credit_ledger where reservation_id='$reservationC' and reason_code='teacher_cancellation_makeup_transfer'" 1 'C3 one transfer ledger mutation'
  Count "select count(*) from public.audit_logs where target_id='$bookingC' and action='booking.cancelled'" 1 'C3 one cancellation audit'
  'C3 [PASS] Concurrent Teacher cancellation retries are idempotent'
  'SUMMARY deadlock=0 double_compensation=0 partial=0'
} finally {
  Must (Invoke-Db $cleanup) 'cleanup'
}
