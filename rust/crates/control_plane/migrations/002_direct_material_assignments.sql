alter table assignment add column source_kind text not null default 'playlist';
alter table assignment add column material_id text null;
alter table assignment add column activity_mode text null;
alter table assignment add constraint assignment_source_check check (
    (source_kind = 'playlist' and playlist_id <> '' and material_id is null and activity_mode is null)
    or (source_kind = 'material' and playlist_id = '' and material_id is not null)
);
alter table assignment add constraint assignment_activity_mode_check
    check (activity_mode is null or activity_mode in ('assisted', 'assessment'));

-- Serializes repeated Start requests into one resumable in-progress run for a material.
-- Historical unfinished duplicates remain readable; new starts are serialized on the session-material row.
create index activity_instance_unfinished_material_idx
    on activity_instance (session_id, material_id, started_at desc)
    where status = 'in_progress';
