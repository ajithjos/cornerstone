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
