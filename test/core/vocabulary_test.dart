import 'package:academia_app/core/vocabulary/vocabulary.dart';
import 'package:academia_app/features/enrollment/data/models.dart';
import 'package:academia_app/features/enrollment/data/request_form.dart';
import 'package:academia_app/features/onboarding/data/models.dart'
    show dailyBasisOptions, invitationMessage;
import 'package:academia_app/features/organizations/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los mismos casos que `tests/Unit/VocabularyTest.php` de la API (las reglas locales son una copia).
void main() {
  group('género de la palabra', () {
    const cases = {
      'Categoría': 'f',
      'Clase': 'f',
      'Sala': 'f',
      'Pileta': 'f',
      'Aula': 'f', //
      'Actividad': 'f', 'Comisión': 'f', 'academia': 'f',
      'Grupo': 'm', 'Nivel': 'm', 'Espacio': 'm', 'Deporte': 'm',
      'Programa': 'm', 'club': 'm', 'Salón': 'm', 'Jugador': 'm',
      'Atleta': 'c', 'Deportista': 'c', 'Estudiante': 'c', 'Responsable': 'c',
      'Grupo de entrenamiento': 'm', 'Clase de natación': 'f',
    };
    for (final entry in cases.entries) {
      test(entry.key, () => expect(wordGender(entry.key), entry.value));
    }

    test('las de género común concuerdan en masculino', () {
      final atleta = Word.of('Atleta');
      expect(atleta.isFeminine, isFalse);
      expect(atleta.the(), 'el atleta');
      expect(atleta.the(person: Gender.female), 'la atleta');
      expect(atleta.g('otro', 'otra'), 'otro');
    });
  });

  test('artículos: "el aula" pero "las aulas" y "esta aula"', () {
    final aula = Word.of('Aula');
    expect(aula.the(), 'el aula');
    expect(aula.a, 'un aula');
    expect(aula.of(), 'del aula');
    expect(aula.the(plural: true), 'las aulas');
    expect(aula.g('este', 'esta'), 'esta');

    expect(Word.of('Categoría').the(), 'la categoría');
    expect(Word.of('Grupo').the(), 'el grupo');
    expect(Word.of('Categoría').a, 'una categoría');
    expect(Word.of('Grupo').of(), 'del grupo');
    expect(Word.of('Técnico').to(), 'al técnico');
    expect(Word.of('comisión').of(), 'de la comisión');
    expect(Word.of('club').theUpper(), 'El club');
  });

  test('plurales', () {
    const cases = {
      'Categoría': 'Categorías', 'Tutor': 'Tutores', 'Nivel': 'Niveles', //
      'Salón': 'Salones', 'Bailarín': 'Bailarines', 'club': 'clubes',
      'Actividad': 'Actividades', 'Luz': 'Luces', 'Joven': 'Jóvenes',
      'Grupo de entrenamiento': 'Grupos de entrenamiento',
    };
    cases.forEach((word, plural) => expect(pluralize(word), plural));
  });

  test('formas de persona', () {
    const cases = {
      'Jugador': ('Jugadora', 'Jugador'), 'Técnico': ('Técnica', 'Técnico'), //
      'Profesor': ('Profesora', 'Profesor'), 'Alumno': ('Alumna', 'Alumno'),
      'Instructor': ('Instructora', 'Instructor'),
      'Entrenador': ('Entrenadora', 'Entrenador'), 'Tutor': ('Tutora', 'Tutor'),
      'Encargado': ('Encargada', 'Encargado'),
      'Bailarín': ('Bailarina', 'Bailarín'), 'Alumna': ('Alumna', 'Alumno'),
      'Profesora': ('Profesora', 'Profesor'), 'Atleta': ('Atleta', 'Atleta'),
      'Responsable': ('Responsable', 'Responsable'),
      'Presidente': ('Presidenta', 'Presidente'),
    };
    cases.forEach((word, forms) {
      expect(feminineOf(word), forms.$1, reason: word);
      expect(masculineOf(word), forms.$2, reason: word);
    });
  });

  test('una persona y un grupo de personas', () {
    final jugador = Word.of('Jugador');
    expect(jugador.forPerson(Gender.female), 'Jugadora');
    expect(jugador.forPerson(null), 'Jugador');
    expect(jugador.agree(Gender.female, 'cargado', 'cargada'), 'cargada');
    expect(jugador.forPeople([Gender.female, Gender.female]), 'Jugadoras');
    expect(jugador.forPeople([Gender.female, Gender.male]), 'Jugadores');
    expect(jugador.forPeople([Gender.female, null]), 'Jugadores');
    expect(Word.of('Alumna').forPeople([Gender.female, null]), 'Alumnas');
    expect(Word.of('Alumna').forPeople([Gender.male]), 'Alumnos');
    // La forma que ajustó la organización gana.
    expect(
      Word.of('Coach', feminineForm: 'Entrenadora').forPerson(Gender.female),
      'Entrenadora',
    );
  });

  group('lo que manda la API', () {
    OrganizationDetails organization({
      String? type,
      Map<String, Object?> vocabulary = const {},
      Map<String, String> terminology = const {},
    }) => OrganizationDetails.fromJson({
      'slug': 'org',
      'name': 'Org',
      'type': ?type,
      'terminology': terminology,
      'vocabulary': vocabulary,
    });

    test('usa la palabra de la API (con su artículo y su forma femenina)', () {
      final details = organization(
        terminology: {'instructor': 'Coach', 'space': 'Aula'},
        vocabulary: {
          'instructor': {
            'word': 'Coach',
            'plural': 'Coaches',
            'gender': 'm',
            'article': 'el',
            'feminine': 'Entrenadora',
            'feminine_plural': 'Entrenadoras',
            'masculine': 'Coach',
            'masculine_plural': 'Coaches',
          },
          'space': {
            'word': 'Aula',
            'plural': 'Aulas',
            'gender': 'f',
            'article': 'el',
          },
          'organization': {
            'word': 'escuela',
            'plural': 'escuelas',
            'gender': 'f',
            'article': 'la',
          },
        },
      );

      expect(
        details.word('instructor').forPerson(Gender.female),
        'Entrenadora',
      );
      expect(details.word('instructor').plural, 'Coaches');
      expect(details.word('space').the(), 'el aula');
      expect(details.org.of(), 'de la escuela');
      // Sin la palabra en la API: las reglas locales.
      expect(details.word('group').the(), 'la categoría');
    });

    test('la organización según el tipo, sin vocabulary', () {
      const cases = {
        null: ('el club', 'del club'),
        'academy': ('la academia', 'de la academia'),
        'school': ('la escuela', 'de la escuela'),
        'parents_association': ('la comisión', 'de la comisión'),
      };
      cases.forEach((type, expected) {
        final details = organization(type: type);
        expect(details.org.the(), expected.$1);
        expect(details.org.of(), expected.$2);
        expect(details.typeWithArticle, expected.$1);
      });
    });
  });

  test('el género del tutor sale del parentesco', () {
    expect(Relationship.mother.gender, Gender.female);
    expect(Relationship.grandmother.gender, Gender.female);
    expect(Relationship.aunt.gender, Gender.female);
    expect(Relationship.father.gender, Gender.male);
    expect(Relationship.guardian.gender, isNull);
    expect(Relationship.other.gender, isNull);
    expect(Relationship.parse('tia'), Relationship.aunt);
  });

  test('textos sueltos con Grupo y con Categoría', () {
    expect(validateGroup(null), 'Elegí la categoría.');
    expect(validateGroup(null, Word.of('Grupo')), 'Elegí el grupo.');
    expect(
      validateGuardianName('', Word.of('Encargado')),
      'Ingresá el nombre del encargado.',
    );
    expect(
      dailyBasisOptions('Grupo')['entrenamiento']!.$2,
      'Los días con horario del grupo.',
    );
    expect(
      dailyBasisOptions('Categoría')['entrenamiento']!.$2,
      'Los días con horario de la categoría.',
    );
    expect(
      invitationMessage(
        name: 'Ana López',
        organization: 'Club Jakare',
        role: Word.of('Técnico').forPerson(Gender.female),
        link: 'https://x',
      ),
      startsWith('Hola Ana, te invito a sumarte como técnica de'),
    );
  });
}
