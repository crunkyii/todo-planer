// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'ToDo Planer';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get undo => 'Deshacer';

  @override
  String get add => 'Añadir';

  @override
  String get added => 'Añadido';

  @override
  String get saved => 'Guardado';

  @override
  String get itemGone => 'Este elemento se eliminó entretanto.';

  @override
  String get back => 'Atrás';

  @override
  String get all => 'Todo';

  @override
  String get name => 'Nombre';

  @override
  String get color => 'Color';

  @override
  String get customColor => 'Color personalizado';

  @override
  String get chooseCustomColor => 'Elegir color personalizado';

  @override
  String get apply => 'Aplicar';

  @override
  String get hue => 'Tono';

  @override
  String get saturation => 'Saturación';

  @override
  String get brightness => 'Brillo';

  @override
  String get none => 'Ninguno';

  @override
  String get timeNone => 'Ninguna';

  @override
  String get done => 'Hecho';

  @override
  String get reopened => 'Reabierto';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get mainNavigation => 'Navegación principal';

  @override
  String get navTasks => 'Tareas';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navWeek => 'Semana';

  @override
  String get navStats => 'Estadísticas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get weeklyPlan => 'Plan semanal';

  @override
  String get statistics => 'Estadísticas';

  @override
  String get settings => 'Ajustes';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get setupLead => '¿Dónde quieres guardar tus tareas?';

  @override
  String get setupCloudText =>
      'Tu propia base de datos Supabase gratuita. Móvil y PC siempre sincronizados, también funciona sin conexión.';

  @override
  String get setupLocalTitle => 'Solo en este dispositivo';

  @override
  String get setupLocalText => 'Sin cuenta ni configuración. Puedes cambiarlo más tarde en los ajustes.';

  @override
  String get languageBoth => 'Idioma · Language';

  @override
  String get connectDb => 'Conectar base de datos';

  @override
  String get connectOtherDb => 'Conectar otra base de datos';

  @override
  String get openSupabase => 'Abrir supabase.com';

  @override
  String get connectExistingLead =>
      'Tu cuenta está en tu propia base de datos. Para que este dispositivo pueda iniciar tu sesión, necesita la <b>Project URL</b> y la <b>Publishable Key</b> de la base de datos, las mismas que en tu primer dispositivo. Ambas están en tu proyecto de Supabase.';

  @override
  String get copySql => 'Copiar SQL';

  @override
  String get sqlCopied => 'SQL copiado: pégalo ahora en el SQL Editor';

  @override
  String get connect => 'Conectar';

  @override
  String get connecting => 'Conectando …';

  @override
  String get setupStep1 => 'Regístrate gratis en <b>supabase.com</b> y crea un <b>proyecto nuevo</b>.';

  @override
  String get setupStep2 =>
      'En el proyecto, abre el <b>SQL Editor</b>, pega el SQL y pulsa <b>Run</b>. Así se crean las tablas.';

  @override
  String get setupStep3 =>
      '<b>Project URL</b>: pulsa <b>Connect</b> en la parte superior del proyecto o abre <b>Project Settings → Data API</b>. Tiene este aspecto: https://abcdefgh.supabase.co – la parte antes de \".supabase.co\" es el <b>Project ID</b> (Project Settings → General). <b>Publishable Key</b>: en <b>Project Settings → API Keys</b>, empieza por sb_publishable_. Copia ambas y pégalas abajo.';

  @override
  String get setupStep4 =>
      'Después de registrarte: desactiva <b>Authentication → Sign In / Providers</b> → <b>\"Allow new users to sign up\"</b>. Así nadie más podrá crear una cuenta en tu base de datos.';

  @override
  String get secretNote => 'No introduzcas nunca la <b>Secret Key</b> (service_role): no debe estar en una app.';

  @override
  String get projectUrl => 'Project URL';

  @override
  String get publishableKey => 'Publishable Key';

  @override
  String get projectUrlHint => 'https://abcdefgh.supabase.co';

  @override
  String get publishableKeyHint => 'sb_publishable_…';

  @override
  String get errUrl => 'La Project URL tiene este aspecto: https://abcdefgh.supabase.co';

  @override
  String get errKeyFormat => 'La clave empieza por \"sb_publishable_\" (o por \"eyJ\" en proyectos antiguos).';

  @override
  String get errSecretKey => 'Esa es la clave secreta. Usa la Publishable Key.';

  @override
  String get errNoConnection => 'Sin conexión. ¿Es correcta la URL y se ejecutó el SQL?';

  @override
  String connectedTo(String host) {
    return 'Conectado a $host';
  }

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get haveAccount => 'Ya tengo una cuenta';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get errEmail => 'Introduce un correo electrónico válido.';

  @override
  String get errPassword => 'Introduce tu contraseña.';

  @override
  String get errPasswordShort => 'La contraseña necesita al menos 6 caracteres.';

  @override
  String get errPasswordLong => 'La contraseña es demasiado larga (72 caracteres como máximo).';

  @override
  String get errWrongLogin => 'El correo o la contraseña no son correctos.';

  @override
  String get accountCreatedHint => 'Cuenta creada. Ahora desactiva \"Allow new users to sign up\" en Supabase.';

  @override
  String get confirmEmailHint => 'Casi listo: confirma tu correo con el enlace del mensaje y después inicia sesión.';

  @override
  String get errNetwork => 'Sin conexión con el servidor. Comprueba tu conexión a internet.';

  @override
  String get errEmailNotConfirmed => 'Confirma primero tu correo (enlace del mensaje de confirmación).';

  @override
  String get errAccountExists => 'Ya existe una cuenta con este correo. Inicia sesión.';

  @override
  String get errWeakPassword => 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';

  @override
  String get errRateLimit => 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';

  @override
  String get errSignupDisabled => 'El registro está desactivado en esta base de datos.';

  @override
  String get errSessionExpired => 'Tu sesión ha caducado. Inicia sesión de nuevo.';

  @override
  String errAuthGeneric(String message) {
    return 'Error al iniciar sesión: $message';
  }

  @override
  String get errNoPermission => 'Sin permiso para esta acción. Inicia sesión de nuevo.';

  @override
  String get errTableMissing => 'Faltan tablas en la base de datos. Ejecuta de nuevo el SQL de la configuración.';

  @override
  String errDbGeneric(String message) {
    return 'Error de la base de datos: $message';
  }

  @override
  String get errUnexpected => 'Error inesperado. Inténtalo de nuevo.';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get yesterday => 'Ayer';

  @override
  String get overdue => 'Atrasadas';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get later => 'Más adelante';

  @override
  String sectionCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get newTask => 'Nueva tarea';

  @override
  String get editTask => 'Editar tarea';

  @override
  String get deleteTask => 'Eliminar tarea';

  @override
  String get task => 'Tarea';

  @override
  String get errTaskTitle => 'Escribe qué hay que hacer.';

  @override
  String get nothingDue => 'Nada pendiente.';

  @override
  String get widgetUpcoming => 'Próximas';

  @override
  String widgetUntil(String when) {
    return 'para: $when';
  }

  @override
  String get widgetNoHabits => 'Aún no hay hábitos.';

  @override
  String get widgetSettings => 'Ajustes del widget';

  @override
  String get widgetContent => 'Contenido';

  @override
  String get widgetContentHint => 'Lo que muestra el widget';

  @override
  String get widgetRange => 'Periodo';

  @override
  String get widgetRangeHint => 'Hasta cuándo';

  @override
  String get widgetRange3d => '3 días';

  @override
  String get widgetRange1w => '1 semana';

  @override
  String get widgetRange2w => '2 semanas';

  @override
  String get widgetRange1m => '1 mes';

  @override
  String get widgetRangeAll => 'Todo';

  @override
  String get widgetRangeNote =>
      'Las tareas atrasadas siempre se incluyen, sea cual sea el periodo. El número de arriba solo cuenta lo que muestra el widget.';

  @override
  String widgetUntilDate(String date) {
    return 'hasta $date';
  }

  @override
  String get widgetBackground => 'Fondo';

  @override
  String get widgetShowBackground => 'Mostrar fondo';

  @override
  String get widgetShape => 'Forma';

  @override
  String get widgetShapeRound => 'Redonda';

  @override
  String get widgetShapeSoft => 'Suave';

  @override
  String get widgetShapeSquare => 'Cuadrada';

  @override
  String get widgetBgColor => 'Color de fondo';

  @override
  String widgetTransparency(int percent) {
    return 'Transparencia: $percent%';
  }

  @override
  String get widgetColorApp => 'Igual que el tema de la app';

  @override
  String get widgetPreview => 'Vista previa';

  @override
  String get widgetHint =>
      'Mantén pulsado el widget en la pantalla de inicio y toca «Ajustes» para cambiarlo más tarde.';

  @override
  String get nothingFound => 'No se encontró nada.';

  @override
  String get noTasks => 'Sin tareas.';

  @override
  String get searchTasks => 'Buscar tareas';

  @override
  String get search => 'Buscar';

  @override
  String get closeSearch => 'Cerrar búsqueda';

  @override
  String get columns => 'Columnas';

  @override
  String get columnsVisible => 'Visibles a la vez';

  @override
  String get columnsPeriods => 'Periodos';

  @override
  String get columnsCategories => 'Categorías como columna propia';

  @override
  String get close => 'Cerrar';

  @override
  String get columnsAllHidden => 'Todas las columnas están ocultas. Vuelve a activarlas en ⋮ → Columnas.';

  @override
  String get columnsDragHint => 'Cambia el orden: mantén pulsado el título de una columna y arrástrala adonde quieras.';

  @override
  String get moveLeft => 'Mover a la izquierda';

  @override
  String get moveRight => 'Mover a la derecha';

  @override
  String get columnsNarrowHint => 'Una ventana estrecha muestra menos columnas a la vez de las que has ajustado aquí.';

  @override
  String get columnsDragHintTouch => 'Cambia el orden: mantén pulsado un título y arrástralo adonde quieras.';

  @override
  String get moveUp => 'Mover arriba';

  @override
  String get moveDown => 'Mover abajo';

  @override
  String get sort => 'Ordenar';

  @override
  String get sortByDate => 'Por fecha';

  @override
  String get sortByCategory => 'Por categoría';

  @override
  String get sortByName => 'Por nombre (A–Z)';

  @override
  String get filterByCategory => 'Filtrar por categoría';

  @override
  String get showCompleted => 'Mostrar completadas';

  @override
  String get hideCompleted => 'Ocultar completadas';

  @override
  String get completedHidden => 'Completadas ocultas';

  @override
  String get completedShown => 'Completadas visibles';

  @override
  String get deleteCompleted => 'Eliminar completadas';

  @override
  String get noCompleted => 'Sin tareas completadas';

  @override
  String completedDeleted(int count) {
    return '$count completadas eliminadas';
  }

  @override
  String get completedTasks => 'Tareas completadas';

  @override
  String get subtask => 'Subtarea';

  @override
  String get subtasks => 'Subtareas';

  @override
  String get removeSubtask => 'Quitar subtarea';

  @override
  String get notes => 'Nota';

  @override
  String get notesHint => 'Más sobre esta tarea …';

  @override
  String get schemaOutdated => 'La base de datos es más antigua que la app: ejecuta de nuevo schema.sql en Supabase.';

  @override
  String get dueOn => 'Para el';

  @override
  String get dateAndTime => 'Fecha y hora';

  @override
  String get time => 'Hora';

  @override
  String get hour => 'Hora';

  @override
  String get minute => 'Minuto';

  @override
  String get quickDate => 'Fecha rápida';

  @override
  String get quickTime => 'Hora rápida';

  @override
  String get inOneWeek => 'En 1 semana';

  @override
  String get prevMonth => 'Mes anterior';

  @override
  String get prevLists => 'Listas anteriores';

  @override
  String get nextLists => 'Listas siguientes';

  @override
  String get todayAllDone => 'Todo hecho';

  @override
  String todayOpen(int count) {
    return '$count pendientes';
  }

  @override
  String todayOpenLate(int count, int late) {
    return '$count pendientes, $late atrasadas';
  }

  @override
  String get nextMonth => 'Mes siguiente';

  @override
  String a11yDone(String title) {
    return 'Hecho: $title';
  }

  @override
  String a11yReopen(String title) {
    return 'Reabrir: $title';
  }

  @override
  String a11yCheckSub(String title) {
    return 'Marcar subtarea: $title';
  }

  @override
  String a11yReopenSub(String title) {
    return 'Reabrir subtarea: $title';
  }

  @override
  String categoryLabel(String name) {
    return 'Categoría: $name';
  }

  @override
  String deletedItem(String name) {
    return '\"$name\" eliminado';
  }

  @override
  String deletedCatMoved(String name, String target) {
    return '\"$name\" eliminada, tareas → $target';
  }

  @override
  String infoDue(String day) {
    return 'Para $day';
  }

  @override
  String infoHandIn(String day) {
    return 'Entrega $day';
  }

  @override
  String infoListFrom(String info, String day) {
    return '$info · en la lista desde $day';
  }

  @override
  String dayWithTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String weekdayWithDate(String weekday, String date) {
    return '$weekday, $date';
  }

  @override
  String weekdayShortWithDate(String weekday, String date) {
    return '$weekday $date';
  }

  @override
  String progress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get pendingSyncHint => 'Se sincronizará en cuanto tengas conexión';

  @override
  String get habits => 'Hábitos';

  @override
  String get habit => 'Hábito';

  @override
  String get newHabit => 'Nuevo hábito';

  @override
  String get editHabit => 'Editar hábito';

  @override
  String get daily => 'Diario';

  @override
  String get habitsCheckAll => 'Marcar todos los hábitos de hoy';

  @override
  String get habitsReopenAll => 'Reabrir todos los hábitos';

  @override
  String get habitHint => 'p. ej. Beber agua';

  @override
  String a11yHabitDoneToday(String name) {
    return '$name hecho hoy';
  }

  @override
  String a11yHabitReopen(String name) {
    return 'Reabrir $name';
  }

  @override
  String a11yHabitDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get noHabits => 'Aún no hay hábitos: toca +.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count días', one: '1 día');
    return '$_temp0';
  }

  @override
  String get categories => 'Categorías';

  @override
  String get manageCategories => 'Gestionar categorías';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get editCategory => 'Editar categoría';

  @override
  String get errCategoryExists => 'Esta categoría ya existe.';

  @override
  String get errName => 'Escribe un nombre.';

  @override
  String get categoryHint => 'p. ej. Presentación';

  @override
  String get catHomework => 'Deberes';

  @override
  String get catTask => 'Tarea';

  @override
  String get catTest => 'Examen';

  @override
  String get catAppointment => 'Cita';

  @override
  String get doWhen => 'Hacer';

  @override
  String get showInTasks => 'Mostrar en tareas';

  @override
  String get listFromAlways => 'Siempre';

  @override
  String get listFromWeek => 'Desde «Esta semana»';

  @override
  String get listFromTomorrow => 'Desde «Mañana»';

  @override
  String get listFromToday => 'Desde «Hoy»';

  @override
  String get listFromNever => 'Nunca';

  @override
  String hiddenByCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas ocultas',
      one: '1 tarea oculta',
    );
    return '$_temp0 – cámbialo en la categoría';
  }

  @override
  String get offsetSameDay => 'El mismo día';

  @override
  String offsetDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count días antes', one: '1 día antes');
    return '$_temp0';
  }

  @override
  String get offsetWeekBefore => '1 semana antes';

  @override
  String catDoSameDay(int open) {
    return 'Hacer el mismo día · $open pendientes';
  }

  @override
  String catDoDaysBefore(int count, int open) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hacer $count días antes · $open pendientes',
      one: 'Hacer 1 día antes · $open pendientes',
    );
    return '$_temp0';
  }

  @override
  String catDoWeekBefore(int open) {
    return 'Hacer 1 semana antes · $open pendientes';
  }

  @override
  String categoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count categorías', one: '1 categoría');
    return '$_temp0';
  }

  @override
  String get newBlock => 'Nuevo bloque';

  @override
  String get editBlock => 'Editar bloque';

  @override
  String get blockView => 'Bloque';

  @override
  String get edit => 'Editar';

  @override
  String blockOnlyWeek(String range) {
    return 'Solo en la semana del $range';
  }

  @override
  String get blockTask => 'Tarea vinculada';

  @override
  String get blockTaskGone => 'La tarea vinculada ya no existe.';

  @override
  String get blockGone => 'Este bloque ya no existe.';

  @override
  String get blockAdded => 'Bloque añadido';

  @override
  String blocksAdded(int count) {
    return '$count bloques añadidos';
  }

  @override
  String get blockDeleted => 'Bloque eliminado';

  @override
  String get from => 'Desde';

  @override
  String get to => 'Hasta';

  @override
  String timeWithDuration(String duration) {
    return 'Hora · $duration';
  }

  @override
  String get day => 'Día';

  @override
  String get days => 'Días';

  @override
  String get everyWeek => 'Cada semana';

  @override
  String get repeatEveryWeek => 'Repetir cada semana';

  @override
  String get errToAfterFrom => '\"Hasta\" debe ser posterior a \"Desde\".';

  @override
  String get durInvalid => '\"Hasta\" debe ser posterior a \"Desde\"';

  @override
  String get errPickDay => 'Elige al menos un día.';

  @override
  String get tasksThatDay => 'Tareas de este día';

  @override
  String get blockHint => 'Clase, entrenamiento …';

  @override
  String get prevWeek => 'Semana anterior';

  @override
  String get nextWeek => 'Semana siguiente';

  @override
  String get prevDay => 'Día anterior';

  @override
  String get nextDay => 'Día siguiente';

  @override
  String get backToWeek => 'Volver a la semana';

  @override
  String showDay(String day) {
    return 'Mostrar $day';
  }

  @override
  String weekNumber(int number) {
    return 'Semana $number';
  }

  @override
  String dayAndWeek(String day, String week) {
    return '$day · $week';
  }

  @override
  String rangeDash(String from, String to) {
    return '$from – $to';
  }

  @override
  String a11yBlock(String name, String day, String from, String to) {
    return '$name, $day de $from a $to';
  }

  @override
  String durHoursMin(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durHours(int hours) {
    return '$hours h';
  }

  @override
  String durMin(int minutes) {
    return '$minutes min';
  }

  @override
  String get quickPlus30 => '+30 min';

  @override
  String get quickPlus60 => '+1 h';

  @override
  String get quickPlus90 => '+1½ h';

  @override
  String get quickPlus120 => '+2 h';

  @override
  String get activity => 'Actividad';

  @override
  String get period => 'Periodo';

  @override
  String get less => 'menos';

  @override
  String get more => 'más';

  @override
  String get perDay => 'por día';

  @override
  String get tileDone => 'hechas';

  @override
  String tileStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'días de racha', one: 'días de racha');
    return '$_temp0';
  }

  @override
  String daysRange(int count) {
    return '$count días';
  }

  @override
  String heatSummary(int total, int days) {
    return '<b>$total</b> hechas en <b>$days</b> días';
  }

  @override
  String heatDay(String date, int count) {
    return '$date: <b>$count</b> hechas';
  }

  @override
  String a11yHeatDay(String date, int count) {
    return '$date: $count hechas';
  }

  @override
  String chartA11y(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas hechas',
      one: '1 tarea hecha',
    );
    return '$_temp0 en $days días';
  }

  @override
  String barTooltip(String day, int count) {
    return '$day: $count';
  }

  @override
  String get byCategory => 'Por categoría';

  @override
  String get language => 'Idioma';

  @override
  String get appearance => 'Apariencia';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get system => 'Sistema';

  @override
  String get theme => 'Tema';

  @override
  String get themeHimmel => 'Cielo';

  @override
  String get themeOzean => 'Océano';

  @override
  String get themeMint => 'Menta';

  @override
  String get themeWald => 'Bosque';

  @override
  String get themeSonne => 'Sol';

  @override
  String get themeAbendrot => 'Atardecer';

  @override
  String get themeBeere => 'Frutos rojos';

  @override
  String get themeLavendel => 'Lavanda';

  @override
  String get themeNord => 'Nord';

  @override
  String get themeGraphit => 'Grafito';

  @override
  String get colorSkyBlue => 'Azul cielo';

  @override
  String get colorMintGreen => 'Verde menta';

  @override
  String get colorSunYellow => 'Amarillo sol';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorLavender => 'Lavanda';

  @override
  String get reminders => 'Recordatorios';

  @override
  String get grid => 'Cuadrícula (minutos)';

  @override
  String get weekStartsOn => 'La semana empieza el';

  @override
  String get dayStarts => 'El día empieza';

  @override
  String get dayEnds => 'El día termina';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get database => 'Base de datos';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get offline => 'Sin conexión';

  @override
  String offlinePending(int count) {
    return 'Sin conexión · $count pendientes';
  }

  @override
  String get synced => 'Sincronizado';

  @override
  String get syncing => 'Sincronizando …';

  @override
  String get allSynced => 'Todo sincronizado';

  @override
  String get offlineToast => 'Sin conexión: los cambios se guardan en el dispositivo';

  @override
  String get backOnline => 'De nuevo en línea';

  @override
  String backOnlineSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'De nuevo en línea: sincronizando $count cambios …',
      one: 'De nuevo en línea: sincronizando 1 cambio …',
    );
    return '$_temp0';
  }

  @override
  String get savedOnDevice => 'Guardado en el dispositivo';

  @override
  String get savedOnDeviceLater => 'Guardado en el dispositivo: se sincronizará más tarde';

  @override
  String get noSyncOtherDevices => 'Sin sincronización con otros dispositivos';

  @override
  String get connectToDb => 'Conectar a una base de datos';

  @override
  String get connectToDbSub => 'Sincroniza tareas entre móvil y PC';

  @override
  String get notifChannelName => 'Recordatorios';

  @override
  String get notifChannelDesc => 'Te recuerda las tareas con hora';

  @override
  String get yearly => 'Anual';

  @override
  String get yearlyHint => 'Se repite cada año';

  @override
  String get doneYearly => 'Hecho: vuelve el año que viene';

  @override
  String holidayLine(String name) {
    return 'Festivo: $name';
  }

  @override
  String get hNewYear => 'Año Nuevo';

  @override
  String get hEpiphany => 'Epifanía';

  @override
  String get hEasterMonday => 'Lunes de Pascua';

  @override
  String get hLabourDay => 'Día del Trabajo';

  @override
  String get hAscension => 'Ascensión';

  @override
  String get hWhitMonday => 'Lunes de Pentecostés';

  @override
  String get hCorpusChristi => 'Corpus Christi';

  @override
  String get hAssumption => 'Asunción';

  @override
  String get hNationalDay => 'Fiesta Nacional';

  @override
  String get hAllSaints => 'Todos los Santos';

  @override
  String get hImmaculate => 'Inmaculada Concepción';

  @override
  String get hChristmas => 'Navidad';

  @override
  String get hStStephen => 'San Esteban';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get exportData => 'Exportar datos';

  @override
  String get exportSub => 'Guardar como PDF, texto u hoja de cálculo';

  @override
  String get exportPdfSub => 'Para leer e imprimir';

  @override
  String get exportTxtSub => 'Texto sin formato';

  @override
  String get exportCsvSub => 'Hoja de cálculo para Excel';

  @override
  String get exportSaved => 'Exportación guardada';

  @override
  String get exportFailed => 'Error al exportar';

  @override
  String get colTitle => 'Título';

  @override
  String get colCategory => 'Categoría';

  @override
  String get colDue => 'Fecha';

  @override
  String get colDaysDone => 'Días hechos';

  @override
  String get colLastDone => 'Última vez';

  @override
  String get colDay => 'Día';

  @override
  String get colFrom => 'Desde';

  @override
  String get colTo => 'Hasta';

  @override
  String get colLeadDays => 'Antelación (días)';

  @override
  String exportStamp(String date) {
    return 'A fecha de $date';
  }

  @override
  String exportWeekOf(String date) {
    return 'Solo semana del $date';
  }

  @override
  String get updates => 'Actualizaciones';

  @override
  String updateVersion(String version) {
    return 'Versión $version';
  }

  @override
  String updateCurrent(String version) {
    return 'Versión $version: actualizada';
  }

  @override
  String get updateChecking => 'Buscando actualizaciones …';

  @override
  String updateAvailable(String version) {
    return 'La versión $version está disponible';
  }

  @override
  String get updateInstall => 'Instalar';

  @override
  String updateDownloading(int percent) {
    return 'Descargando … $percent %';
  }

  @override
  String get updateInstalling => 'Instalando: la app se reiniciará enseguida';

  @override
  String get updateConfirm => 'Toca «Actualizar» en el diálogo de Android';

  @override
  String get updateFailed => 'No ha funcionado: haz clic aquí para reintentar';

  @override
  String get langDe => 'Deutsch';

  @override
  String get langEn => 'English';

  @override
  String get langEs => 'Español';

  @override
  String get langFr => 'Français';

  @override
  String get langIt => 'Italiano';

  @override
  String get langNameDe => 'Alemán';

  @override
  String get langNameEn => 'Inglés';

  @override
  String get langNameEs => 'Español';

  @override
  String get langNameFr => 'Francés';

  @override
  String get langNameIt => 'Italiano';

  @override
  String get langSameAsDevice => 'Igual que el dispositivo';

  @override
  String get finish => 'Listo';

  @override
  String olderDoneLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cargar $count tareas completadas anteriores',
      one: 'Cargar 1 tarea completada anterior',
    );
    return '$_temp0';
  }

  @override
  String olderDoneOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas completadas anteriores solo son visibles en línea',
      one: '1 tarea completada anterior solo es visible en línea',
    );
    return '$_temp0';
  }

  @override
  String get olderDoneFailed => 'No se pudieron cargar las tareas anteriores';

  @override
  String exportOlderMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sin $count tareas completadas anteriores: solo disponibles en línea',
      one: 'Sin 1 tarea completada anterior: solo disponible en línea',
    );
    return '$_temp0';
  }

  @override
  String flickHeader(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendientes',
      one: '1 pendiente',
      zero: 'nada pendiente',
    );
    return 'Hoy, $date · $_temp0';
  }

  @override
  String flickTimed(String time, String title) {
    return '$time $title';
  }

  @override
  String flickOverdue(String title) {
    return '⚠ $title (atrasada)';
  }

  @override
  String get flickToday => 'Tareas de hoy para Flick';

  @override
  String get flickTodaySub => 'Las muestra en el lanzador de Windows Flick al escribir «Aufgaben»';

  @override
  String get flickCopy => 'Copiar accesos de Flick';

  @override
  String get flickCopySub => 'Escribe «flick config» en Flick y pégalos al final';

  @override
  String get flickCopied => 'Accesos de Flick copiados';

  @override
  String get flickAboutAdd => 'Nueva tarea en ToDo Planer';

  @override
  String get flickAboutToday => 'Tareas de hoy de ToDo Planer';

  @override
  String get flickAboutTab => 'Abrir ToDo Planer en una pestaña';

  @override
  String get flickGuideTitle => 'Configurar Flick';

  @override
  String get flickGuideIntro => 'Los accesos están copiados. Así se añaden a Flick:';

  @override
  String get flickStep1 => 'Abre Flick';

  @override
  String get flickStep1Sub => 'Pulsa Alt+Espacio.';

  @override
  String get flickStep2 => 'Escribe «flick config»';

  @override
  String get flickStep2Sub => 'Pulsa Intro: el archivo config.toml se abre en tu editor.';

  @override
  String get flickStep3 => 'Pega al final';

  @override
  String get flickStep3Sub =>
      'Desplázate hasta abajo del todo y pulsa Ctrl+V. Si ya añadiste los accesos antes, borra primero el bloque antiguo; si no, aparecerán dos veces.';

  @override
  String get flickStep4 => 'Guarda';

  @override
  String get flickStep4Sub => 'Pulsa Ctrl+S. Flick detecta los accesos al instante.';

  @override
  String get flickGuideList => 'Lista «Aufgaben»';

  @override
  String get flickGuideTry => 'Lo que puedes escribir después';

  @override
  String get flickCopyAgain => 'Copiar de nuevo';

  @override
  String get flickHeading => 'Flick';

  @override
  String get closeHint => 'Cerrar aviso';

  @override
  String blockMoved(String time) {
    return 'Bloque movido a las $time';
  }

  @override
  String get pickCategory => 'Categoría';

  @override
  String get addTasksToDay => 'Más tareas para este día';

  @override
  String get pickTasksTitle => 'Tareas para este día';

  @override
  String get pickTasksInfo =>
      'Todas las tareas pendientes desde este día. Las que elijas aparecen en el bloque para escogerlas.';

  @override
  String get pickTasksNone => 'No hay tareas pendientes desde este día.';

  @override
  String applyCount(int count) {
    return 'Añadir $count';
  }

  @override
  String get allHabitsDone => 'Todos los hábitos de hoy completados. ¡Bien hecho!';
}
