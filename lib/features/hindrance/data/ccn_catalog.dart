/// Temporary selectable values transcribed from the user's CCN reference.
/// Replace this catalog with the CCN API response when its contract is supplied.
const ccnCategories = <String>['Linear', 'Architecture change Involved'];

const ccnSubtypes = <String, List<String>>{
  'Linear': ['Low Depth', 'Route Divert', 'New GP Add', 'GP Shifting'],
  'Architecture change Involved': [
    'Heavy congestion of underground utilities',
    'CC Road – Authority not allowing',
    'CC Road – OT/HDD is not feasible',
    'Permission issue from local authority',
    'Local objection on private land',
    'Hard Rock',
    'Public issue',
    'Permission restriction from the concerned',
    'Road Expansion',
  ],
};
