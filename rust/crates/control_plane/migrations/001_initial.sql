create table team (
    team_id text primary key,
    display_name text not null,
    description text not null
);

create table user_account (
    user_id text primary key,
    username text not null unique,
    display_name text not null,
    date_of_birth date null,
    sex text null,
    current_level text null,
    notes text null,
    first_name text null,
    last_name text null,
    email text null,
    google_subject text null,
    google_email text null,
    google_display_name text null,
    google_picture_url text null
);

create unique index user_account_email_unique_idx
    on user_account ((lower(email)))
    where email is not null;

create unique index user_account_google_subject_unique_idx
    on user_account (google_subject)
    where google_subject is not null;

create unique index user_account_google_email_unique_idx
    on user_account ((lower(google_email)))
    where google_email is not null;

create table team_membership (
    team_id text not null references team(team_id) on delete cascade,
    user_id text not null references user_account(user_id) on delete cascade,
    role text not null,
    primary key (team_id, user_id)
);

create view learner_profile as
select
    ua.user_id as learner_id,
    tm.team_id,
    ua.user_id,
    ua.display_name,
    ua.date_of_birth,
    ua.sex,
    ua.current_level,
    coalesce(ua.notes, '') as notes
from user_account ua
join team_membership tm on tm.user_id = ua.user_id
where
    tm.role = 'learner'
    and ua.date_of_birth is not null
    and ua.sex is not null
    and ua.current_level is not null;

create table assignment (
    assignment_id text primary key,
    learner_id text not null references user_account(user_id) on delete cascade,
    playlist_id text not null,
    title text not null,
    start_date date not null,
    end_date date not null,
    status text not null,
    total_sessions integer not null,
    completed_sessions integer not null,
    created_at timestamptz not null
);

create table session (
    session_id text primary key,
    assignment_id text not null references assignment(assignment_id) on delete cascade,
    learner_id text not null references user_account(user_id) on delete cascade,
    authored_session_id text not null,
    title text not null,
    scheduled_date date not null,
    status text not null check (status in ('scheduled', 'active', 'completed')),
    day_offset integer not null,
    notes text not null default '',
    completed_at timestamptz null
);

create unique index session_assignment_authored_session_idx
    on session (assignment_id, authored_session_id);
create index session_assignment_idx on session (assignment_id, scheduled_date);
create index session_learner_idx on session (learner_id, scheduled_date);

create table session_material (
    session_material_id text primary key,
    session_id text not null references session(session_id) on delete cascade,
    title text not null,
    skill_id text not null,
    material_id text not null,
    status text not null check (status in ('scheduled', 'active', 'completed'))
);

create unique index session_material_unique_ref_idx
    on session_material (session_id, material_id, skill_id);

create table evidence (
    evidence_id text primary key,
    session_id text not null references session(session_id) on delete cascade,
    learner_id text not null references user_account(user_id) on delete cascade,
    score double precision not null,
    max_score double precision not null,
    duration_minutes integer not null,
    notes text not null,
    recorded_at timestamptz not null
);

create index evidence_learner_idx on evidence (learner_id, recorded_at desc);
create index evidence_session_idx on evidence (session_id, recorded_at desc);

create table evidence_artifact (
    evidence_artifact_id text primary key,
    evidence_id text not null references evidence(evidence_id) on delete cascade,
    learner_id text not null references user_account(user_id) on delete cascade,
    kind text not null,
    storage_path text not null,
    summary text not null
);

create table learner_skill_progress (
    learner_id text not null references user_account(user_id) on delete cascade,
    skill_id text not null,
    status text not null check (status in ('needs_practice', 'ready_for_check', 'confirmed')),
    score_average double precision not null,
    last_score double precision not null,
    total_evidence integer not null,
    last_evidence_at timestamptz null,
    primary key (learner_id, skill_id)
);

create table review_item (
    review_item_id text primary key,
    learner_id text not null references user_account(user_id) on delete cascade,
    skill_ids jsonb not null,
    session_id text null references session(session_id) on delete set null,
    session_material_id text null references session_material(session_material_id) on delete set null,
    material_id text not null,
    evidence_material_id text not null,
    reason text not null,
    fact_focus jsonb not null default '[]'::jsonb,
    family_focus jsonb not null default '[]'::jsonb,
    due_date date not null,
    review_step integer not null default 0 check (review_step between 0 and 2),
    is_actionable boolean not null default true,
    last_reviewed_at timestamptz null,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    unique (learner_id, evidence_material_id)
);

create index review_item_learner_idx on review_item (learner_id, due_date);

