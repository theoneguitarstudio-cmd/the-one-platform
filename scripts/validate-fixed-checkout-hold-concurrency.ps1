# Manual LOCAL validation only. Reuses the Epic5/Epic6 Docker + independent
# psql process pattern. No Supabase CLI, remote URL or migration/reset command.
[CmdletBinding()]
param(
  [ValidatePattern('^supabase_db_[A-Za-z0-9_-]+$')]
  [string]$ContainerName = 'supabase_db_the-one-platform',
  [ValidateSet('127.0.0.1', 'localhost')]
  [string]$DbHost = '127.0.0.1',
  [string]$LocalDatabasePassword = 'postgres'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT') { throw 'This manual harness requires local Windows Docker Desktop.' }
$docker = (Get-Command docker -ErrorAction Stop).Source
# Pin the Windows named pipe: DOCKER_HOST/context must never select a remote daemon.
$dockerEndpoint = 'npipe:////./pipe/docker_engine'
$run = 'holdrace-' + [guid]::NewGuid().ToString('N')
$sessions = [Collections.Generic.List[object]]::new()
$users = @{}
foreach ($name in @('a','b','teacher','admin')) { $users[$name] = [guid]::NewGuid().ToString() }
$relationshipA = [guid]::NewGuid().ToString()
$relationshipB = [guid]::NewGuid().ToString()
$product = [guid]::NewGuid().ToString()
$allUsers = ($users.Values | ForEach-Object { "'$_'::uuid" }) -join ','
$students = "'$($users.a)'::uuid,'$($users.b)'::uuid"
$paidCount = 0
$ready = $false
$passed = $false
$outsideBefore = $null

function Start-Db([string]$Sql, [string]$Name, [switch]$KeepInputOpen) {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $docker
  # Validated container/host; SQL and password are never interpolated into a shell.
  $info.Arguments = "--host $dockerEndpoint exec -i -e PGPASSWORD $ContainerName psql -X -w -h $DbHost -p 5432 -U postgres -d postgres -qAt -v ON_ERROR_STOP=1 -v VERBOSITY=verbose"
  foreach ($variable in @('DOCKER_CONTEXT','DOCKER_HOST','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH')) {
    $info.EnvironmentVariables.Remove($variable)
  }
  $info.EnvironmentVariables['PGPASSWORD'] = $LocalDatabasePassword
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  [void]$process.Start()
  $session = [pscustomobject]@{
    Process=$process; Name=$Name
    Stdout=$process.StandardOutput.ReadToEndAsync()
    Stderr=$process.StandardError.ReadToEndAsync()
  }
  $sessions.Add($session)
  # The deliberate race gate time and the cross-timezone ownership scan share
  # this PostgreSQL statement budget. Keep assertions strict while avoiding a
  # harness-only 57014 before the gated contenders can finish serialization.
  $process.StandardInput.WriteLine("set application_name='$Name'; set statement_timeout='45s'; set idle_in_transaction_session_timeout='60s';")
  $process.StandardInput.WriteLine($Sql)
  $process.StandardInput.Flush()
  if (-not $KeepInputOpen) { $process.StandardInput.Close() }
  return $session
}

function Wait-Db($Session) {
  if (-not $Session.Process.WaitForExit(30000)) { throw "Session timeout: $($Session.Name)" }
  $result = [pscustomobject]@{
    ExitCode=$Session.Process.ExitCode
    Output=($Session.Stdout.Result + "`n" + $Session.Stderr.Result).Trim()
  }
  # Verbose psql includes SQLSTATE. Any database error except an explicitly
  # asserted domain rejection fails the scenario; deadlocks cannot count as wins.
  if ($result.Output -match 'ERROR:\s+(40P01|23505|23P01|57014|55P03)') {
    throw "Unexpected SQLSTATE in $($Session.Name): $($result.Output)"
  }
  return $result
}
function Invoke-Db([string]$Sql) { Wait-Db (Start-Db $Sql "$run-observer") }
function Must($Result, [string]$Label) {
  if ($Result.ExitCode -ne 0) { throw "$Label failed: $($Result.Output)" }
}
function Value([string]$Sql) {
  $result = Invoke-Db $Sql
  Must $result 'SQL query'
  return ($result.Output -split "`r?`n")[-1]
}
function Check([bool]$Condition, [string]$Label) { if (-not $Condition) { throw $Label } }
function Count([string]$Sql, [int]$Expected, [string]$Label) {
  $actual = [int](Value $Sql)
  Check ($actual -eq $Expected) "$Label expected $Expected, got $actual"
}
function Auth([string]$User, [string]$Body) {
  "begin; set local role authenticated; select set_config('request.jwt.claim.role','authenticated',true); select set_config('request.jwt.claim.sub','$User',true); $Body commit;"
}
function Service([string]$Body) {
  "begin; set local role service_role; select set_config('request.jwt.claim.role','service_role',true); select set_config('request.jwt.claim.sub','',true); $Body commit;"
}
function Wait-Condition([string]$Sql, [string]$Label) {
  $timer = [Diagnostics.Stopwatch]::StartNew()
  do {
    if ((Value $Sql) -eq 't') { return }
    Start-Sleep -Milliseconds 100
  } while ($timer.Elapsed.TotalSeconds -lt 12)
  throw "Timed out waiting for $Label"
}

function Race([string]$Case, [string]$Left, [string]$Right) {
  $gateName = "$run-$Case-g"
  $leftName = "$run-$Case-l"
  $rightName = "$run-$Case-r"
  # Hold the exact existing teacher advisory lock until BOTH independent
  # backends are visibly blocked by this coordinator, not merely started.
  $gate = Start-Db "begin; select private.lock_scheduling_teacher('$($users.teacher)');" $gateName -KeepInputOpen
  try {
    Wait-Condition "select exists(select 1 from pg_stat_activity where application_name='$gateName' and state='idle in transaction');" 'teacher gate'
    $leftSession = Start-Db $Left $leftName
    $rightSession = Start-Db $Right $rightName
    Wait-Condition @"
select count(distinct w.pid)=2 from pg_stat_activity w
where w.application_name in('$leftName','$rightName') and w.wait_event_type='Lock'
  and exists(select 1 from pg_stat_activity g where g.application_name='$gateName'
    and g.pid=any(pg_blocking_pids(w.pid)));
"@ 'two distinct PostgreSQL sessions blocked by the teacher gate'
    Write-Host "$Case barrier: two independent PostgreSQL sessions confirmed"
    $gate.Process.StandardInput.WriteLine('commit;')
    $gate.Process.StandardInput.Close()
    Must (Wait-Db $gate) 'release race gate'
    return @((Wait-Db $leftSession), (Wait-Db $rightSession))
  } finally {
    if (-not $gate.Process.HasExited) {
      try { $gate.Process.StandardInput.WriteLine('rollback;'); $gate.Process.StandardInput.Close() } catch { }
    }
  }
}

function One-Winner($Results, [string]$Label) {
  Check (@($Results | Where-Object { $_.ExitCode -eq 0 }).Count -eq 1) "${Label}: expected exactly one success"
  $loser = @($Results | Where-Object { $_.ExitCode -ne 0 })[0]
  Check ($loser.Output -match 'ERROR:\s+P0001:\s+FIXED_SLOT_UNAVAILABLE') "${Label}: unexpected rejection: $($loser.Output)"
  Write-Host "$Label loser: SQLSTATE P0001 / FIXED_SLOT_UNAVAILABLE"
}
function Claim([string]$Case, [string]$Who, [string]$Time, [string]$Zone='Asia/Taipei', [string]$DateSql='current_date+14') {
  $relationship = if ($Who -eq 'a') { $relationshipA } else { $relationshipB }
  "select public.claim_fixed_checkout_hold('$($users.teacher)','$relationship','$run',extract(dow from ($DateSql))::smallint,'$Time'::time,'$Zone',($DateSql)::date,null,'$run-$Case-$Who');"
}
function Hold-Id([string]$Case, [string]$Who) {
  $id = Value "select id from public.fixed_checkout_holds where student_user_id='$($users[$Who])' and idempotency_key='$run-$Case-$Who';"
  Check ($id -match '^[0-9a-f-]{36}$') "Missing hold $Case/$Who"
  return $id
}
function Pay-Fulfill([string]$Hold) {
  $order = Value "select order_id from public.fixed_checkout_holds where id='$Hold';"
  Must (Invoke-Db (Auth $users.admin "select public.admin_confirm_cash_payment('$order','$run-$Hold','Local hold concurrency payment');")) 'cash payment'
  $event = Value "select id from public.order_fulfillment_events where order_id='$order' and event_type='order.paid';"
  Must (Invoke-Db (Service "select public.process_order_fulfillment_event('$event');")) 'Epic5 fulfillment'
  $ent = Value "select id from public.entitlements where source_order_id='$order' and source_fulfillment_event_id='$event';"
  Check ($ent -match '^[0-9a-f-]{36}$') 'Expected one fulfilled entitlement'
  $script:paidCount++
  return [pscustomobject]@{Hold=$Hold; Order=$order; Event=$event; Entitlement=$ent}
}
function Conversion($Paid) {
  "select public.convert_fixed_checkout_hold('$($Paid.Hold)','$($Paid.Entitlement)','$($Paid.Event)','Local concurrency conversion');"
}
function Conversion-Result($Result, [string]$Expected, [string]$ErrorCode='') {
  Must $Result 'conversion call'
  $line = @($Result.Output -split "`r?`n" | Where-Object { $_.StartsWith('{') })[-1]
  $json = $line | ConvertFrom-Json
  Check ($json.status -eq $Expected) "Unexpected conversion result: $line"
  if ($ErrorCode) { Check ($json.error -eq $ErrorCode) "Unexpected conversion rejection: $line" }
}
function Outside-State {
  Value @"
select md5(concat(
 (select coalesce(string_agg(md5(to_jsonb(x)::text),'' order by id),'') from public.entitlements x where beneficiary_user_id not in($students)),
 (select coalesce(string_agg(md5(to_jsonb(x)::text),'' order by id),'') from public.lesson_credit_ledger x where beneficiary_user_id not in($students)),
 (select coalesce(string_agg(md5(to_jsonb(x)::text),'' order by id),'') from public.lesson_credit_reservations x where beneficiary_user_id not in($students))));
"@
}
function Integrity([string]$Case, [int]$Effective, [int]$TotalSeries, [int]$CaseHolds) {
  Count "select count(*) from public.fixed_checkout_holds where idempotency_key like '$run-$Case-%';" $CaseHolds "$Case hold history"
  Count "select count(*) from public.fixed_checkout_holds where idempotency_key like '$run-$Case-%' and status='active' and expires_at>clock_timestamp();" $Effective "$Case effective holds"
  Count "select count(*) from public.recurring_lesson_series where teacher_user_id='$($users.teacher)';" $TotalSeries 'series count'
  Count "select count(*) from public.fixed_entitlement_cycles where teacher_user_id='$($users.teacher)';" $TotalSeries 'cycle count'
  Count "select count(*) from public.entitlements where beneficiary_user_id in($students);" $paidCount 'only fulfilled entitlements'
  Count "select count(*) from public.lesson_credit_ledger where beneficiary_user_id in($students);" $paidCount 'only Epic5 allocations'
  Count "select count(*) from public.lesson_credit_ledger l join public.entitlements e on e.id=l.entitlement_id where l.beneficiary_user_id in($students) and (l.entry_type<>'allocation' or l.available_delta<>4 or l.reserved_delta<>0 or l.consumed_delta<>0 or l.source_fulfillment_event_id is distinct from e.source_fulfillment_event_id);" 0 'ledger provenance/value'
  Count "select count(*) from public.lesson_credit_reservations where beneficiary_user_id in($students);" 0 'no reservation mutations'
  Count "select count(*) from public.lessons where student_user_id in($students);" 0 'no speculative Lessons'
  Count "select count(*) from public.bookings where student_user_id in($students);" 0 'no speculative Bookings'
  Count "select count(*) from public.orders o where buyer_user_id in($students) and not exists(select 1 from public.fixed_checkout_holds h where h.order_id=o.id);" 0 'no orphan checkout order'
  Count "select count(*) from public.recurring_lesson_series s where teacher_user_id='$($users.teacher)' and not exists(select 1 from public.fixed_checkout_holds h where h.series_id=s.id and h.status='converted');" 0 'no partial owner'
  Count "select count(*) from public.fixed_entitlement_cycles c join public.fixed_checkout_holds h on h.cycle_id=c.id join public.entitlements e on e.id=c.entitlement_id where h.teacher_user_id='$($users.teacher)' and (c.sequence_number<>1 or c.series_id<>h.series_id or e.source_order_id<>h.order_id or e.beneficiary_user_id<>h.student_user_id or c.source_fulfillment_event_id<>h.source_fulfillment_event_id);" 0 'Cycle 1 and entitlement identity'
  Count "select count(*) from (select series_id,sequence_number from public.fixed_entitlement_cycles where teacher_user_id='$($users.teacher)' group by series_id,sequence_number having count(*)>1) d;" 0 'no duplicate sequence'
  Count "select count(*) from public.audit_logs where action='fixed_checkout_hold.converted' and target_id in(select id from public.fixed_checkout_holds where teacher_user_id='$($users.teacher)');" $TotalSeries 'one conversion audit per owner'
  Count "select count(*) from public.audit_logs where action='fixed_cycle.attached' and target_id in(select id from public.fixed_entitlement_cycles where teacher_user_id='$($users.teacher)');" $TotalSeries 'one cycle attachment audit'
  Count "select count(*) from public.fixed_checkout_holds h where teacher_user_id='$($users.teacher)' and status='active' and expires_at>clock_timestamp() and not private.recurring_series_ownership_clear(h.student_user_id,h.teacher_user_id,h.weekday,h.local_start_time,h.timezone,h.duration_minutes,h.effective_from,h.effective_until);" 0 'no live hold overlapping a formal owner'
  Check ((Outside-State) -eq $outsideBefore) 'Unrelated entitlement/reservation/ledger state changed'
}

# Cleanup only this run's UUIDs. Replication role is transaction-local and used
# only for fixture teardown, as in the existing Epic5/Epic6 harnesses. Production
# append-only guards and RPC permissions are never changed or disabled in tests.
$cleanup = @"
begin;
set local session_replication_role='replica';
create temporary table cleanup_ids(id uuid primary key) on commit drop;
insert into cleanup_ids select unnest(array[$allUsers]) union select '$product'::uuid
 union select id from public.orders where buyer_user_id in($students)
 union select id from public.order_items where product_id='$product'
 union select id from public.payments where order_id in(select id from public.orders where buyer_user_id in($students))
 union select id from public.order_fulfillment_events where order_id in(select id from public.orders where buyer_user_id in($students))
 union select id from public.entitlements where beneficiary_user_id in($students)
 union select id from public.fixed_checkout_holds where teacher_user_id='$($users.teacher)'
 union select id from public.recurring_lesson_series where teacher_user_id='$($users.teacher)'
 union select id from public.fixed_entitlement_cycles where teacher_user_id='$($users.teacher)';
delete from public.audit_logs where actor_user_id in($allUsers) or target_id in(select id from cleanup_ids);
delete from public.fixed_checkout_holds where teacher_user_id='$($users.teacher)';
delete from public.fixed_entitlement_cycles where teacher_user_id='$($users.teacher)';
delete from public.lesson_records where lesson_id in(select id from public.lessons where student_user_id in($students));
delete from public.recurring_lesson_series_exceptions where series_id in(select id from public.recurring_lesson_series where teacher_user_id='$($users.teacher)');
delete from public.recurring_lesson_occurrences where teacher_user_id='$($users.teacher)';
delete from public.bookings where student_user_id in($students);
delete from public.lesson_credit_ledger where beneficiary_user_id in($students);
delete from public.lesson_credit_reservations where beneficiary_user_id in($students);
delete from public.lessons where student_user_id in($students);
delete from public.recurring_lesson_series where teacher_user_id='$($users.teacher)';
delete from public.entitlement_expiry_history where entitlement_id in(select id from public.entitlements where beneficiary_user_id in($students));
delete from public.entitlements where beneficiary_user_id in($students);
delete from public.fulfillment_manual_retry_attempts where order_id in(select id from public.orders where buyer_user_id in($students));
delete from public.refunds where order_id in(select id from public.orders where buyer_user_id in($students));
delete from public.payment_submissions where buyer_user_id in($students);
delete from public.payments where order_id in(select id from public.orders where buyer_user_id in($students));
delete from public.order_item_fulfillment_snapshots where product_id='$product';
delete from public.order_fulfillment_events where order_id in(select id from public.orders where buyer_user_id in($students));
delete from public.order_items where product_id='$product';
delete from public.orders where buyer_user_id in($students);
delete from public.lesson_package_product_configs where product_id='$product';
delete from public.product_public_catalog where product_id='$product';
delete from public.product_publication_requests where product_id='$product';
delete from public.products where id='$product';
delete from public.teacher_availability_exceptions where teacher_user_id='$($users.teacher)';
delete from public.teacher_availability_rules where teacher_user_id='$($users.teacher)';
delete from public.teacher_scheduling_settings where teacher_user_id='$($users.teacher)';
delete from public.student_teacher_relationships where student_user_id in($students);
delete from public.teacher_public_profiles where teacher_profile_id in(select id from public.teacher_profiles where user_id='$($users.teacher)');
delete from public.teacher_profiles where user_id='$($users.teacher)';
delete from public.public_profiles where user_id in($allUsers);
delete from public.user_roles where user_id in($allUsers);
delete from public.profiles where user_id in($allUsers);
delete from auth.users where id in($allUsers);
commit;
"@

try {
  $address = Value 'select host(inet_server_addr());'
  Check ($address -in @('127.0.0.1','::1')) 'Refusing non-loopback PostgreSQL server'
  Check ((Value "select to_regclass('public.fixed_checkout_holds') is not null and exists(select 1 from supabase_migrations.schema_migrations where version='20260903000100');") -eq 't') 'Apply the local checkout hold migration first'
  $ready = $true
  Write-Host "LOCAL ONLY: $ContainerName / $DbHost; fixture prefix $run"
  Must (Invoke-Db @"
begin;
insert into auth.users(id,email) values
('$($users.a)','$run-a@example.invalid'),('$($users.b)','$run-b@example.invalid'),
('$($users.teacher)','$run-teacher@example.invalid'),('$($users.admin)','$run-admin@example.invalid');
insert into public.user_roles(user_id,role) values('$($users.teacher)','teacher'),('$($users.admin)','admin');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd)
values('$($users.teacher)','$run','Local hold race','active',true,array['online']::public.teaching_mode[],500);
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)
values('$relationshipA','$($users.a)','$($users.teacher)','active','online'),('$relationshipB','$($users.b)','$($users.teacher)','active','online');
insert into public.teacher_scheduling_settings(teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes)
values('$($users.teacher)','Asia/Taipei',0,180,10);
insert into public.teacher_availability_rules(teacher_user_id,weekday,local_start_time,local_end_time,timezone,effective_from,created_by)
select '$($users.teacher)',d,'00:00','23:59','Asia/Taipei',current_date,'$($users.teacher)' from generate_series(0,6) d;
insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,is_public,is_purchasable,published_at)
values('$product','lesson_package','active','$run','Hold race package','TWD',3200,'platform',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,booking_mode_eligibility)
values('$product',4,12,'months',50,'fixed');
commit;
"@) 'fixture setup'
  Must (Invoke-Db (Auth $users.admin "select public.set_fixed_checkout_hold_policy('$product',1200,'Local race fixture TTL');")) 'TTL policy'
  $outsideBefore = Outside-State

  $race = Race 'A' (Auth $users.a (Claim 'A' 'a' '08:00')) (Auth $users.b (Claim 'A' 'b' '08:00'))
  One-Winner $race 'A same-slot claim'
  Integrity 'A' 1 0 1
  Write-Host 'A PASS: exactly one effective hold, no order/owner/cycle partial writes'

  # Real elapsed expiry, not a raw status update. A retry keeps the expired row
  # for history; it must not resurrect or block B. Restore TTL for later claims.
  Must (Invoke-Db (Auth $users.admin "select public.set_fixed_checkout_hold_policy('$product',2,'Short expiry test fixture');")) 'short TTL'
  Must (Invoke-Db (Auth $users.a (Claim 'B' 'a' '10:00'))) 'A pre-expiry claim'
  $oldHold = Hold-Id 'B' 'a'
  Must (Invoke-Db (Auth $users.admin "select public.set_fixed_checkout_hold_policy('$product',1200,'Restore race fixture TTL');")) 'restore TTL'
  Wait-Condition "select expires_at<=clock_timestamp() from public.fixed_checkout_holds where id='$oldHold';" 'actual expiry'
  $race = Race 'B' (Auth $users.a (Claim 'B' 'a' '10:00')) (Auth $users.b (Claim 'B' 'b' '10:00'))
  foreach ($result in $race) { Must $result 'expiry retry/new claim' }
  Check ((Hold-Id 'B' 'a') -eq $oldHold) 'Expired retry changed identity'
  Count "select count(*) from public.fixed_checkout_holds where id='$oldHold' and expires_at<=clock_timestamp();" 1 'old hold still expired'
  $newHold = Hold-Id 'B' 'b'
  Count "select count(*) from public.fixed_checkout_holds where id='$newHold' and status='active' and expires_at>clock_timestamp();" 1 'B is sole effective holder'
  Integrity 'B' 1 0 2
  Write-Host 'B PASS: expired A history retained; only B is effective (no cron required)'

  $paidB = Pay-Fulfill $newHold
  Conversion-Result (Invoke-Db (Service (Conversion $paidB))) 'converted'
  # A payment and fulfillment genuinely arrive AFTER B is already owner.
  $paidA = Pay-Fulfill $oldHold
  $race = Race 'C' (Service (Conversion $paidA)) (Service (Conversion $paidB))
  Conversion-Result $race[0] 'rejected' 'HOLD_NOT_ACTIVE'
  Conversion-Result $race[1] 'converted'
  Count "select count(*) from public.recurring_lesson_series where teacher_user_id='$($users.teacher)' and student_user_id='$($users.b)';" 1 'B remains owner'
  Count "select count(*) from public.fixed_entitlement_cycles where entitlement_id='$($paidA.Entitlement)';" 0 'A receives no cycle'
  Count "select count(*) from public.entitlements where id='$($paidA.Entitlement)' and source_order_id='$($paidA.Order)';" 1 'A commerce entitlement survives'
  Count "select count(*) from public.fixed_entitlement_cycles where entitlement_id='$($paidB.Entitlement)' and sequence_number=1;" 1 'B Cycle 1 provenance'
  Integrity 'B' 0 1 2
  Write-Host 'C PASS: delayed A rejected; B ownership and both commerce entitlements preserved'

  Must (Invoke-Db (Auth $users.a (Claim 'D' 'a' '12:00'))) 'conversion race hold'
  $paidD = Pay-Fulfill (Hold-Id 'D' 'a')
  $race = Race 'D' (Service (Conversion $paidD)) (Auth $users.b (Claim 'D' 'b' '12:00'))
  One-Winner $race 'D conversion vs claim'
  Conversion-Result $race[0] 'converted'
  Integrity 'D' 0 2 1
  Write-Host 'D PASS: conversion succeeds; competing claim cannot coexist'

  # Derive the second local schedule from the existing resolver, never +08:00.
  $utc = (Value "select json_build_object('date',(i at time zone 'UTC')::date,'time',(i at time zone 'UTC')::time) from (select private.resolve_scheduling_local_datetime(current_date+14,'14:00','Asia/Taipei') i) x;") | ConvertFrom-Json
  $race = Race 'TZ' (Auth $users.a (Claim 'TZ' 'a' '14:00')) (Auth $users.b (Claim 'TZ' 'b' $utc.time 'UTC' "date '$($utc.date)'"))
  One-Winner $race 'TZ actual UTC overlap'
  Integrity 'TZ' 1 2 1
  Write-Host 'TZ PASS: different wall schedules with actual UTC overlap have one winner'
  $passed = $true
} finally {
  try {
    if ($ready) {
      # Terminate only this run's tagged backends before cleanup, including any
      # sessions left waiting after a failed barrier/timeout. Never reset the DB.
      Must (Invoke-Db "select pg_terminate_backend(pid) from pg_stat_activity where application_name like '$run-%' and pid<>pg_backend_pid();") 'stop fixture sessions'
    }
  } finally {
    try {
      foreach ($session in $sessions.ToArray()) {
        if (-not $session.Process.HasExited) {
          try { $session.Process.StandardInput.Close() } catch { }
          if (-not $session.Process.WaitForExit(3000)) { $session.Process.Kill() }
        }
      }
    } finally {
      try {
        if ($ready) {
          Must (Invoke-Db $cleanup) 'fixture cleanup'
          Count "select count(*) from auth.users where id in($allUsers);" 0 'cleanup users'
          Count "select count(*) from public.fixed_checkout_holds where teacher_user_id='$($users.teacher)';" 0 'cleanup holds'
          Count "select count(*) from public.orders where buyer_user_id in($students);" 0 'cleanup orders'
          Count "select count(*) from public.recurring_lesson_series where teacher_user_id='$($users.teacher)';" 0 'cleanup series'
          Count "select count(*) from public.fixed_entitlement_cycles where teacher_user_id='$($users.teacher)';" 0 'cleanup cycles'
          Count "select count(*) from public.lesson_credit_ledger where beneficiary_user_id in($students);" 0 'cleanup ledger'
          Count "select count(*) from public.entitlements where beneficiary_user_id in($students);" 0 'cleanup entitlements'
          Count "select count(*) from public.products where id='$product';" 0 'cleanup product'
          Write-Host 'CLEANUP PASS: this run fixtures removed'
        }
      } finally {
        foreach ($session in $sessions) { $session.Process.Dispose() }
      }
    }
  }
}
if ($passed) { Write-Host 'P1-4C CONCURRENCY PASS: A / B / C / D / TZ; no deadlocks, leaked integrity errors or partial writes' }
