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
    status text not null,
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
    status text not null
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
    status text not null,
    score_average double precision not null,
    last_score double precision not null,
    total_evidence integer not null,
    last_evidence_at timestamptz null,
    primary key (learner_id, skill_id)
);

create table review_item (
    review_item_id text primary key,
    learner_id text not null references user_account(user_id) on delete cascade,
    skill_id text not null,
    reason text not null,
    due_date date not null,
    status text not null,
    created_at timestamptz not null
);

create index review_item_learner_idx on review_item (learner_id, due_date);

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

create table learner_material_proficiency_override (
    learner_id text not null references user_account(user_id) on delete cascade,
    material_id text not null,
    min_attempts integer not null,
    window_size integer not null,
    target_accuracy double precision not null,
    consecutive_passes integer not null,
    target_correct_count integer null,
    max_duration_seconds integer null,
    enabled boolean not null default true,
    reason text not null default '',
    created_by_user_id text not null references user_account(user_id) on delete restrict,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    disabled_at timestamptz null,
    primary key (learner_id, material_id)
);

create index learner_material_proficiency_override_learner_idx
    on learner_material_proficiency_override (learner_id, enabled);
