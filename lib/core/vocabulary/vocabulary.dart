/// Concordancia con las palabras del vocabulario de la organización (Categoría / Grupo, Técnico / Profesora,
/// Aula…) y con el género de las personas ("Técnica", "Jugadora").
///
/// La API decide (`GET organization` → `vocabulary`, ver `academia-api/docs/PLAN_GENERO.md`): cada palabra llega
/// con su plural, género, artículo y formas de persona. Las reglas de abajo son una copia mínima de las de la API
/// (`App\Support\Vocabulary`) **solo** para palabras que todavía no están guardadas (la vista previa de "Tu club" y
/// "Cómo les dicen") o si la API no las manda.
library;

/// Género de una persona (opcional): null = sin especificar.
enum Gender {
  female('female', 'Femenino'),
  male('male', 'Masculino');

  const Gender(this.value, this.label);

  final String value;
  final String label;

  static Gender? fromApi(Object? value) => switch (value) {
    'female' => Gender.female,
    'male' => Gender.male,
    _ => null,
  };
}

/// El género con que se nombra a un grupo: femenino si son todas mujeres, masculino (genérico) si hay algún
/// varón, null (la palabra de la organización) si no se sabe de nadie.
Gender? groupGender(Iterable<Gender?> genders) {
  if (genders.isEmpty) return null;
  if (genders.every((g) => g == Gender.female)) return Gender.female;
  if (genders.contains(Gender.male)) return Gender.male;
  return null;
}

/// Una palabra del vocabulario con lo necesario para concordar.
class Word {
  const Word({
    required this.word,
    required this.plural,
    required this.gender,
    required this.article,
    this.feminine,
    this.femininePlural,
    this.masculine,
    this.masculinePlural,
  });

  /// Como la manda la API (`vocabulary.group`).
  factory Word.fromJson(Map<String, dynamic> json) {
    final word = json['word'] as String;
    return Word(
      word: word,
      plural: json['plural'] as String? ?? pluralize(word),
      gender: json['gender'] as String? ?? wordGender(word),
      article: json['article'] as String? ?? _article(word),
      feminine: json['feminine'] as String?,
      femininePlural: json['feminine_plural'] as String?,
      masculine: json['masculine'] as String?,
      masculinePlural: json['masculine_plural'] as String?,
    );
  }

  /// Con las reglas locales (una palabra que todavía no guardó la API). [feminineForm]: la que ajustó la
  /// organización.
  factory Word.of(String word, {String? feminineForm}) {
    final female = feminineForm ?? feminineOf(word);
    final male = masculineOf(word);
    return Word(
      word: word,
      plural: pluralize(word),
      gender: wordGender(word),
      article: _article(word),
      feminine: female,
      femininePlural: pluralize(female),
      masculine: male,
      masculinePlural: pluralize(male),
    );
  }

  /// Tal como la eligió la organización ("Categoría").
  final String word;
  final String plural;

  /// 'm', 'f' o 'c' (común: Atleta, Estudiante; concuerda en masculino salvo una mujer concreta).
  final String gender;

  /// Artículo definido en singular ("el" aula).
  final String article;
  final String? feminine;
  final String? femininePlural;
  final String? masculine;
  final String? masculinePlural;

  bool get isFeminine => gender == 'f';

  /// En minúscula: "categoría".
  String get lower => word.toLowerCase();

  /// Plural en minúscula: "categorías".
  String get pluralLower => plural.toLowerCase();

  /// Según el género de la palabra: g('otro', 'otra').
  String g(String masculine, String feminine) =>
      isFeminine ? feminine : masculine;

  /// "la categoría", "el aula", "los grupos"; con [person], según la persona ("la atleta", "la tutora").
  String the({bool plural = false, Gender? person}) =>
      '${_articleFor(plural: plural, person: person)} '
      '${_noun(plural: plural, person: person)}';

  /// Al principio de una frase: "La academia", "El club".
  String theUpper({bool plural = false, Gender? person}) =>
      capitalize(the(plural: plural, person: person));

  /// "una categoría", "un aula", "un grupo".
  String get a => '${article == 'el' ? 'un' : 'una'} $lower';

