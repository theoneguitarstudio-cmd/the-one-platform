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
$run = 'renewrace-' + [guid]::NewGuid().ToString('N')
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
  $process.StandardInput.WriteLine("set application_name='$Name'; set statement_timeout='20s'; set idle_in_transaction_session_timeout='30s';")
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
  # backends are visibly blocked by this coordinator, directly or through the
  # other participant. Resource hashes determine student/teacher lock order.
  $gate = Start-Db "begin; select private.lock_scheduling_teacher('$($users.teacher)');" $gateName -KeepInputOpen
  try {
    Wait-Condition "select exists(select 1 from pg_stat_activity where application_name='$gateName' and state='idle in transaction');" 'teacher gate'
    $leftSession = Start-Db $Left $leftName
    $rightSession = Start-Db $Right $rightName
    Wait-Condition @"
with recursive blocked(root,pid,path) as (
 select pid,pid,array[pid] from pg_stat_activity
 where application_name in('$leftName','$rightName') and wait_event_type='Lock'
 union all
 select b.root,p.pid,b.path||p.pid from blocked b
 cross join lateral unnest(pg_blocking_pids(b.pid)) p(pid)
 where not p.pid=any(b.path)
)
select count(distinct b.root)=2 from blocked b join pg_stat_activity g on g.pid=b.pid
where g.application_name='$gateName';
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

function Reverse-FulfillmentRenewal($Case) {
  $gateName = "$run-E-g"
  $convertName = "$run-E-convert"
  $eventName = "$run-E-event"
  $gate = Start-Db "begin; select private.lock_scheduling_teacher('$($users.teacher)');" $gateName -KeepInputOpen
  try {
    Wait-Condition "select exists(select 1 from pg_stat_activity where application_name='$gateName' and state='idle in transaction');" 'renewal reverse-order gate'
    $convert = Start-Db (Convert-Sql $Case) $convertName
    Wait-Condition "select exists(select 1 from pg_stat_activity where application_name='$convertName' and wait_event_type='Lock');" 'schedule-first renewal conversion'
    $event = Start-Db @"
begin;
select id from public.order_fulfillment_events where id='$($Case.Event)' for update;
select pg_sleep(2);
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claim.sub','',true);
select public.process_order_fulfillment_event('$($Case.Event)');
commit;
"@ $eventName
    Wait-Condition "select exists(select 1 from pg_stat_activity where application_name='$eventName' and wait_event='PgSleep');" 'event-first fulfillment session'
    $gate.Process.StandardInput.WriteLine('commit;')
    $gate.Process.StandardInput.Close()
    Must (Wait-Db $gate) 'release renewal reverse-order gate'
    Wait-Condition @"
select exists(
  select 1 from pg_stat_activity waiting
  join pg_stat_activity blocker on blocker.pid=any(pg_blocking_pids(waiting.pid))
  where waiting.application_name='$convertName' and blocker.application_name='$eventName'
);
"@ 'schedule-first conversion waiting for event-first fulfillment'
    return @((Wait-Db $event),(Wait-Db $convert))
  } finally {
    if (-not $gate.Process.HasExited) {
      try { $gate.Process.StandardInput.WriteLine('rollback;'); $gate.Process.StandardInput.Close() } catch { }
    }
  }
}

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
 union select id from public.fixed_cycle_renewals where teacher_user_id='$($users.teacher)'
 union select id from public.fixed_renewal_holds where student_user_id in($students)
 union select id from public.fixed_checkout_holds where teacher_user_id='$($users.teacher)'
 union select id from public.recurring_lesson_series where teacher_user_id='$($users.teacher)'
 union select id from public.fixed_entitlement_cycles where teacher_user_id='$($users.teacher)';
delete from public.audit_logs where actor_user_id in($allUsers) or target_id in(select id from cleanup_ids);
delete from public.fixed_renewal_holds where student_user_id in($students);
delete from public.fixed_cycle_renewals where teacher_user_id='$($users.teacher)';
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

function Uuid([string]$Sql) {
  $result=Invoke-Db $Sql;Must $result 'UUID operation'
  $matches=[regex]::Matches($result.Output,'[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}')
  Check ($matches.Count -gt 0) 'Missing UUID result'
  return $matches[$matches.Count-1].Value
}
function Pay([string]$Order) {
  Must (Invoke-Db (Auth $users.admin "select public.admin_confirm_cash_payment('$Order','$run-$Order','Renewal race payment');")) 'payment'
  $event=Value "select id from public.order_fulfillment_events where order_id='$Order';"
  Must (Invoke-Db (Service "select public.process_order_fulfillment_event('$event');")) 'fulfillment'
  $ent=Value "select id from public.entitlements where source_order_id='$Order';"
  return [pscustomobject]@{Event=$event;Entitlement=$ent}
}
function New-Case([string]$Name,[int]$Hour,[int]$Grace,[int]$Ttl) {
  Must (Invoke-Db (Auth $users.admin "select public.set_fixed_renewal_policy('$product',1,$Grace,$Ttl,0,'Race policy');")) 'policy'
  $order=Uuid (Auth $users.a "select public.create_checkout_order('$run',1,'$run-$Name-initial');")
  $paid=Pay $order
  $time=$Hour.ToString('00')+':00'
  $series=Uuid (Auth $users.teacher "select public.create_recurring_lesson_series('$($users.a)','$($users.teacher)','$relationshipA',null,extract(dow from current_date+7)::smallint,'$time','Asia/Taipei',50::smallint,current_date,null,'Renewal race series');")
  $cycle=Uuid (Service "select public.attach_fixed_entitlement_cycle('$series','$($paid.Entitlement)','$($paid.Event)','Race first cycle');")
  $renewal=Uuid (Service "select public.open_fixed_cycle_renewal('$cycle','Race window');")
  $hold=Uuid (Auth $users.a "select public.claim_fixed_renewal_hold('$renewal','$run','$run-$Name-renewal');")
  $renewOrder=Value "select order_id from public.fixed_renewal_holds where id='$hold';"
  $next=Pay $renewOrder
  $booking=Uuid (Auth $users.teacher "select public.materialize_recurring_lesson_occurrence('$series',current_date+7,'$($paid.Entitlement)','$run-$Name-booking');")
  # Fixture time travel only. Actual completion still goes through Booking/Credit
  # and 4A Cycle authority, not direct completed-cycle inserts.
  Must (Invoke-Db "begin;update public.lessons set starts_at=now()-interval '2 days'-make_interval(hours=>$Hour),ends_at=now()-interval '2 days'-make_interval(hours=>$Hour)+interval '50 minutes' where fixed_cycle_id='$cycle';update public.bookings b set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where b.lesson_id=l.id and b.id='$booking';update public.recurring_lesson_occurrences o set starts_at=l.starts_at,ends_at=l.ends_at from public.lessons l where o.lesson_id=l.id and o.fixed_cycle_id='$cycle';commit;") 'fixture clock'
  Must (Invoke-Db (Auth $users.teacher "select public.complete_lesson_booking('$booking','Actual race fixture completion','','','','');select public.complete_fixed_entitlement_cycle('$cycle','Actual value complete');")) 'actual completion'
  return [pscustomobject]@{Name=$Name;Hour=$Hour;Time=$time;Series=$series;Cycle=$cycle;Renewal=$renewal;Hold=$hold;Entitlement=$next.Entitlement;Event=$next.Event}
}
function Convert-Sql($Case) {
  Service "select public.convert_fixed_renewal('$($Case.Renewal)','$($Case.Hold)','$($Case.Entitlement)','$($Case.Event)','Concurrent renewal');"
}
function Release-Sql($Case) {
  Service "select public.release_expired_fixed_renewal('$($Case.Renewal)','renewal_expired');"
}
function Expect-Conversion($Result,[string]$State) {
  Must $Result 'renewal conversion'
  $json=@($Result.Output -split "`r?`n" | Where-Object { $_.StartsWith('{') })[-1] | ConvertFrom-Json
  Check ($json.status -eq $State) "Expected $State, got $($Result.Output)"
}
function Check-Case($Case,[string]$State,[int]$Cycles) {
  Check ((Value "select state::text from public.fixed_cycle_renewals where id='$($Case.Renewal)';") -eq $State) 'Unexpected renewal state'
  Count "select count(*) from public.fixed_entitlement_cycles where series_id='$($Case.Series)';" $Cycles 'cycle count'
  Count "select count(*) from public.fixed_entitlement_cycles where series_id='$($Case.Series)' and sequence_number=2;" ($Cycles-1) 'unique next cycle'
  Count "select count(*) from public.audit_logs where action='fixed_renewal.renewed' and target_id='$($Case.Renewal)';" ($Cycles-1) 'unique renewal audit'
  Count "select count(*) from public.lesson_credit_reservations where entitlement_id='$($Case.Entitlement)';" 0 'renewal does not reserve credit'
  Count "select count(*) from public.lesson_credit_ledger where entitlement_id='$($Case.Entitlement)' and entry_type<>'allocation';" 0 'renewal does not spend credit'
}
function New-Claim-Sql($Case) {
  Auth $users.b "select public.claim_fixed_checkout_hold('$($users.teacher)','$relationshipB','$run',extract(dow from current_date+7)::smallint,'$($Case.Time)','Asia/Taipei',current_date+7,null,'$run-$($Case.Name)-new-owner');"
}

try {
  Check ((Value 'select host(inet_server_addr());') -in @('127.0.0.1','::1')) 'Local loopback database required'
  Check ((Value "select to_regclass('public.fixed_cycle_renewals') is not null;") -eq 't') 'Apply local renewal migration first'
  $ready=$true
  Must (Invoke-Db @"
begin;
insert into auth.users(id,email)values('$($users.a)','$run-a@example.invalid'),('$($users.b)','$run-b@example.invalid'),('$($users.teacher)','$run-teacher@example.invalid'),('$($users.admin)','$run-admin@example.invalid');
insert into public.user_roles(user_id,role)values('$($users.teacher)','teacher'),('$($users.admin)','admin');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url)values('$($users.teacher)','$run','Renewal race','active',true,array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij');
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)values('$relationshipA','$($users.a)','$($users.teacher)','active','online'),('$relationshipB','$($users.b)','$($users.teacher)','active','online');
insert into public.teacher_scheduling_settings(teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes)values('$($users.teacher)','Asia/Taipei',0,60,10);
insert into public.teacher_availability_rules(teacher_user_id,weekday,local_start_time,local_end_time,timezone,effective_from,created_by)select '$($users.teacher)',d,'00:00','23:59','Asia/Taipei',current_date,'$($users.teacher)' from generate_series(0,6)d;
insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,is_public,is_purchasable,published_at)values('$product','lesson_package','active','$run','Renewal race package','TWD',800,'platform',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,booking_mode_eligibility,fixed_checkout_hold_seconds)values('$product',1,12,'months',50,'fixed',600);
commit;
"@) 'setup'
  $caseA=New-Case 'A' 8 0 600
  $race=Race 'A' (Release-Sql $caseA) (Convert-Sql $caseA)
  Must $race[0] 'release control';Expect-Conversion $race[1] 'renewed';Check-Case $caseA 'renewed' 2
  Write-Host 'A PASS: valid renewal hold protects deadline conversion from release'

  $caseB=New-Case 'B' 10 0 2
  Wait-Condition "select expires_at<clock_timestamp() from public.fixed_renewal_holds where id='$($caseB.Hold)';" 'renewal hold expiry'
  $race=Race 'B' (Release-Sql $caseB) (Convert-Sql $caseB)
  Must $race[0] 'expired release';Expect-Conversion $race[1] 'rejected';Check-Case $caseB 'released' 1
  $race=Race 'late' (Convert-Sql $caseB) (New-Claim-Sql $caseB)
  Expect-Conversion $race[0] 'rejected';Must $race[1] 'B legal claim'
  $bHold=Value "select id from public.fixed_checkout_holds where student_user_id='$($users.b)' and idempotency_key='$run-B-new-owner';"
  $bOrder=Value "select order_id from public.fixed_checkout_holds where id='$bHold';";$bPaid=Pay $bOrder
  Must (Invoke-Db (Service "select public.convert_fixed_checkout_hold('$bHold','$($bPaid.Entitlement)','$($bPaid.Event)','B legal ownership');")) 'B ownership conversion'
  Expect-Conversion (Invoke-Db (Convert-Sql $caseB)) 'rejected'
  Count "select count(*) from public.fixed_checkout_holds where id='$bHold' and status='converted';" 1 'B remains converted'
  Count "select count(*) from public.entitlements where id='$($caseB.Entitlement)';" 1 'A paid entitlement survives'
  Write-Host 'B PASS: late A cannot displace B after reassignment'

  $caseC=New-Case 'C' 12 3600 600
  $race=Race 'retry' (Convert-Sql $caseC) (Convert-Sql $caseC)
  Expect-Conversion $race[0] 'renewed';Expect-Conversion $race[1] 'renewed';Check-Case $caseC 'renewed' 2
  Write-Host 'C PASS: concurrent fulfillment retry attaches one next cycle'

  $caseD=New-Case 'D' 14 0 2
  Wait-Condition "select expires_at<clock_timestamp() from public.fixed_renewal_holds where id='$($caseD.Hold)';" 'second hold expiry'
  $race=Race 'expiry' (Release-Sql $caseD) (New-Claim-Sql $caseD)
  Must $race[0] 'expiry release'
  if($race[1].ExitCode -ne 0){Check ($race[1].Output -match 'P0001:\s+FIXED_SLOT_UNAVAILABLE') 'Unexpected claim error';Must (Invoke-Db (New-Claim-Sql $caseD)) 'retry after authoritative release'}
  Check-Case $caseD 'released' 1
  Count "select count(*) from public.fixed_checkout_holds where idempotency_key='$run-D-new-owner' and status='active' and expires_at>clock_timestamp();" 1 'one effective holder'
  Count "select count(*) from public.recurring_lesson_series where id='$($caseD.Series)' and status='active';" 0 'old priority released'
  Write-Host 'D PASS: hold expiry/release vs new claim has one effective holder'

  $caseE=New-Case 'E' 16 3600 600
  $race=Reverse-FulfillmentRenewal $caseE
  Must $race[0] 'event-first fulfillment retry';Expect-Conversion $race[1] 'renewed';Check-Case $caseE 'renewed' 2
  Count "select count(*) from public.entitlements where source_fulfillment_event_id='$($caseE.Event)';" 1 'one renewal entitlement'
  Count "select count(*) from public.fixed_renewal_holds where id='$($caseE.Hold)' and status='converted';" 1 'renewal hold converted once'
  Write-Host 'E PASS P2-2: event-first fulfillment vs schedule-first renewal has no reverse edge or partial state'
  $passed=$true
} finally {
  try {
    if($ready){Must (Invoke-Db "select pg_terminate_backend(pid)from pg_stat_activity where application_name like '$run-%' and pid<>pg_backend_pid();") 'stop test sessions'}
  } finally {
    try {
      if($ready){Must (Invoke-Db $cleanup) 'cleanup';Count "select count(*)from public.fixed_cycle_renewals where teacher_user_id='$($users.teacher)';" 0 'renewal cleanup';Count "select count(*)from auth.users where id in($allUsers);" 0 'user cleanup';Write-Host 'CLEANUP PASS'}
    } finally {foreach($session in $sessions){if(-not $session.Process.HasExited){$session.Process.Kill()};$session.Process.Dispose()}}
  }
}
if($passed){Write-Host 'P2-2 FIXED RENEWAL LOCK-ORDER PASS: A/B/C/D/E; 40P01=0 23505=0 23P01=0 unexpected integrity=0 partial=0 fixture residue=0'}
