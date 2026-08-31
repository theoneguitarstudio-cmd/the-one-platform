[CmdletBinding()]
param(
  [string]$ContainerName,
  [ValidateRange(1, 100)]
  [int]$StressRounds = 20
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$docker = (Get-Command docker -ErrorAction Stop).Source

if (-not $ContainerName) {
  $containers = @(& $docker ps --format '{{.Names}}' | Where-Object { $_ -like 'supabase_db_*' })
  if ($containers.Count -ne 1) {
    throw "Expected exactly one running local Supabase database container; found $($containers.Count). Pass -ContainerName explicitly."
  }
  $ContainerName = $containers[0]
}

if (-not (@(& $docker ps --format '{{.Names}}') -contains $ContainerName)) {
  throw "Local Supabase database container '$ContainerName' is not running."
}

$ids = [ordered]@{
  student1  = '61000000-0000-0000-0000-000000000001'
  student2  = '61000000-0000-0000-0000-000000000002'
  student3  = '61000000-0000-0000-0000-000000000003'
  student4  = '61000000-0000-0000-0000-000000000004'
  student5  = '61000000-0000-0000-0000-000000000005'
  student6  = '61000000-0000-0000-0000-000000000006'
  student7  = '61000000-0000-0000-0000-000000000007'
  student8  = '61000000-0000-0000-0000-000000000008'
  student9  = '61000000-0000-0000-0000-000000000009'
  student10 = '61000000-0000-0000-0000-000000000010'
  student11 = '61000000-0000-0000-0000-000000000011'
  student12 = '61000000-0000-0000-0000-000000000012'
  teacher1  = '62000000-0000-0000-0000-000000000001'
  teacher2  = '62000000-0000-0000-0000-000000000002'
  teacher3  = '62000000-0000-0000-0000-000000000003'
  teacher4  = '62000000-0000-0000-0000-000000000004'
  teacher5  = '62000000-0000-0000-0000-000000000005'
  teacher6  = '62000000-0000-0000-0000-000000000006'
  teacher7  = '62000000-0000-0000-0000-000000000007'
  teacher8  = '62000000-0000-0000-0000-000000000008'
  teacher9  = '62000000-0000-0000-0000-000000000009'
  teacher10 = '62000000-0000-0000-0000-000000000010'
  teacher11 = '62000000-0000-0000-0000-000000000011'
  admin1    = '63000000-0000-0000-0000-000000000001'
  admin2    = '63000000-0000-0000-0000-000000000002'
}

$relationshipIds = 1..18 | ForEach-Object { '64000000-0000-0000-0000-{0:d12}' -f $_ }
$orderIds = 1..14 | ForEach-Object { '65000000-0000-0000-0000-{0:d12}' -f $_ }
$lessonIds = 1..14 | ForEach-Object { '66000000-0000-0000-0000-{0:d12}' -f $_ }
$allUserIdsSql = ($ids.Values | ForEach-Object { "'$_'::uuid" }) -join ', '

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-LocalPsql {
  param([Parameter(Mandatory)][string]$Sql)

  $output = & $docker exec $ContainerName psql -X -U postgres -d postgres `
    -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -At -c $Sql 2>&1 | Out-String
  [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output = $output.Trim()
  }
}

function Start-LocalPsql {
  param([Parameter(Mandatory)][string]$Sql)

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $docker
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in @(
    'exec', $ContainerName, 'psql', '-X', '-U', 'postgres', '-d', 'postgres',
    '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-At', '-c', $Sql
  )) {
    [void]$startInfo.ArgumentList.Add($argument)
  }

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  [void]$process.Start()
  return $process
}

function Wait-LocalPsql {
  param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)

  $stdoutTask = $Process.StandardOutput.ReadToEndAsync()
  $stderrTask = $Process.StandardError.ReadToEndAsync()
  if (-not $Process.WaitForExit(30000)) {
    $Process.Kill($true)
    throw 'Concurrent psql session exceeded 30 seconds.'
  }
  [pscustomobject]@{
    ExitCode = $Process.ExitCode
    Output = (($stdoutTask.Result + "`n" + $stderrTask.Result).Trim())
  }
}

function Invoke-Concurrent {
  param([Parameter(Mandatory)][string[]]$Sql)

  $processes = @($Sql | ForEach-Object { Start-LocalPsql -Sql $_ })
  return @($processes | ForEach-Object { Wait-LocalPsql -Process $_ })
}

function Authenticated-Sql {
  param(
    [Parameter(Mandatory)][string]$UserId,
    [Parameter(Mandatory)][string]$Body
  )

  return @"
begin;
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub', '$UserId', true);
set local statement_timeout = '15s';
$Body
commit;
"@
}

function Require-Success {
  param($Result, [string]$Context)
  if ($Result.ExitCode -ne 0) {
    throw "$Context failed: $($Result.Output)"
  }
}

function Require-Count {
  param([string]$Sql, [int]$Expected, [string]$Context)
  $result = Invoke-LocalPsql -Sql $Sql
  Require-Success $result $Context
  $actual = [int](($result.Output -split "`r?`n")[-1])
  if ($actual -ne $Expected) {
    throw "$Context expected $Expected, got $actual"
  }
}

