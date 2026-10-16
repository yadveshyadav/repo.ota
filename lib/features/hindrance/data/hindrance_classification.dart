/// Hindrance classification choices mirrored from the Dev Hindrance form.
///
/// The current task API contract does not define a classification lookup
/// endpoint. Keep these options in one place so the app matches the web form
/// until the backend publishes an authoritative master-data route.
abstract final class HindranceClassification {
  static const types = <String>[
    'Linear',
    'Architecture change Involved',
    'No',
    'Ring to Linear',
    'Linear to Ring',
  ];

  static const subtypes = <String>[
    'Low Depth',
    'Route Divert',
    'New GP Add',
    'GP Shifting',
    'Heavy congestion of underground utilities',
    'CC Road – Authority not allowing',
    'CC Road – OT/HDD is not feasible',
    'Permission issue from local authority',
    'Local objection on private land',
    'Narrow Road',
    'Hard Rock',
    'Public issue',
    'Permission restriction from the concerned authority',
    'Road Expansion',
    'Other Remarks (Open Text)',
  ];

  static const _linearOtnSubtypes = <String>[
    'Low Depth',
    'Route Divert',
    'New GP Add',
    'GP Shifting',
  ];

  static const _changeOtnSubtypes = <String>[
    'Heavy congestion of underground utilities',
    'CC Road – Authority not allowing',
    'CC Road – OT/HDD is not feasible',
    'Permission issue from local authority',
    'Local objection on private land',
    'Narrow Road',
    'Hard Rock',
    'Public issue',
    'Permission restriction from the concerned authority',
    'Road Expansion',
    'Other Remarks (Open Text)',
  ];

  /// Mirrors the OTN type/subtype dependency in the deployed task form.
  static List<String> otnSubtypesFor(String? otnType) => switch (otnType) {
    'Linear' => _linearOtnSubtypes,
    'Architecture change Involved' ||
    'Ring to Linear' ||
    'Linear to Ring' => _changeOtnSubtypes,
    _ => subtypes,
  };
}