create table activity_instance (
    activity_instance_id uuid primary key,
    learner_id text not null references user_account(user_id) on delete cascade,
    session_id text not null references session(session_id) on delete cascade,
    session_material_id text not null references session_material(session_material_id) on delete cascade,
    material_id text not null,
    evidence_material_id text not null,
    mode text not null check (mode in ('practice', 'check', 'review', 'retry')),
    status text not null check (status in ('in_progress', 'finished')),
    run_outcome text null check (run_outcome in ('target_met', 'target_not_met')),
    plan jsonb not null,
    result jsonb null,
    review_item_id text null references review_item(review_item_id) on delete set null,
    retry_origin_activity_instance_id uuid null references activity_instance(activity_instance_id) on delete set null,
    evidence_id text null references evidence(evidence_id) on delete set null,
    started_at timestamptz not null,
    finished_at timestamptz null,
    duration_seconds integer null check (duration_seconds is null or duration_seconds >= 0),
    check (
        (status = 'in_progress' and run_outcome is null and result is null and finished_at is null)
        or
        (status = 'finished' and run_outcome is not null and result is not null and finished_at is not null)
    )
);

create index activity_instance_learner_idx
    on activity_instance (learner_id, started_at desc);
create index activity_instance_material_idx
    on activity_instance (learner_id, material_id, started_at desc);
create unique index activity_instance_evidence_idx
    on activity_instance (evidence_id)
    where evidence_id is not null;

create table learner_fact_progress (
    learner_id text not null references user_account(user_id) on delete cascade,
    material_id text not null,
    fact_key text not null,
    attempted_count integer not null check (attempted_count >= 0),
    correct_count integer not null check (correct_count between 0 and attempted_count),
    last_correct boolean not null,
    consecutive_correct_count integer not null check (consecutive_correct_count >= 0),
    last_seen_at timestamptz not null,
    primary key (learner_id, material_id, fact_key)
);

create index learner_fact_progress_adaptive_idx
    on learner_fact_progress (learner_id, material_id, correct_count, attempted_count, last_seen_at);

create table learner_family_progress (
    learner_id text not null references user_account(user_id) on delete cascade,
    material_id text not null,
    family_key text not null,
    attempted_count integer not null check (attempted_count >= 0),
    correct_count integer not null check (correct_count between 0 and attempted_count),
    last_correct boolean not null,
    consecutive_correct_count integer not null check (consecutive_correct_count >= 0),
    last_seen_at timestamptz not null,
    primary key (learner_id, material_id, family_key)
);

create index learner_family_progress_adaptive_idx
    on learner_family_progress (learner_id, material_id, correct_count, attempted_count, last_seen_at);

create table web_session (
    session_id uuid primary key,
    team_id text not null references team(team_id) on delete cascade,
    authenticated_user_id text not null references user_account(user_id) on delete cascade,
    active_user_id text not null references user_account(user_id) on delete cascade,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    expires_at timestamptz not null
);

create index web_session_expires_at_idx on web_session (expires_at);
create index web_session_authenticated_user_idx on web_session (authenticated_user_id, expires_at desc);

create table google_oauth_flow (
    state text primary key,
    code_verifier text not null,
    next_path text not null,
    redirect_uri text not null,
    created_at timestamptz not null
);

create index google_oauth_flow_created_at_idx on google_oauth_flow (created_at);

create table learner_material_readiness_override (
    learner_id text not null references user_account(user_id) on delete cascade,
    material_id text not null,
    minimum_runs integer not null check (minimum_runs > 0),
    recent_run_window integer not null check (recent_run_window > 0),
    target_accuracy double precision not null check (target_accuracy > 0 and target_accuracy <= 1),
    consecutive_target_runs integer not null check (
        consecutive_target_runs > 0
        and consecutive_target_runs <= recent_run_window
        and consecutive_target_runs <= minimum_runs
    ),
    target_correct_count integer null check (target_correct_count is null or target_correct_count > 0),
    minimum_distinct_items integer null check (minimum_distinct_items is null or minimum_distinct_items > 0),
    minimum_family_count integer null check (minimum_family_count is null or minimum_family_count > 0),
    max_duration_seconds integer null check (max_duration_seconds is null or max_duration_seconds > 0),
    enabled boolean not null default true,
    reason text not null default '',
    created_by_user_id text not null references user_account(user_id) on delete restrict,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    disabled_at timestamptz null,
    primary key (learner_id, material_id)
);

create index learner_material_readiness_override_learner_idx
    on learner_material_readiness_override (learner_id, enabled);