function Get-LastUuid {
  param($Result)
  $matches = [regex]::Matches($Result.Output, '(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
  if ($matches.Count -eq 0) { return $null }
  return $matches[$matches.Count - 1].Value.ToLowerInvariant()
}

function Has-SqlState {
  param($Result, [string]$SqlState)
  return $Result.Output -match "(?m)$SqlState"
}

function Run-Case {
  param([int]$Number, [string]$Name, [scriptblock]$Body)
  try {
    $outcome = & $Body
    $results.Add([pscustomobject]@{
      Test = $Number
      Name = $Name
      Status = $outcome.Status
      Details = $outcome.Details
    })
  } catch {
    $results.Add([pscustomobject]@{
      Test = $Number
      Name = $Name
      Status = 'FAIL'
      Details = $_.Exception.Message
    })
  }
}

function New-RelationshipSql {
  param([string]$Id, [string]$Student, [string]$Teacher, [string]$Status = 'active')
  return "insert into public.student_teacher_relationships (id, student_user_id, teacher_user_id, relationship_status, preferred_mode) values ('$Id', '$Student', '$Teacher', '$Status', 'onsite');"
}

function New-OnsiteLessonSql {
  param(
    [string]$Id, [string]$Student, [string]$Teacher, [string]$Relationship,
    [string]$StartsAt, [string]$EndsAt, [string]$Status = 'scheduled'
  )
  return "insert into public.lessons (id, student_user_id, teacher_user_id, relationship_id, lesson_type, delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor, status, location_text) values ('$Id', '$Student', '$Teacher', '$Relationship', 'fixed', 'onsite', '$StartsAt', '$EndsAt', 50, 'Asia/Taipei', '$Status', 'Fake test room');"
}

function New-TrialFixtureSql {
  param(
    [string]$Order, [string]$Relationship, [string]$Lesson,
    [string]$Student, [string]$Teacher
  )
  return @"
insert into public.trial_orders (
  id, idempotency_key, student_user_id, teacher_user_id, delivery_mode,
  proposed_starts_at, timezone, price_twd, payment_status, confirmed_at,
  confirmed_by
) values (
  '$Order', 'epic3-concurrency-$($Order.Substring($Order.Length - 12))',
  '$Student', '$Teacher', 'online', now() - interval '60 minutes',
  'Asia/Taipei', 500, 'paid', now() - interval '70 minutes', '$($ids.admin1)'
);
insert into public.student_teacher_relationships (
  id, student_user_id, teacher_user_id, relationship_status, preferred_mode
) values ('$Relationship', '$Student', '$Teacher', 'trial', 'online');
insert into public.lessons (
  id, student_user_id, teacher_user_id, relationship_id, trial_order_id,
  lesson_type, delivery_mode, starts_at, ends_at, duration_minutes,
  timezone_anchor, status, meeting_provider, meeting_url
) values (
  '$Lesson', '$Student', '$Teacher', '$Relationship', '$Order', 'trial',
  'online', now() - interval '60 minutes', now() - interval '10 minutes',
  50, 'Asia/Taipei', 'scheduled', 'manual_google_meet',
  'https://meet.google.com/epic-test-room'
);
"@
}

$cleanupSql = @"
delete from public.assessments where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql);
delete from public.lesson_records where lesson_id in (select id from public.lessons where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql));
delete from public.lessons where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql);
delete from public.trial_orders where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql);
delete from public.student_teacher_relationships where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql);
delete from public.student_profiles where user_id in ($allUserIdsSql);
delete from public.teacher_stage_capabilities where teacher_profile_id in (select id from public.teacher_profiles where user_id in ($allUserIdsSql));
delete from public.teacher_specialties where teacher_profile_id in (select id from public.teacher_profiles where user_id in ($allUserIdsSql));
delete from public.teacher_public_profiles where teacher_profile_id in (select id from public.teacher_profiles where user_id in ($allUserIdsSql));
delete from public.teacher_profiles where user_id in ($allUserIdsSql);
delete from public.user_roles where user_id in ($allUserIdsSql);
delete from public.profiles where user_id in ($allUserIdsSql);
delete from auth.users where id in ($allUserIdsSql);
"@

$studentValues = 1..12 | ForEach-Object {
  "('$($ids["student$_"])', 'epic3-concurrency-student-$_@example.invalid')"
}
$teacherValues = 1..11 | ForEach-Object {
  "('$($ids["teacher$_"])', 'epic3-concurrency-teacher-$_@example.invalid')"
}
$adminValues = 1..2 | ForEach-Object {
  "('$($ids["admin$_"])', 'epic3-concurrency-admin-$_@example.invalid')"
}
$authValues = ($studentValues + $teacherValues + $adminValues) -join ",`n"
$teacherProfileValues = 1..11 | ForEach-Object {
  "('$($ids["teacher$_"])', 'epic3-concurrency-teacher-$_', 'Fake concurrency Teacher $_', 'active', true, array['online','onsite']::public.teaching_mode[], 500, 'manual_google_meet', 'https://meet.google.com/epic-test-room')"
}
$teacherRoleValues = 1..11 | ForEach-Object { "('$($ids["teacher$_"])', 'teacher')" }
$adminRoleValues = 1..2 | ForEach-Object { "('$($ids["admin$_"])', 'admin')" }

$setupSql = @"
$cleanupSql
insert into auth.users (id, email) values
$authValues;
update public.profiles set account_status = 'active', display_name = 'Epic 3 concurrency fixture'
where user_id in ($allUserIdsSql);
insert into public.user_roles (user_id, role) values
$(($teacherRoleValues + $adminRoleValues) -join ",`n")
on conflict do nothing;
insert into public.teacher_profiles (
  user_id, public_slug, bio, teaching_status, is_public, teaching_modes,
  trial_price_twd, default_meeting_provider, default_meeting_url
) values
$($teacherProfileValues -join ",`n");
"@

