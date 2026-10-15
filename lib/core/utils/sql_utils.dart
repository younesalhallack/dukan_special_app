/// Escapes `\`, `%` and `_` so user text can be used inside a SQL LIKE
/// pattern that declares `ESCAPE '\'`.
String escapeLike(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');