  /// "del grupo", "de la categoría", "del aula", "de los técnicos".
  String of({bool plural = false, Gender? person}) {
    final article = _articleFor(plural: plural, person: person);
    return '${article == 'el' ? 'del' : 'de $article'} '
        '${_noun(plural: plural, person: person)}';
  }

  /// "al técnico", "a la técnica", "a los jugadores".
  String to({bool plural = false, Gender? person}) {
    final article = _articleFor(plural: plural, person: person);
    return '${article == 'el' ? 'al' : 'a $article'} '
        '${_noun(plural: plural, person: person)}';
  }

  /// Cómo se nombra a una persona: su forma si se sabe el género; si no, la palabra de la organización.
  String forPerson(Gender? person) => switch (person) {
    Gender.female => feminine ?? feminineOf(word),
    Gender.male => masculine ?? masculineOf(word),
    null => word,
  };

  /// Plural para un grupo de personas (femenino solo si son todas mujeres).
  String forPeople(Iterable<Gender?> genders) => switch (groupGender(genders)) {
    Gender.female => femininePlural ?? pluralize(forPerson(Gender.female)),
    Gender.male => masculinePlural ?? pluralize(forPerson(Gender.male)),
    null => plural,
  };

  /// Concordancia con una persona concreta: por su género si se sabe; si no, por el de la palabra.
  String agree(Gender? person, String masculine, String feminine) =>
      switch (person) {
        Gender.female => feminine,
        Gender.male => masculine,
        null => g(masculine, feminine),
      };

  /// En minúscula; con [person], su forma ("tutora", "jugadores").
  String _noun({required bool plural, Gender? person}) {
    if (person == null) return plural ? pluralLower : lower;
    return (plural ? forPeople([person]) : forPerson(person)).toLowerCase();
  }

  String _articleFor({required bool plural, Gender? person}) {
    final feminine = person != null ? person == Gender.female : isFeminine;
    if (plural) return feminine ? 'las' : 'los';
    if (person != null) return feminine ? 'la' : 'el';
    return article;
  }
}

// ---------------------------------------------------------------------------
// Reglas locales (copia de App\Support\Vocabulary; ver arriba cuándo se usan).

const _masculineWords = {
  'día', 'mapa', 'programa', 'tema', 'sistema', 'problema', 'idioma', //
  'clima', 'planeta', 'esquema', 'drama', 'poema', 'dilema', 'sofá', 'papá',
};
const _feminineWords = {
  'clase', 'sede', 'base', 'tarde', 'noche', 'red', 'pared', 'mano', 'foto', //
  'moto', 'flor', 'piel', 'imagen', 'calle', 'llave', 'nave', 'madre', 'mamá',
  'mujer',
};
const _masculineIon = {
  'avión', 'camión', 'gorrión', 'sarampión', 'aluvión', 'guion', 'guión', //
  'ion', 'ión',
};
const _commonWords = {
  'atleta', 'guía', 'profe', 'coach', 'responsable', 'gimnasta', 'karateca', //
  'colega', 'joven', 'miembro', 'sensei', 'tutor/a', 'cónyuge', 'líder',
  'referente',
};
const _notCommonIsta = {
  'pista',
  'lista',
  'vista',
  'revista',
  'conquista',
  'arista',
};
const _stressedA = {
  'aula', 'área', 'agua', 'ala', 'alma', 'arma', 'acta', 'ancla', 'arpa', //
  'asa', 'ave', 'alba', 'aria', 'haba', 'habla', 'hacha', 'hada', 'hambre',
  'águila',
};
const _feminineForms = {
  'padre': 'madre', 'papá': 'mamá', 'hombre': 'mujer', 'varón': 'mujer', //
  'jefe': 'jefa', 'presidente': 'presidenta',
  'vicepresidente': 'vicepresidenta', 'rey': 'reina',
};
const _plurals = {
  'joven': 'jóvenes', 'examen': 'exámenes', 'imagen': 'imágenes', //
  'origen': 'orígenes',
};

String _head(String word) => word.trim().split(' ').first.toLowerCase();