try {
  $setup = Invoke-LocalPsql -Sql $setupSql
  Require-Success $setup 'fixture setup'

  Run-Case 1 'Same idempotency key concurrent checkout' {
    $body = @"
select pg_sleep(0.5);
select public.request_trial_checkout(
  'epic3-concurrency-teacher-1', 'Fake goal', 'online', null,
  '2099-09-01 10:00:00+00', 'Asia/Taipei',
  'epic3-concurrency-same-key-0001'
);
"@
    $race = Invoke-Concurrent @(
      (Authenticated-Sql $ids.student1 $body),
      (Authenticated-Sql $ids.student1 $body)
    )
    $race | ForEach-Object { Require-Success $_ 'same-key checkout' }
    $returned = @($race | ForEach-Object { Get-LastUuid $_ })
    if (-not $returned[0] -or $returned[0] -ne $returned[1]) {
      throw "Concurrent calls returned different order IDs: $($returned -join ', ')"
    }
    Require-Count "select count(*) from public.trial_orders where student_user_id = '$($ids.student1)' and teacher_user_id = '$($ids.teacher1)';" 1 'same-key order count'
    Require-Count "select count(*) from public.student_teacher_relationships where student_user_id = '$($ids.student1)' and teacher_user_id = '$($ids.teacher1)';" 0 'checkout relationship count'
    Require-Count "select count(*) from public.lessons where student_user_id = '$($ids.student1)' and teacher_user_id = '$($ids.teacher1)';" 0 'checkout lesson count'
    @{ Status = 'PASS'; Details = "Two independent sessions returned $($returned[0]); one pending order, no relationship or lesson." }
  }

  Run-Case 2 'Same pair, different idempotency keys' {
    $bodyA = "select pg_sleep(0.5); select public.request_trial_checkout('epic3-concurrency-teacher-2', 'Fake goal A', 'online', null, '2099-09-02 10:00:00+00', 'Asia/Taipei', 'epic3-concurrency-different-key-a');"
    $bodyB = "select pg_sleep(0.5); select public.request_trial_checkout('epic3-concurrency-teacher-2', 'Fake goal B', 'online', null, '2099-09-02 11:00:00+00', 'Asia/Taipei', 'epic3-concurrency-different-key-b');"
    $race = Invoke-Concurrent @(
      (Authenticated-Sql $ids.student2 $bodyA),
      (Authenticated-Sql $ids.student2 $bodyB)
    )
    $successes = @($race | Where-Object ExitCode -eq 0)
    $rejections = @($race | Where-Object ExitCode -ne 0)
    if ($successes.Count -ne 1 -or $rejections.Count -ne 1 -or -not (Has-SqlState $rejections[0] '23514')) {
      throw "Expected one success and one 23514 rejection: $($race.Output -join ' | ')"
    }
    Require-Count "select count(*) from public.trial_orders where student_user_id = '$($ids.student2)' and teacher_user_id = '$($ids.teacher2)' and payment_status = 'pending';" 1 'different-key pending count'
    Require-Count "select count(*) from public.student_teacher_relationships where student_user_id = '$($ids.student2)' and teacher_user_id = '$($ids.teacher2)';" 0 'different-key relationship count'
    @{ Status = 'EXPECTED REJECTION'; Details = 'One request committed; the serialized loser received domain SQLSTATE 23514 with no partial state.' }
  }

  Run-Case 3 'Concurrent payment confirmation, same order' {
    $checkout = Invoke-LocalPsql -Sql (Authenticated-Sql $ids.student3 "select public.request_trial_checkout('epic3-concurrency-teacher-3', 'Fake payment goal', 'online', null, '2099-09-03 10:00:00+00', 'Asia/Taipei', 'epic3-concurrency-payment-order');")
    Require-Success $checkout 'payment fixture checkout'
    $orderId = Get-LastUuid $checkout
    $confirm = "select pg_sleep(0.5); select public.confirm_trial_payment('$orderId'::uuid, null);"
    $race = Invoke-Concurrent @(
      (Authenticated-Sql $ids.admin1 $confirm),
      (Authenticated-Sql $ids.admin2 $confirm)
    )
    $race | ForEach-Object { Require-Success $_ 'same-order confirmation' }
    $lessonIdsReturned = @($race | ForEach-Object { Get-LastUuid $_ })
    if ($lessonIdsReturned[0] -ne $lessonIdsReturned[1]) { throw 'Confirmations returned different lesson IDs.' }
    Require-Count "select count(*) from public.trial_orders where id = '$orderId' and payment_status = 'paid';" 1 'paid order count'
    Require-Count "select count(*) from public.student_teacher_relationships where student_user_id = '$($ids.student3)' and teacher_user_id = '$($ids.teacher3)' and relationship_status = 'trial';" 1 'payment relationship count'
    Require-Count "select count(*) from public.lessons where trial_order_id = '$orderId' and status = 'scheduled';" 1 'payment lesson count'
    @{ Status = 'PASS'; Details = "Both sessions returned lesson $($lessonIdsReturned[0]); row locking made confirmation idempotent." }
  }

  Run-Case 4 'Concurrent payment confirmation, same pair different orders' {
    $fixture = Invoke-LocalPsql -Sql @"
insert into public.trial_orders (id, idempotency_key, student_user_id, teacher_user_id, delivery_mode, proposed_starts_at, timezone, price_twd)
values
  ('$($orderIds[0])', 'epic3-concurrency-pair-order-a', '$($ids.student4)', '$($ids.teacher4)', 'online', '2099-09-04 10:00:00+00', 'Asia/Taipei', 500),
  ('$($orderIds[1])', 'epic3-concurrency-pair-order-b', '$($ids.student4)', '$($ids.teacher4)', 'online', '2099-09-04 10:00:00+00', 'Asia/Taipei', 500);
"@
    Require-Success $fixture 'two-order fixture'
    $race = Invoke-Concurrent @(
      (Authenticated-Sql $ids.admin1 "select pg_sleep(0.5); select public.confirm_trial_payment('$($orderIds[0])'::uuid, null);"),
      (Authenticated-Sql $ids.admin2 "select pg_sleep(0.5); select public.confirm_trial_payment('$($orderIds[1])'::uuid, null);")
    )
    $successes = @($race | Where-Object ExitCode -eq 0)
    $rejections = @($race | Where-Object ExitCode -ne 0)
    if ($successes.Count -ne 1 -or $rejections.Count -ne 1 -or -not (Has-SqlState $rejections[0] '23P01')) {
      throw "Expected one success and one GiST 23P01 rejection: $($race.Output -join ' | ')"
    }
    Require-Count "select count(*) from public.student_teacher_relationships where student_user_id = '$($ids.student4)' and teacher_user_id = '$($ids.teacher4)' and relationship_status = 'trial';" 1 'same-pair relationship count'
    Require-Count "select count(*) from public.lessons where student_user_id = '$($ids.student4)' and teacher_user_id = '$($ids.teacher4)';" 1 'same-pair lesson count'
    Require-Count "select count(*) from public.trial_orders o where o.id in ('$($orderIds[0])', '$($orderIds[1])') and o.payment_status = 'paid' and not exists (select 1 from public.lessons l where l.trial_order_id = o.id);" 0 'paid order without lesson count'
    Require-Count "select count(*) from public.trial_orders where id in ('$($orderIds[0])', '$($orderIds[1])') and payment_status = 'pending';" 1 'loser order rollback state'
    @{ Status = 'EXPECTED REJECTION'; Details = 'Pair advisory lock serialized confirmations; one committed and one rolled back on 23P01, leaving its pre-existing order pending.' }
  }

  Run-Case 5 'Teacher schedule collision race' {
    $stats = [ordered]@{ Success = 0; Collision = 0; Deadlock = 0; Unique = 0; Partial = 0 }
    foreach ($round in 1..$StressRounds) {
      $fixtureSql = @"
delete from public.lessons where trial_order_id in ('$($orderIds[6])', '$($orderIds[7])');
delete from public.student_teacher_relationships where
  (student_user_id in ('$($ids.student5)', '$($ids.student6)') and teacher_user_id = '$($ids.teacher5)');
delete from public.trial_orders where id in ('$($orderIds[6])', '$($orderIds[7])');
insert into public.trial_orders (id, idempotency_key, student_user_id, teacher_user_id, delivery_mode, proposed_starts_at, timezone, price_twd)
values
  ('$($orderIds[6])', 'epic3-concurrency-teacher-race-a', '$($ids.student5)', '$($ids.teacher5)', 'online', '2099-09-05 10:00:00+00', 'Asia/Taipei', 500),
  ('$($orderIds[7])', 'epic3-concurrency-teacher-race-b', '$($ids.student6)', '$($ids.teacher5)', 'online', '2099-09-05 10:20:00+00', 'Asia/Taipei', 500);
"@
      Require-Success (Invoke-LocalPsql $fixtureSql) "teacher collision fixture round $round"
      $race = Invoke-Concurrent @(
        (Authenticated-Sql $ids.admin1 "select pg_sleep(0.1); select public.confirm_trial_payment('$($orderIds[6])'::uuid, null);"),
        (Authenticated-Sql $ids.admin2 "select pg_sleep(0.1); select public.confirm_trial_payment('$($orderIds[7])'::uuid, null);")
      )
      $successes = @($race | Where-Object ExitCode -eq 0)
      $rejections = @($race | Where-Object ExitCode -ne 0)
      $stats.Success += $successes.Count
      $stats.Collision += @($rejections | Where-Object { Has-SqlState $_ '23P01' }).Count
      $stats.Deadlock += @($rejections | Where-Object { Has-SqlState $_ '40P01' }).Count
      $stats.Unique += @($rejections | Where-Object { Has-SqlState $_ '23505' }).Count
      if ($successes.Count -ne 1 -or $rejections.Count -ne 1) {
        throw "Teacher collision round $round had an unexpected outcome: $($race | ConvertTo-Json -Compress -Depth 3)"
      }
      $state = Invoke-LocalPsql "select (select count(*) from public.lessons where teacher_user_id='$($ids.teacher5)' and status='scheduled') || '|' || (select count(*) from public.student_teacher_relationships where teacher_user_id='$($ids.teacher5)') || '|' || (select count(*) from public.trial_orders where id in ('$($orderIds[6])','$($orderIds[7])') and payment_status='paid') || '|' || (select count(*) from public.trial_orders o where o.id in ('$($orderIds[6])','$($orderIds[7])') and o.payment_status='paid' and not exists (select 1 from public.lessons l where l.trial_order_id=o.id));"
      Require-Success $state "teacher collision state round $round"
      if (($state.Output -split "`r?`n")[-1] -ne '1|1|1|0') { $stats.Partial++ }
    }
    if ($stats.Deadlock -ne 0 -or $stats.Unique -ne 0 -or $stats.Partial -ne 0 -or $stats.Collision -ne $StressRounds) {
      throw "Teacher stress failed: rounds=$StressRounds success=$($stats.Success) 23P01=$($stats.Collision) 40P01=$($stats.Deadlock) 23505=$($stats.Unique) partial=$($stats.Partial)"
    }
    @{ Status = 'EXPECTED REJECTION'; Details = "rounds=$StressRounds success=$($stats.Success) 23P01=$($stats.Collision) 40P01=$($stats.Deadlock) 23505=$($stats.Unique) partial=$($stats.Partial)" }
  }

  Run-Case 6 'Student schedule collision race' {
    $stats = [ordered]@{ Success = 0; Collision = 0; Deadlock = 0; Unique = 0; Partial = 0 }
    foreach ($round in 1..$StressRounds) {
      $fixtureSql = @"
delete from public.lessons where trial_order_id in ('$($orderIds[8])', '$($orderIds[9])');
delete from public.student_teacher_relationships where
  student_user_id = '$($ids.student7)' and teacher_user_id in ('$($ids.teacher6)', '$($ids.teacher7)');
delete from public.trial_orders where id in ('$($orderIds[8])', '$($orderIds[9])');
insert into public.trial_orders (id, idempotency_key, student_user_id, teacher_user_id, delivery_mode, proposed_starts_at, timezone, price_twd)
values
  ('$($orderIds[8])', 'epic3-concurrency-student-race-a', '$($ids.student7)', '$($ids.teacher6)', 'online', '2099-09-06 10:00:00+00', 'Asia/Taipei', 500),
  ('$($orderIds[9])', 'epic3-concurrency-student-race-b', '$($ids.student7)', '$($ids.teacher7)', 'online', '2099-09-06 10:20:00+00', 'Asia/Taipei', 500);
"@
      Require-Success (Invoke-LocalPsql $fixtureSql) "student collision fixture round $round"
      $race = Invoke-Concurrent @(
        (Authenticated-Sql $ids.admin1 "select pg_sleep(0.1); select public.confirm_trial_payment('$($orderIds[8])'::uuid, null);"),
        (Authenticated-Sql $ids.admin2 "select pg_sleep(0.1); select public.confirm_trial_payment('$($orderIds[9])'::uuid, null);")
      )
      $successes = @($race | Where-Object ExitCode -eq 0)
      $rejections = @($race | Where-Object ExitCode -ne 0)
      $stats.Success += $successes.Count
      $stats.Collision += @($rejections | Where-Object { Has-SqlState $_ '23P01' }).Count
      $stats.Deadlock += @($rejections | Where-Object { Has-SqlState $_ '40P01' }).Count
      $stats.Unique += @($rejections | Where-Object { Has-SqlState $_ '23505' }).Count
      if ($successes.Count -ne 1 -or $rejections.Count -ne 1) {
        throw "Student collision round $round had an unexpected outcome: $($race | ConvertTo-Json -Compress -Depth 3)"
      }
      $state = Invoke-LocalPsql "select (select count(*) from public.lessons where student_user_id='$($ids.student7)' and status='scheduled') || '|' || (select count(*) from public.student_teacher_relationships where student_user_id='$($ids.student7)') || '|' || (select count(*) from public.trial_orders where id in ('$($orderIds[8])','$($orderIds[9])') and payment_status='paid') || '|' || (select count(*) from public.trial_orders o where o.id in ('$($orderIds[8])','$($orderIds[9])') and o.payment_status='paid' and not exists (select 1 from public.lessons l where l.trial_order_id=o.id));"
      Require-Success $state "student collision state round $round"
      if (($state.Output -split "`r?`n")[-1] -ne '1|1|1|0') { $stats.Partial++ }
    }
    if ($stats.Deadlock -ne 0 -or $stats.Unique -ne 0 -or $stats.Partial -ne 0 -or $stats.Collision -ne $StressRounds) {
      throw "Student stress failed: rounds=$StressRounds success=$($stats.Success) 23P01=$($stats.Collision) 40P01=$($stats.Deadlock) 23505=$($stats.Unique) partial=$($stats.Partial)"
    }
    @{ Status = 'EXPECTED REJECTION'; Details = "rounds=$StressRounds success=$($stats.Success) 23P01=$($stats.Collision) 40P01=$($stats.Deadlock) 23505=$($stats.Unique) partial=$($stats.Partial)" }
  }

  Run-Case 7 'Adjacent lesson ranges' {
    $fixtureSql = (New-RelationshipSql $relationshipIds[4] $ids.student8 $ids.teacher8) + (New-RelationshipSql $relationshipIds[5] $ids.student8 $ids.teacher9)
    Require-Success (Invoke-LocalPsql $fixtureSql) 'adjacent relationships'
    $race = Invoke-Concurrent @(
      "begin; select pg_sleep(0.5); $(New-OnsiteLessonSql $lessonIds[4] $ids.student8 $ids.teacher8 $relationshipIds[4] '2099-09-07 10:00:00+00' '2099-09-07 10:50:00+00') commit;",
      "begin; select pg_sleep(0.5); $(New-OnsiteLessonSql $lessonIds[5] $ids.student8 $ids.teacher9 $relationshipIds[5] '2099-09-07 10:50:00+00' '2099-09-07 11:40:00+00') commit;"
    )
    $race | ForEach-Object { Require-Success $_ 'adjacent lesson insertion' }
    Require-Count "select count(*) from public.lessons where student_user_id = '$($ids.student8)' and status = 'scheduled';" 2 'adjacent lesson count'
    @{ Status = 'PASS'; Details = 'Both [start,end) ranges committed; the shared 10:50 boundary was not treated as overlap.' }
  }

  Run-Case 8 'Cancel then concurrent rebook' {
    $baseFixture = (New-RelationshipSql $relationshipIds[6] $ids.student9 $ids.teacher10) + (New-OnsiteLessonSql $lessonIds[6] $ids.student9 $ids.teacher10 $relationshipIds[6] '2099-09-08 10:00:00+00' '2099-09-08 10:50:00+00' 'admin_cancelled')
    Require-Success (Invoke-LocalPsql $baseFixture) 'cancel/rebook base fixture'
    $stats = [ordered]@{ Success = 0; Collision = 0; Deadlock = 0; Unique = 0; Partial = 0 }
    foreach ($round in 1..$StressRounds) {
      $fixtureSql = @"
delete from public.lessons where trial_order_id in ('$($orderIds[10])', '$($orderIds[11])');
delete from public.student_teacher_relationships where
  student_user_id in ('$($ids.student10)', '$($ids.student11)') and teacher_user_id='$($ids.teacher10)';
delete from public.trial_orders where id in ('$($orderIds[10])', '$($orderIds[11])');
insert into public.trial_orders (id, idempotency_key, student_user_id, teacher_user_id, delivery_mode, proposed_starts_at, timezone, price_twd)
values
  ('$($orderIds[10])', 'epic3-concurrency-rebook-race-a', '$($ids.student10)', '$($ids.teacher10)', 'online', '2099-09-08 10:00:00+00', 'Asia/Taipei', 500),
  ('$($orderIds[11])', 'epic3-concurrency-rebook-race-b', '$($ids.student11)', '$($ids.teacher10)', 'online', '2099-09-08 10:00:00+00', 'Asia/Taipei', 500);
"@
      Require-Success (Invoke-LocalPsql $fixtureSql) "cancel/rebook fixture round $round"
      $race = Invoke-Concurrent @(
        (Authenticated-Sql $ids.admin1 "select pg_sleep(0.1); select public.confirm_trial_payment('$($orderIds[10])'::uuid, null);"),
        (Authenticated-Sql $ids.admin2 "select pg_sleep(0.1); select public.confirm_trial_payment('$($orderIds[11])'::uuid, null);")
      )
      $successes = @($race | Where-Object ExitCode -eq 0)
      $rejections = @($race | Where-Object ExitCode -ne 0)
      $stats.Success += $successes.Count
      $stats.Collision += @($rejections | Where-Object { Has-SqlState $_ '23P01' }).Count
      $stats.Deadlock += @($rejections | Where-Object { Has-SqlState $_ '40P01' }).Count
      $stats.Unique += @($rejections | Where-Object { Has-SqlState $_ '23505' }).Count
      if ($successes.Count -ne 1 -or $rejections.Count -ne 1) {
        throw "Rebook round $round had an unexpected outcome: $($race | ConvertTo-Json -Compress -Depth 3)"
      }
      $state = Invoke-LocalPsql "select (select count(*) from public.lessons where id='$($lessonIds[6])' and status='admin_cancelled') || '|' || (select count(*) from public.lessons where trial_order_id in ('$($orderIds[10])','$($orderIds[11])') and status='scheduled') || '|' || (select count(*) from public.trial_orders where id in ('$($orderIds[10])','$($orderIds[11])') and payment_status='paid') || '|' || (select count(*) from public.trial_orders o where o.id in ('$($orderIds[10])','$($orderIds[11])') and o.payment_status='paid' and not exists (select 1 from public.lessons l where l.trial_order_id=o.id));"
      Require-Success $state "rebook state round $round"
      if (($state.Output -split "`r?`n")[-1] -ne '1|1|1|0') { $stats.Partial++ }
    }
    if ($stats.Deadlock -ne 0 -or $stats.Unique -ne 0 -or $stats.Partial -ne 0 -or $stats.Collision -ne $StressRounds) {
      throw "Rebook stress failed: rounds=$StressRounds success=$($stats.Success) 23P01=$($stats.Collision) 40P01=$($stats.Deadlock) 23505=$($stats.Unique) partial=$($stats.Partial)"
    }
    @{ Status = 'EXPECTED REJECTION'; Details = "rounds=$StressRounds success=$($stats.Success) 23P01=$($stats.Collision) 40P01=$($stats.Deadlock) 23505=$($stats.Unique) partial=$($stats.Partial)" }
  }

  Run-Case 9 'Concurrent trial completion' {
    Require-Success (Invoke-LocalPsql (New-TrialFixtureSql $orderIds[2] $relationshipIds[9] $lessonIds[9] $ids.student9 $ids.teacher9)) 'completion fixture'
    $completion = @"
select pg_sleep(0.5);
select public.complete_trial_lesson(
  '$($lessonIds[9])'::uuid, 1::smallint, 'Visible', 'Private',
  'Performance', 'Next', 'Homework',
  'one_to_one'::public.recommendation_type, 'Assessment'
);
"@
    $race = Invoke-Concurrent @(
      (Authenticated-Sql $ids.teacher9 $completion),
      (Authenticated-Sql $ids.teacher9 $completion)
    )
    $race | ForEach-Object { Require-Success $_ 'concurrent completion' }
    $assessmentIds = @($race | ForEach-Object { Get-LastUuid $_ })
    if ($assessmentIds[0] -ne $assessmentIds[1]) { throw 'Concurrent completion returned different assessment IDs.' }
    Require-Count "select count(*) from public.lessons where id = '$($lessonIds[9])' and status = 'completed';" 1 'completed lesson count'
    Require-Count "select count(*) from public.student_teacher_relationships where id = '$($relationshipIds[9])' and relationship_status = 'awaiting_conversion';" 1 'completion relationship state'
    Require-Count "select count(*) from public.lesson_records where lesson_id = '$($lessonIds[9])';" 1 'completion record count'
    Require-Count "select count(*) from public.assessments where lesson_id = '$($lessonIds[9])';" 1 'completion assessment count'
    @{ Status = 'PASS'; Details = "Lesson row lock serialized both sessions; both returned assessment $($assessmentIds[0]) without duplication." }
  }

  Run-Case 10 'Completion versus cancellation race' {
    Require-Success (Invoke-LocalPsql (New-TrialFixtureSql $orderIds[3] $relationshipIds[10] $lessonIds[10] $ids.student10 $ids.teacher8)) 'completion/cancel fixture'
    $completion = Authenticated-Sql $ids.teacher8 "select pg_sleep(0.5); select public.complete_trial_lesson('$($lessonIds[10])'::uuid, 1::smallint, 'Visible', 'Private', 'Performance', 'Next', 'Homework', 'one_to_one'::public.recommendation_type, 'Assessment');"
    $cancellation = Authenticated-Sql $ids.admin1 "select pg_sleep(0.5); select public.admin_cancel_trial_lesson('$($lessonIds[10])'::uuid);"
    $race = Invoke-Concurrent @($completion, $cancellation)
    $state = Invoke-LocalPsql "select l.status::text || '|' || r.relationship_status::text || '|' || (select count(*) from public.lesson_records where lesson_id=l.id) || '|' || (select count(*) from public.assessments where lesson_id=l.id) from public.lessons l join public.student_teacher_relationships r on r.id=l.relationship_id where l.id='$($lessonIds[10])';"
    Require-Success $state 'completion/cancel state read'
    $validStates = @('completed|awaiting_conversion|1|1', 'admin_cancelled|trial|0|0')
    $finalState = ($state.Output -split "`r?`n")[-1]
    if ($validStates -notcontains $finalState) { throw "Invalid completion/cancel partial state: $finalState" }
    if (@($race | Where-Object ExitCode -eq 0).Count -ne 1) { throw "Expected exactly one mutation winner: $($race.Output -join ' | ')" }
    @{ Status = 'ARCHITECTURE RISK'; Details = "Observed $finalState. Row locking prevents partial state, but the domain has no explicit winner rule; lock acquisition timing decides completion versus cancellation." }
  }

  Run-Case 11 'Role revocation during mutation' {
    Require-Success (Invoke-LocalPsql (New-TrialFixtureSql $orderIds[4] $relationshipIds[11] $lessonIds[11] $ids.student11 $ids.teacher11)) 'role revocation fixture'
    $blocker = Start-LocalPsql "begin; select id from public.lessons where id='$($lessonIds[11])' for update; select pg_sleep(3); commit;"
    Start-Sleep -Milliseconds 350
    $completion = Start-LocalPsql (Authenticated-Sql $ids.teacher11 "select public.complete_trial_lesson('$($lessonIds[11])'::uuid, 1::smallint, 'Visible', 'Private', 'Performance', 'Next', 'Homework', 'one_to_one'::public.recommendation_type, 'Assessment');")
    Start-Sleep -Milliseconds 500
    $revocation = Invoke-LocalPsql "delete from public.user_roles where user_id='$($ids.teacher11)' and role='teacher';"
    Require-Success $revocation 'role revocation'
    $blockerResult = Wait-LocalPsql $blocker
    $completionResult = Wait-LocalPsql $completion
    Require-Success $blockerResult 'role-revocation blocker'
    Require-Success $completionResult 'in-flight completion'
    Require-Count "select count(*) from public.user_roles where user_id='$($ids.teacher11)' and role='teacher';" 0 'revoked role count'
    Require-Count "select count(*) from public.lessons where id='$($lessonIds[11])' and status='completed';" 1 'in-flight completion state'
    @{ Status = 'ARCHITECTURE RISK'; Details = 'Authorization passed before the lesson lock wait; revoking the role did not cancel the already-authorized in-flight transaction. New calls are denied, but revocation is not instantaneous for an active RPC.' }
  }

  Run-Case 12 'Deadlock observation and reverse lock probe' {
    # Raw locks deliberately use a privileged test connection. Public clients have no
    # direct mutation grants; production RPC races are covered by tests 1-11.
    $fixtureSql = (New-RelationshipSql $relationshipIds[12] $ids.student12 $ids.teacher6) + (New-OnsiteLessonSql $lessonIds[12] $ids.student12 $ids.teacher6 $relationshipIds[12] '2099-09-12 10:00:00+00' '2099-09-12 10:50:00+00') + @"
insert into public.trial_orders (id, idempotency_key, student_user_id, teacher_user_id, delivery_mode, proposed_starts_at, timezone, price_twd)
values ('$($orderIds[5])', 'epic3-concurrency-deadlock-order', '$($ids.student12)', '$($ids.teacher6)', 'onsite', '2099-09-12 12:00:00+00', 'Asia/Taipei', 500);
"@
    Require-Success (Invoke-LocalPsql $fixtureSql) 'deadlock fixture'
    $race = Invoke-Concurrent @(
      "begin; set local deadlock_timeout='100ms'; set local statement_timeout='10s'; select id from public.trial_orders where id='$($orderIds[5])' for update; select pg_sleep(0.5); select id from public.lessons where id='$($lessonIds[12])' for update; commit;",
      "begin; set local deadlock_timeout='100ms'; set local statement_timeout='10s'; select id from public.lessons where id='$($lessonIds[12])' for update; select pg_sleep(0.5); select id from public.trial_orders where id='$($orderIds[5])' for update; commit;"
    )
    $deadlocks = @($race | Where-Object { $_.ExitCode -ne 0 -and (Has-SqlState $_ '40P01') })
    $survivors = @($race | Where-Object ExitCode -eq 0)
    if ($deadlocks.Count -ne 1 -or $survivors.Count -ne 1) {
      throw "Reverse lock probe did not yield one detected 40P01 and one survivor: $($race.Output -join ' | ')"
    }
    $productionDeadlockObserved = @(
      $results | Where-Object {
        $_.Test -le 11 -and (
          $_.Details -match '40P01=([1-9][0-9]*)' -or
          $_.Details -match 'exposed transient SQLSTATE 40P01'
        )
      }
    ).Count -gt 0
    if ($productionDeadlockObserved) {
      @{ Status = 'ARCHITECTURE RISK'; Details = 'Intentional privileged inverse row-lock order produced one prompt 40P01 and one survivor. A production confirm RPC collision also exposed 40P01 in this run; schedule-resource lock ordering or bounded server retry is required.' }
    } else {
      @{ Status = 'PASS'; Details = 'Intentional privileged inverse row-lock order produced one prompt 40P01 and one survivor. No production RPC deadlock occurred in this run; repeated runs are required because GiST deadlocks are timing-dependent.' }
    }
  }

  Run-Case 13 'Reschedule versus confirmation collision race' {
    $fixtureSql = @"
insert into public.trial_orders (
  id, idempotency_key, student_user_id, teacher_user_id, delivery_mode,
  proposed_starts_at, timezone, price_twd, payment_status, confirmed_at,
  confirmed_by
) values (
  '$($orderIds[13])', 'epic3-concurrency-reschedule-source',
  '$($ids.student12)', '$($ids.teacher7)', 'online',
  '2099-09-13 08:00:00+00', 'Asia/Taipei', 500, 'paid', now(),
  '$($ids.admin1)'
);
insert into public.student_teacher_relationships (
  id, student_user_id, teacher_user_id, relationship_status, preferred_mode
) values (
  '$($relationshipIds[13])', '$($ids.student12)', '$($ids.teacher7)',
  'trial', 'online'
);
insert into public.lessons (
  id, student_user_id, teacher_user_id, relationship_id, trial_order_id,
  lesson_type, delivery_mode, starts_at, ends_at, duration_minutes,
  timezone_anchor, status, meeting_provider, meeting_url
) values (
  '$($lessonIds[13])', '$($ids.student12)', '$($ids.teacher7)',
  '$($relationshipIds[13])', '$($orderIds[13])', 'trial', 'online',
  '2099-09-13 08:00:00+00', '2099-09-13 08:50:00+00', 50,
  'Asia/Taipei', 'scheduled', 'manual_google_meet',
  'https://meet.google.com/epic-test-room'
);
insert into public.trial_orders (
  id, idempotency_key, student_user_id, teacher_user_id, delivery_mode,
  proposed_starts_at, timezone, price_twd
) values (
  '$($orderIds[12])', 'epic3-concurrency-reschedule-target',
  '$($ids.student6)', '$($ids.teacher7)', 'online',
  '2099-09-13 10:20:00+00', 'Asia/Taipei', 500
);
"@
    Require-Success (Invoke-LocalPsql $fixtureSql) 'reschedule collision fixture'
    $race = Invoke-Concurrent @(
      (Authenticated-Sql $ids.admin1 "select pg_sleep(0.1); select public.admin_reschedule_trial_lesson('$($lessonIds[13])'::uuid, '2099-09-13 10:00:00+00'::timestamptz);"),
      (Authenticated-Sql $ids.admin2 "select pg_sleep(0.1); select public.confirm_trial_payment('$($orderIds[12])'::uuid, null);")
    )
    $successes = @($race | Where-Object ExitCode -eq 0)
    $rejections = @($race | Where-Object ExitCode -ne 0)
    $deadlocks = @($rejections | Where-Object { Has-SqlState $_ '40P01' })
    $uniqueViolations = @($rejections | Where-Object { Has-SqlState $_ '23505' })
    $collisions = @($rejections | Where-Object { Has-SqlState $_ '23P01' })
    if ($successes.Count -ne 1 -or $collisions.Count -ne 1 -or $deadlocks.Count -ne 0 -or $uniqueViolations.Count -ne 0) {
      throw "Reschedule collision had an unexpected outcome: $($race | ConvertTo-Json -Compress -Depth 3)"
    }
    $state = Invoke-LocalPsql "select (select count(*) from public.lessons where teacher_user_id='$($ids.teacher7)' and status='scheduled' and tstzrange(starts_at,ends_at,'[)') && tstzrange('2099-09-13 10:00:00+00','2099-09-13 11:10:00+00','[)')) || '|' || (select count(*) from public.lessons where id='$($lessonIds[13])' and status='scheduled' and starts_at in ('2099-09-13 08:00:00+00','2099-09-13 10:00:00+00')) || '|' || (select count(*) from public.trial_orders o where o.id='$($orderIds[12])' and o.payment_status='paid' and not exists (select 1 from public.lessons l where l.trial_order_id=o.id));"
    Require-Success $state 'reschedule collision state'
    $finalState = ($state.Output -split "`r?`n")[-1]
    if ($finalState -ne '1|1|0') { throw "Reschedule collision left invalid state: $finalState" }
    @{ Status = 'EXPECTED REJECTION'; Details = 'One target-slot mutation committed, the loser received 23P01, the original lesson remained valid, and no paid-without-lesson state was created.' }
  }
} finally {
  $cleanup = Invoke-LocalPsql -Sql $cleanupSql
  if ($cleanup.ExitCode -ne 0) {
    $results.Add([pscustomobject]@{
      Test = 99
      Name = 'Cleanup'
      Status = 'FAIL'
      Details = $cleanup.Output
    })
  } else {
    $remaining = Invoke-LocalPsql -Sql @"
select
  (select count(*) from auth.users where id in ($allUserIdsSql))
  + (select count(*) from public.profiles where user_id in ($allUserIdsSql))
  + (select count(*) from public.user_roles where user_id in ($allUserIdsSql))
  + (select count(*) from public.student_profiles where user_id in ($allUserIdsSql))
  + (select count(*) from public.teacher_profiles where user_id in ($allUserIdsSql))
  + (select count(*) from public.student_teacher_relationships where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql))
  + (select count(*) from public.trial_orders where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql))
  + (select count(*) from public.lessons where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql))
  + (select count(*) from public.assessments where student_user_id in ($allUserIdsSql) or teacher_user_id in ($allUserIdsSql));
"@
    if ($remaining.ExitCode -ne 0 -or [int](($remaining.Output -split "`r?`n")[-1]) -ne 0) {
      $results.Add([pscustomobject]@{
        Test = 99
        Name = 'Cleanup'
        Status = 'FAIL'
        Details = "Fixture rows remain: $($remaining.Output)"
      })
    }
  }
}

$results | Sort-Object Test | ForEach-Object {
  "TEST $($_.Test) [$($_.Status)] $($_.Name): $($_.Details)"
}

$failed = @($results | Where-Object Status -eq 'FAIL')
if ($failed.Count -gt 0) {
  exit 1
}
