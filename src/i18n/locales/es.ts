import { en } from './en';

export const es = {
  ...en,
  marketing: {
    home: {
      hero: {
        eyebrow: 'Veralify fitness',
        title: 'Rastrea. Conecta. Transforma.',
        body: 'Apunta tu teléfono a un plato y Veralify te dice qué hay en él: calorías, proteínas, carbohidratos, grasas. Regístralo, sigue la tendencia y mantente honesto con gente que notará si te detienes.',
        primaryCta: 'Empieza tu prueba Pro de 3 días',
        secondaryCta: 'Explora el seguimiento con IA',
        stats: ['Prueba de 3 días', 'Sin plan gratuito', 'Cancela cuando quieras'],
      },
      howItWorks: {
        eyebrow: 'Cómo funciona',
        title: 'De la descarga a tu primer registro en menos de un minuto.',
        steps: [
          {
            title: 'Define tu objetivo',
            body: 'Perder, mantener o ganar peso: dinos la dirección y tu punto de partida.',
          },
          {
            title: 'Obtén tu plan',
            body: 'Objetivos diarios de calorías y macros calculados con tus propios datos, no con una plantilla genérica.',
          },
          {
            title: 'Escanea tu primera comida',
            body: 'Apunta el teléfono al plato. Confirma lo que ve la IA antes de guardarlo.',
          },
          {
            title: 'Comienza tu prueba',
            body: '3 días de acceso Pro completo: seguimiento, comunidades, salas en vivo y coaches.',
          },
        ],
      },
      whyItSticks: {
        eyebrow: 'Por qué funciona',
        body: 'La mayoría de las apps de seguimiento se quedan en el registro. Veralify convierte ese registro en un análisis que vale la pena leer, un motivo para entrar a una sala con otras personas y, si lo quieres, un coach que de verdad está pendiente de ti.',
      },
      foodScan: {
        eyebrow: 'Escaneo de comida con IA',
        title: 'Registra comidas con una foto y verifica los detalles.',
        body: 'El proceso prioriza la trazabilidad: la IA propone qué hay en el plato, el motor de nutrición hace los cálculos y tu historial no se reescribe en silencio más adelante.',
        points: [
          'Toma una foto: la IA propone el alimento y las porciones',
          'Confirma o corrige antes de guardarlo en tu registro',
          'Calorías, proteínas, carbohidratos y grasas calculados de forma determinista',
        ],
        previewLabel: 'Vista previa del análisis',
        previewHeading: 'Foto → macros',
        calories: 'Calorías',
        protein: 'Proteína',
        carbs: 'Carbohidratos',
        fat: 'Grasa',
      },
      liveRooms: {
        eyebrow: 'Salas en vivo',
        title: 'Aparece con otros, en tiempo real.',
        body: 'Un feed es fácil de ignorar. Una sala en la que ya estás, no: las salas de voz y video convierten la responsabilidad en algo que ocurre a una hora concreta, con personas concretas.',
        points: [
          'Salas centradas en voz con solicitud para hablar',
          'Sesiones comunitarias programadas y salas organizadas por coaches',
          'Moderación del anfitrión y estados de palabra claros',
        ],
        liveNow: 'En vivo ahora',
        roomName: 'Club de running matutino',
        peopleLive: '12 personas en vivo · toca para unirte',
      },
      coach: {
        eyebrow: 'Descubre coaches',
        title: 'Apoyo humano cuando el seguimiento solo no basta.',
        body: 'Algunas semanas los datos están bien pero la motivación no. Explora coaches verificados, reserva una sesión y págala ahí mismo: sin otra app, sin esperar un correo.',
        points: [
          'Perfiles de coaches verificados con especialidades y tarifas',
          'Reserva y paga una sesión en un solo flujo',
          'Compartir datos es opcional, permiso por permiso',
        ],
        badge: 'Coach verificado',
        coachTitle: 'Coaching de fuerza y nutrición',
        tags: ['Fuerza', 'Nutrición', 'Hábitos'],
      },
      pricing: {
        eyebrow: 'Precios',
        title: 'Una sola suscripción. Sin restricciones.',
        body: 'No hay plan gratuito: la prueba de 3 días te da todo — registro de comidas con IA, análisis, grupos, salas en vivo, seguimiento de progreso y coaches.',
        bestValue: 'Mejor valor',
        compareCta: 'Comparar planes',
      },
      faq: {
        title: 'Preguntas antes de empezar',
        items: [
          {
            question: '¿Cómo funciona realmente el registro de comidas con IA?',
            answer:
              'Toma una foto de tu comida: la IA propone lo que ve y estima las porciones. Confirmas o corriges antes de que se guarde nada, así tu registro se mantiene preciso con el tiempo.',
          },
          {
            question: '¿Hay un plan gratuito?',
            answer:
              'No. Veralify Pro es una sola suscripción con una prueba de 3 días, y esa prueba no es una versión reducida: es todo.',
          },
          {
            question: '¿Y si prefiero trabajar con un coach en vez de hacerlo solo?',
            answer:
              'Descubrir coaches está incluido en Pro. Explora coaches verificados, reserva una sesión y paga de forma segura: el coaching se suma al seguimiento, no lo sustituye.',
          },
          {
            question: '¿En qué plataformas está disponible Veralify?',
            answer:
              'Hoy en web e iOS, con la misma cuenta, derechos y datos sin importar por dónde entres.',
          },
        ],
      },
      finalCta: {
        title: 'Empieza con el seguimiento. Quédate por la responsabilidad.',
        body: 'Registros de comidas, análisis, comunidades, salas en vivo y coaches, todos apuntando a lo mismo: que termines lo que empezaste.',
      },
    },
  },
};
