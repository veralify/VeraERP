import { en } from './en';

export const it = {
  ...en,
  marketing: {
    home: {
      hero: {
        eyebrow: 'Veralify fitness',
        title: 'Traccia. Connetti. Trasforma.',
        body: "Inquadra un piatto con il telefono e Veralify ti dice cosa c'è: calorie, proteine, carboidrati, grassi. Registralo, segui l'andamento e resta onesto con persone che si accorgeranno se smetti.",
        primaryCta: 'Inizia la prova Pro di 3 giorni',
        secondaryCta: 'Scopri il tracking con IA',
        stats: ['Prova di 3 giorni', 'Nessun piano gratuito', 'Annulla quando vuoi'],
      },
      howItWorks: {
        eyebrow: 'Come funziona',
        title: 'Dal download al primo pasto registrato in meno di un minuto.',
        steps: [
          {
            title: 'Imposta il tuo obiettivo',
            body: 'Perdere, mantenere o aumentare peso — dicci la direzione e il tuo punto di partenza.',
          },
          {
            title: 'Ottieni il tuo piano',
            body: 'Obiettivi giornalieri di calorie e macro calcolati sui tuoi dati, non su un modello generico.',
          },
          {
            title: 'Scansiona il primo pasto',
            body: "Inquadra il piatto con il telefono. Conferma ciò che l'IA riconosce prima che venga salvato.",
          },
          {
            title: 'Avvia la prova',
            body: '3 giorni di accesso Pro completo — tracking, community, stanze live e coach.',
          },
        ],
      },
      whyItSticks: {
        eyebrow: 'Perché funziona',
        body: "La maggior parte delle app di tracking si ferma al registro. Veralify trasforma quel registro in un'analisi che vale la pena leggere, un motivo per entrare in una stanza con altre persone e, se lo vuoi, un coach che ti segue davvero.",
      },
      foodScan: {
        eyebrow: 'Scansione pasti con IA',
        title: 'Registra i pasti con una foto, poi verifica i dettagli.',
        body: "Il processo dà priorità alla tracciabilità: l'IA propone cosa c'è nel piatto, il motore nutrizionale fa i calcoli e la tua cronologia non viene mai riscritta in silenzio in seguito.",
        points: [
          "Scatta una foto — l'IA propone alimento e porzioni",
          'Conferma o correggi prima che venga salvato',
          'Calorie, proteine, carboidrati e grassi calcolati in modo deterministico',
        ],
        previewLabel: 'Anteprima analisi pasto',
        previewHeading: 'Foto → macro',
        calories: 'Calorie',
        protein: 'Proteine',
        carbs: 'Carboidrati',
        fat: 'Grassi',
      },
      liveRooms: {
        eyebrow: 'Stanze live',
        title: 'Ritrovatevi insieme, in tempo reale.',
        body: 'Un feed è facile da ignorare. Una stanza in cui sei già dentro no — le stanze audio e video trasformano la responsabilità in qualcosa che succede in un momento preciso, con persone precise.',
        points: [
          'Stanze incentrate sulla voce, con richiesta di parola',
          'Sessioni di community programmate e stanze guidate da coach',
          'Moderazione dell’host e stati di parola chiari',
        ],
        liveNow: 'Live ora',
        roomName: 'Morning Run Club',
        peopleLive: '12 persone live · tocca per unirti',
      },
      coach: {
        eyebrow: 'Trova un coach',
        title: 'Supporto umano quando il tracking da solo non basta.',
        body: 'Certe settimane i dati vanno bene ma la motivazione no. Sfoglia coach verificati, prenota una sessione e pagala lì — niente altra app, niente attese via email.',
        points: [
          'Profili di coach verificati con specialità e tariffe',
          'Prenota e paga una sessione in un solo passaggio',
          'Condivisione dati facoltativa, permesso per permesso',
        ],
        badge: 'Coach verificato',
        coachTitle: 'Coaching di forza e nutrizione',
        tags: ['Forza', 'Nutrizione', 'Abitudini'],
      },
      pricing: {
        eyebrow: 'Prezzi',
        title: 'Un solo abbonamento. Niente di limitato.',
        body: "Non c'è un piano gratuito — la prova di 3 giorni ti dà tutto: registro pasti con IA, analisi, gruppi, stanze live, monitoraggio dei progressi e ricerca coach.",
        bestValue: 'Miglior valore',
        compareCta: 'Confronta i piani',
      },
      faq: {
        title: 'Domande prima di iniziare',
        items: [
          {
            question: 'Come funziona davvero il tracking dei pasti con IA?',
            answer:
              "Scatta una foto del pasto — l'IA propone ciò che vede e stima le porzioni. Confermi o correggi prima che venga salvato, così il registro resta accurato nel tempo.",
          },
          {
            question: "C'è un piano gratuito?",
            answer:
              'No. Veralify Pro è un unico abbonamento con una prova di 3 giorni, e la prova non è una versione ridotta: è tutto.',
          },
          {
            question: 'E se preferissi lavorare con un coach invece di procedere da solo?',
            answer:
              'La ricerca coach è inclusa in Pro. Sfoglia coach verificati, prenota una sessione e paga in sicurezza — il coaching si affianca al tracking, non lo sostituisce.',
          },
          {
            question: 'Su quali piattaforme è disponibile Veralify?',
            answer:
              'Oggi su web e iOS, con lo stesso account, gli stessi diritti e gli stessi dati da entrambe le parti.',
          },
        ],
      },
      finalCta: {
        title: 'Inizia con il tracking. Resta per la responsabilità.',
        body: 'Registro pasti, analisi, community, stanze live e coach — tutti puntati sulla stessa cosa: farti davvero finire quello che hai iniziato.',
      },
    },
  },
};
