import 'package:flutter/material.dart';

/// Shared Cornerstone icon vocabulary for curriculum entities, materials,
/// and workspace navigation. Update icons here to keep the UI consistent.
abstract final class CornerstoneIcons {
  CornerstoneIcons._();

  // Curriculum hierarchy
  static const IconData pathway = Icons.route_rounded;
  static const IconData playlist = Icons.playlist_play_rounded;
  static const IconData session = Icons.assignment_rounded;

  // Shell destinations
  static const IconData team = Icons.dashboard_rounded;
  static const IconData learning = Icons.school_rounded;
  static const IconData library = Icons.auto_stories_rounded;
  static const IconData profile = Icons.person_rounded;

  // Audience and teaching surfaces
  static const IconData learnerAudience = Icons.school_rounded;
  static const IconData teachingGuidance = Icons.co_present_rounded;

  // Workspace chrome
  static const IconData menu = Icons.menu_rounded;
  static const IconData menuOpen = Icons.menu_open_rounded;
  static const IconData progress = Icons.insights_outlined;
  static const IconData progressActive = Icons.insights_rounded;
  static const IconData expandAll = Icons.unfold_more_rounded;
  static const IconData collapseAll = Icons.unfold_less_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;

  // Progress and assignment stats
  static const IconData completed = Icons.task_alt_rounded;
  static const IconData pending = Icons.timelapse_rounded;
  static const IconData review = Icons.pending_actions_rounded;
  static const IconData standing = Icons.place_rounded;
  static const IconData readyNow = Icons.rocket_launch_rounded;

  // Documents and material kinds
  static const IconData document = Icons.description_rounded;
  static const IconData print = Icons.print_rounded;
  static const IconData lessonNote = Icons.menu_book_rounded;
  static const IconData teachingNote = Icons.record_voice_over_rounded;
  static const IconData worksheet = Icons.edit_note_rounded;
  static const IconData drill = Icons.play_circle_fill_rounded;
  static const IconData quickCheck = Icons.fact_check_rounded;
  static const IconData activity = Icons.playlist_add_check_circle_rounded;

  static IconData materialKind(String kind) {
    return switch (kind) {
      'lesson_note' => lessonNote,
      'teaching_note' => teachingNote,
      'worksheet' => worksheet,
      'drill' => drill,
      'quick_check' => quickCheck,
      _ => document,
    };
  }

  static IconData entity(String entity) {
    return switch (entity) {
      'pathway' => pathway,
      'playlist' => playlist,
      'session' => session,
      _ => document,
    };
  }
}