/// 'm', 'f' o 'c' (común).
String wordGender(String word) {
  final h = _head(word);
  if (h.isEmpty) return 'm';
  if (_commonWords.contains(h) ||
      (h.endsWith('ista') && !_notCommonIsta.contains(h)) ||
      h.endsWith('nte')) {
    return 'c';
  }
  if (_masculineWords.contains(h) || _masculineIon.contains(h)) return 'm';
  if (_feminineWords.contains(h) ||
      h.endsWith('a') ||
      h.endsWith('á') ||
      h.endsWith('dad') ||
      h.endsWith('tad') ||
      h.endsWith('tud') ||
      h.endsWith('ión') ||
      h.endsWith('ion') ||
      h.endsWith('umbre')) {
    return 'f';
  }
  return 'm';
}

String _article(String word) {
  if (wordGender(word) != 'f') return 'el';
  return _stressedA.contains(_head(word)) ? 'el' : 'la';
}

/// Aplica [transform] a la primera palabra y conserva el resto y la mayúscula inicial.
String _mapHead(String word, String Function(String head) transform) {
  final trimmed = word.trim();
  final space = trimmed.indexOf(' ');
  final head = space < 0 ? trimmed : trimmed.substring(0, space);
  final rest = space < 0 ? '' : trimmed.substring(space);
  var result = transform(head);
  if (head.isNotEmpty &&
      head[0] == head[0].toUpperCase() &&
      head[0] != head[0].toLowerCase() &&
      result.isNotEmpty) {
    result = result[0].toUpperCase() + result.substring(1);
  }
  return '$result$rest';
}

const _unaccent = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};

String _unaccentLast(String word) {
  for (var i = word.length - 1; i >= 0; i--) {
    final plain = _unaccent[word[i]];
    if (plain != null) return word.replaceRange(i, i + 1, plain);
  }
  return word;
}

/// Plural en español: categoría → categorías, tutor → tutores, salón → salones.
String pluralize(String word) => _mapHead(word, (head) {
  final lower = head.toLowerCase();
  if (_plurals.containsKey(lower)) return _plurals[lower]!;
  if (lower.isEmpty || lower.contains('/')) return head;
  if (lower.endsWith('z')) return '${head.substring(0, head.length - 1)}ces';
  if (RegExp(r'[aeiouáéó]$').hasMatch(lower)) return '${head}s';
  if (RegExp(r'[áéíóú][nsl]$').hasMatch(lower)) {
    return '${_unaccentLast(head)}es';
  }
  if (RegExp(r'[sx]$').hasMatch(lower) &&
      RegExp(r'[aeiouáéíóú]+').allMatches(lower).length > 1) {
    return head;
  }
  return '${head}es';
});

/// Forma femenina de una palabra de persona: Jugador → Jugadora, Atleta → Atleta.
String feminineOf(String word) {
  final h = _head(word);
  if (wordGender(word) != 'm' && !_feminineForms.containsKey(h)) return word;
  return _mapHead(word, (head) {
    final lower = head.toLowerCase();
    if (_feminineForms.containsKey(lower)) return _feminineForms[lower]!;
    if (lower.endsWith('o')) return '${head.substring(0, head.length - 1)}a';
    if (lower.endsWith('or')) return '${head}a';
    if (RegExp(r'[íóéá]n$|és$').hasMatch(lower)) {
      return '${_unaccentLast(head)}a';
    }
    return head;
  });
}

/// Forma masculina de una palabra de persona: Alumna → Alumno, Profesora → Profesor.
String masculineOf(String word) {
  if (wordGender(word) != 'f') return word;
  return _mapHead(word, (head) {
    final lower = head.toLowerCase();
    for (final entry in _feminineForms.entries) {
      if (entry.value == lower && lower != 'mujer') return entry.key;
    }
    if (lower.endsWith('ora')) return head.substring(0, head.length - 1);
    if (lower.endsWith('a')) return '${head.substring(0, head.length - 1)}o';
    return head;
  });
}

/// Primera letra en mayúscula: capitalize('la academia') → "La academia".
String capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Según el género de una palabra suelta (sin `Word` a mano): gendered('Grupo', 'otro', 'otra').
String gendered(String word, String masculine, String feminine) =>
    wordGender(word) == 'f' ? feminine : masculine;
