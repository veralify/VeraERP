import { defaultLocale, isLocale, type Locale, localeMeta } from '@i18n/config';

export type EmailStrings = {
  welcome: {
    subject: string;
    preview: string;
    heroTitleLine1: string;
    heroTitleLine2: string;
    greeting: string;
    onList: string;
    building: string;
    bullet1: string;
    bullet2: string;
    bullet3: string;
    redefining: string;
    positionLabel: string;
    moveUp: string;
    inviteLabel: string;
    closingLine: string;
    signoff: string;
    teamLine: string;
  };
  referral: {
    subject: string;
    preview: string;
    heroTitleLine1: string;
    heroTitleLine2: string;
    greeting: string;
    friendJoined: string;
    positionLabel: string;
    friendsCountOne: string;
    friendsCountMany: string;
    keepClimbing: string;
    inviteLabel: string;
    signoff: string;
    teamLine: string;
  };
  common: {
    logoAlt: string;
    company: string;
    receiving: string;
    unsubscribe: string;
  };
};

export const emailStrings: Record<Locale, EmailStrings> = {
  en: {
    welcome: {
      subject: "Welcome to {brand} — you're on the list",
      preview: "You're #{position} on the {brand} waitlist — invite friends to move up.",
      heroTitleLine1: 'Your passport to a',
      heroTitleLine2: 'borderless world.',
      greeting: 'Hey 👋',
      onList: "You're officially on the {brand} waitlist — thank you for joining us early.",
      building:
        "We're building your **passport to a borderless world**: the first travel and telecom super-app for modern explorers. Intuitive enough to activate global internet in seconds, smart enough to curate your perfect trip, and designed to make amazing experiences easier to reach — wherever you go.",
      bullet1: '🌍 Global travel & connectivity in one place.',
      bullet2: '📲 One intelligent super-app.',
      bullet3: '💡 Zero friction. No roaming drama.',
      redefining:
        "We're redefining how travel should feel — with transparency, empathy, and tech that actually works. Booking your journey and staying connected should feel like freedom, not frustration.",
      positionLabel: 'Your position on the waitlist',
      moveUp:
        '**Want to move up?** The higher you climb, the sooner you get in — and the **top 100** unlock an **exclusive launch discount code**. Every friend who joins with your link bumps you up the list.',
      inviteLabel: 'Your personal invite link:',
      closingLine:
        'Join us as we stray off the beaten path to find better ways to explore the world.',
      signoff: 'Talk soon,',
      teamLine: 'The {brand} team ·',
    },
    referral: {
      subject: '🎉 A friend just joined {brand} — you moved up',
      preview: "🎉 A friend just joined {brand} with your link — you're now #{position}.",
      heroTitleLine1: 'You just moved',
      heroTitleLine2: 'up the list. 🎉',
      greeting: 'Great news 🎉',
      friendJoined:
        "A friend just joined the {brand} waitlist using **your invite link** — thank you for spreading the word! You've moved up the list.",
      positionLabel: 'Your new position on the waitlist',
      friendsCountOne: '1 friend joined with your link',
      friendsCountMany: '{count} friends joined with your link',
      keepClimbing:
        '**Keep climbing.** The **top 100** unlock an **exclusive launch discount code** — every friend who joins with your link bumps you higher.',
      inviteLabel: 'Your personal invite link:',
      signoff: 'Talk soon,',
      teamLine: 'The {brand} team ·',
    },
    common: {
      logoAlt: '{brand} logo',
      company: 'VERALIFY LTD · Company Number 17332341 · Registered in England and Wales.',
      receiving: "You're receiving this because you joined our waitlist.",
      unsubscribe: 'Unsubscribe',
    },
  },
  es: {
    welcome: {
      subject: 'Bienvenido a {brand} — ya estás en la lista',
      preview:
        'Estás en el puesto #{position} de la lista de espera de {brand} — invita a amigos para subir.',
      heroTitleLine1: 'Tu pasaporte a un',
      heroTitleLine2: 'mundo sin fronteras.',
      greeting: 'Hola 👋',
      onList:
        'Ya estás oficialmente en la lista de espera de {brand} — gracias por unirte desde el principio.',
      building:
        'Estamos construyendo tu **pasaporte a un mundo sin fronteras**: la primera súper app de viajes y telecomunicaciones para exploradores modernos. Lo bastante intuitiva para activar internet global en segundos, lo bastante inteligente para planear tu viaje perfecto y diseñada para acercarte experiencias increíbles — vayas donde vayas.',
      bullet1: '🌍 Viajes y conectividad global en un solo lugar.',
      bullet2: '📲 Una súper app inteligente.',
      bullet3: '💡 Cero fricción. Sin dramas de roaming.',
      redefining:
        'Estamos redefiniendo cómo debería sentirse viajar — con transparencia, empatía y tecnología que de verdad funciona. Reservar tu viaje y mantenerte conectado debería sentirse como libertad, no como frustración.',
      positionLabel: 'Tu posición en la lista de espera',
      moveUp:
        '**¿Quieres subir?** Cuanto más alto llegues, antes entrarás — y los **100 primeros** desbloquean un **código de descuento exclusivo de lanzamiento**. Cada amigo que se une con tu enlace te sube en la lista.',
      inviteLabel: 'Tu enlace de invitación personal:',
      closingLine:
        'Únete a nosotros mientras salimos del camino trillado para encontrar mejores formas de explorar el mundo.',
      signoff: 'Hasta pronto,',
      teamLine: 'El equipo de {brand} ·',
    },
    referral: {
      subject: '🎉 Un amigo acaba de unirse a {brand} — has subido',
      preview:
        '🎉 Un amigo acaba de unirse a {brand} con tu enlace — ahora estás en el puesto #{position}.',
      heroTitleLine1: 'Acabas de subir',
      heroTitleLine2: 'en la lista. 🎉',
      greeting: 'Buenas noticias 🎉',
      friendJoined:
        'Un amigo acaba de unirse a la lista de espera de {brand} usando **tu enlace de invitación** — ¡gracias por difundirlo! Has subido en la lista.',
      positionLabel: 'Tu nueva posición en la lista de espera',
      friendsCountOne: '1 amigo se unió con tu enlace',
      friendsCountMany: '{count} amigos se unieron con tu enlace',
      keepClimbing:
        '**Sigue subiendo.** Los **100 primeros** desbloquean un **código de descuento exclusivo de lanzamiento** — cada amigo que se une con tu enlace te sube más.',
      inviteLabel: 'Tu enlace de invitación personal:',
      signoff: 'Hasta pronto,',
      teamLine: 'El equipo de {brand} ·',
    },
    common: {
      logoAlt: 'Logo de {brand}',
      company: 'VERALIFY LTD · Número de empresa 17332341 · Registrada en Inglaterra y Gales.',
      receiving: 'Recibes este correo porque te uniste a nuestra lista de espera.',
      unsubscribe: 'Darse de baja',
    },
  },
  fr: {
    welcome: {
      subject: 'Bienvenue chez {brand} — vous êtes sur la liste',
      preview:
        "Vous êtes #{position} sur la liste d'attente de {brand} — invitez des amis pour monter.",
      heroTitleLine1: 'Votre passeport pour un',
      heroTitleLine2: 'monde sans frontières.',
      greeting: 'Bonjour 👋',
      onList:
        "Vous êtes officiellement sur la liste d'attente de {brand} — merci de nous rejoindre dès le début.",
      building:
        "Nous construisons votre **passeport pour un monde sans frontières** : la première super-app de voyage et de télécom pour les explorateurs modernes. Assez intuitive pour activer l'internet mondial en quelques secondes, assez intelligente pour composer votre voyage parfait, et conçue pour rendre les expériences incroyables plus faciles à atteindre — où que vous alliez.",
      bullet1: '🌍 Voyage et connectivité mondiale en un seul endroit.',
      bullet2: '📲 Une super-app intelligente.',
      bullet3: '💡 Zéro friction. Aucun souci de roaming.',
      redefining:
        'Nous redéfinissons ce que voyager devrait être — avec transparence, empathie et une technologie qui fonctionne vraiment. Réserver votre voyage et rester connecté devrait être une liberté, pas une frustration.',
      positionLabel: "Votre position sur la liste d'attente",
      moveUp:
        '**Envie de monter ?** Plus vous grimpez, plus tôt vous entrez — et les **100 premiers** débloquent un **code de réduction de lancement exclusif**. Chaque ami qui rejoint avec votre lien vous fait monter dans la liste.',
      inviteLabel: "Votre lien d'invitation personnel :",
      closingLine:
        'Rejoignez-nous alors que nous sortons des sentiers battus pour trouver de meilleures façons d’explorer le monde.',
      signoff: 'À bientôt,',
      teamLine: "L'équipe {brand} ·",
    },
    referral: {
      subject: '🎉 Un ami vient de rejoindre {brand} — vous êtes monté',
      preview:
        '🎉 Un ami vient de rejoindre {brand} avec votre lien — vous êtes maintenant #{position}.',
      heroTitleLine1: 'Vous venez de monter',
      heroTitleLine2: 'dans la liste. 🎉',
      greeting: 'Bonne nouvelle 🎉',
      friendJoined:
        "Un ami vient de rejoindre la liste d'attente de {brand} avec **votre lien d'invitation** — merci d'avoir passé le mot ! Vous êtes monté dans la liste.",
      positionLabel: "Votre nouvelle position sur la liste d'attente",
      friendsCountOne: '1 ami a rejoint avec votre lien',
      friendsCountMany: '{count} amis ont rejoint avec votre lien',
      keepClimbing:
        '**Continuez à grimper.** Les **100 premiers** débloquent un **code de réduction de lancement exclusif** — chaque ami qui rejoint avec votre lien vous fait monter plus haut.',
      inviteLabel: "Votre lien d'invitation personnel :",
      signoff: 'À bientôt,',
      teamLine: "L'équipe {brand} ·",
    },
    common: {
      logoAlt: 'Logo {brand}',
      company:
        "VERALIFY LTD · Numéro d'entreprise 17332341 · Enregistrée en Angleterre et au Pays de Galles.",
      receiving: "Vous recevez cet e-mail car vous avez rejoint notre liste d'attente.",
      unsubscribe: 'Se désabonner',
    },
  },
  de: {
    welcome: {
      subject: 'Willkommen bei {brand} — du bist auf der Liste',
      preview:
        'Du bist #{position} auf der {brand}-Warteliste — lade Freunde ein, um aufzusteigen.',
      heroTitleLine1: 'Dein Reisepass für eine',
      heroTitleLine2: 'grenzenlose Welt.',
      greeting: 'Hallo 👋',
      onList:
        'Du bist jetzt offiziell auf der {brand}-Warteliste — danke, dass du von Anfang an dabei bist.',
      building:
        'Wir bauen deinen **Reisepass für eine grenzenlose Welt**: die erste Reise- und Telekom-Super-App für moderne Entdecker. Intuitiv genug, um globales Internet in Sekunden zu aktivieren, klug genug, um deine perfekte Reise zusammenzustellen, und darauf ausgelegt, großartige Erlebnisse leichter erreichbar zu machen — wohin du auch gehst.',
      bullet1: '🌍 Globales Reisen & Konnektivität an einem Ort.',
      bullet2: '📲 Eine intelligente Super-App.',
      bullet3: '💡 Null Reibung. Kein Roaming-Drama.',
      redefining:
        'Wir definieren neu, wie sich Reisen anfühlen sollte — mit Transparenz, Empathie und Technik, die wirklich funktioniert. Deine Reise zu buchen und verbunden zu bleiben sollte sich wie Freiheit anfühlen, nicht wie Frust.',
      positionLabel: 'Deine Position auf der Warteliste',
      moveUp:
        '**Willst du aufsteigen?** Je höher du kletterst, desto früher bist du dabei — und die **Top 100** schalten einen **exklusiven Launch-Rabattcode** frei. Jeder Freund, der über deinen Link beitritt, bringt dich in der Liste nach oben.',
      inviteLabel: 'Dein persönlicher Einladungslink:',
      closingLine:
        'Begleite uns, während wir abseits der ausgetretenen Pfade bessere Wege finden, die Welt zu entdecken.',
      signoff: 'Bis bald,',
      teamLine: 'Das {brand}-Team ·',
    },
    referral: {
      subject: '🎉 Ein Freund ist gerade {brand} beigetreten — du bist aufgestiegen',
      preview:
        '🎉 Ein Freund ist gerade {brand} über deinen Link beigetreten — du bist jetzt #{position}.',
      heroTitleLine1: 'Du bist gerade',
      heroTitleLine2: 'aufgestiegen. 🎉',
      greeting: 'Gute Neuigkeiten 🎉',
      friendJoined:
        'Ein Freund ist gerade über **deinen Einladungslink** der {brand}-Warteliste beigetreten — danke, dass du es weitererzählt hast! Du bist in der Liste aufgestiegen.',
      positionLabel: 'Deine neue Position auf der Warteliste',
      friendsCountOne: '1 Freund ist über deinen Link beigetreten',
      friendsCountMany: '{count} Freunde sind über deinen Link beigetreten',
      keepClimbing:
        '**Klettere weiter.** Die **Top 100** schalten einen **exklusiven Launch-Rabattcode** frei — jeder Freund, der über deinen Link beitritt, bringt dich höher.',
      inviteLabel: 'Dein persönlicher Einladungslink:',
      signoff: 'Bis bald,',
      teamLine: 'Das {brand}-Team ·',
    },
    common: {
      logoAlt: '{brand}-Logo',
      company: 'VERALIFY LTD · Firmennummer 17332341 · Registriert in England und Wales.',
      receiving: 'Du erhältst diese E-Mail, weil du unserer Warteliste beigetreten bist.',
      unsubscribe: 'Abbestellen',
    },
  },
  it: {
    welcome: {
      subject: 'Benvenuto in {brand} — sei nella lista',
      preview: "Sei al #{position} nella lista d'attesa di {brand} — invita amici per salire.",
      heroTitleLine1: 'Il tuo passaporto per un',
      heroTitleLine2: 'mondo senza confini.',
      greeting: 'Ciao 👋',
      onList:
        "Sei ufficialmente nella lista d'attesa di {brand} — grazie per esserti unito fin dall'inizio.",
      building:
        'Stiamo costruendo il tuo **passaporto per un mondo senza confini**: la prima super-app di viaggio e telecomunicazioni per gli esploratori moderni. Abbastanza intuitiva da attivare internet globale in pochi secondi, abbastanza intelligente da organizzare il tuo viaggio perfetto e progettata per rendere le esperienze straordinarie più facili da raggiungere — ovunque tu vada.',
      bullet1: '🌍 Viaggi e connettività globale in un unico posto.',
      bullet2: '📲 Una super-app intelligente.',
      bullet3: '💡 Zero attriti. Nessun dramma di roaming.',
      redefining:
        'Stiamo ridefinendo come dovrebbe essere viaggiare — con trasparenza, empatia e una tecnologia che funziona davvero. Prenotare il tuo viaggio e restare connesso dovrebbe essere libertà, non frustrazione.',
      positionLabel: "La tua posizione nella lista d'attesa",
      moveUp:
        '**Vuoi salire?** Più sali, prima entri — e i **primi 100** sbloccano un **codice sconto di lancio esclusivo**. Ogni amico che si unisce con il tuo link ti fa salire nella lista.',
      inviteLabel: 'Il tuo link di invito personale:',
      closingLine:
        'Unisciti a noi mentre usciamo dai sentieri battuti per trovare modi migliori di esplorare il mondo.',
      signoff: 'A presto,',
      teamLine: 'Il team di {brand} ·',
    },
    referral: {
      subject: '🎉 Un amico si è appena unito a {brand} — sei salito',
      preview: '🎉 Un amico si è appena unito a {brand} con il tuo link — ora sei al #{position}.',
      heroTitleLine1: 'Sei appena salito',
      heroTitleLine2: 'nella lista. 🎉',
      greeting: 'Ottime notizie 🎉',
      friendJoined:
        "Un amico si è appena unito alla lista d'attesa di {brand} usando **il tuo link di invito** — grazie per averlo condiviso! Sei salito nella lista.",
      positionLabel: "La tua nuova posizione nella lista d'attesa",
      friendsCountOne: '1 amico si è unito con il tuo link',
      friendsCountMany: '{count} amici si sono uniti con il tuo link',
      keepClimbing:
        '**Continua a salire.** I **primi 100** sbloccano un **codice sconto di lancio esclusivo** — ogni amico che si unisce con il tuo link ti fa salire più in alto.',
      inviteLabel: 'Il tuo link di invito personale:',
      signoff: 'A presto,',
      teamLine: 'Il team di {brand} ·',
    },
    common: {
      logoAlt: 'Logo di {brand}',
      company: 'VERALIFY LTD · Numero società 17332341 · Registrata in Inghilterra e Galles.',
      receiving: "Ricevi questa email perché ti sei iscritto alla nostra lista d'attesa.",
      unsubscribe: 'Annulla iscrizione',
    },
  },
  ar: {
    welcome: {
      subject: 'مرحبًا بك في {brand} — أنت الآن على القائمة',
      preview: 'أنت في المركز #{position} على قائمة انتظار {brand} — ادعُ أصدقاءك للصعود.',
      heroTitleLine1: 'جواز سفرك إلى',
      heroTitleLine2: 'عالم بلا حدود.',
      greeting: 'مرحبًا 👋',
      onList: 'أنت الآن رسميًا على قائمة انتظار {brand} — شكرًا لانضمامك مبكرًا.',
      building:
        'نحن نبني **جواز سفرك إلى عالم بلا حدود**: أول تطبيق خارق للسفر والاتصالات مصمم للمستكشفين العصريين. بديهي بما يكفي لتفعيل الإنترنت العالمي في ثوانٍ، وذكي بما يكفي لتنسيق رحلتك المثالية، ومصمم ليجعل التجارب الرائعة أسهل منالًا — أينما ذهبت.',
      bullet1: '🌍 السفر والاتصال العالمي في مكان واحد.',
      bullet2: '📲 تطبيق خارق واحد ذكي.',
      bullet3: '💡 دون أي عوائق. لا متاعب تجوال.',
      redefining:
        'نحن نعيد تعريف شعور السفر — بالشفافية والتعاطف وتقنية تعمل فعلًا. حجز رحلتك والبقاء متصلًا يجب أن يكون حرية، لا إحباطًا.',
      positionLabel: 'مركزك على قائمة الانتظار',
      moveUp:
        '**تريد الصعود؟** كلما ارتفعت، أسرع دخولك — و**أول 100** يحصلون على **رمز خصم إطلاق حصري**. كل صديق ينضم عبر رابطك يرفعك في القائمة.',
      inviteLabel: 'رابط دعوتك الشخصي:',
      closingLine: 'انضم إلينا ونحن نسلك الطرق غير المألوفة لإيجاد طرق أفضل لاستكشاف العالم.',
      signoff: 'إلى اللقاء قريبًا،',
      teamLine: 'فريق {brand} ·',
    },
    referral: {
      subject: '🎉 صديق انضم للتو إلى {brand} — لقد صعدت',
      preview: '🎉 صديق انضم للتو إلى {brand} عبر رابطك — أنت الآن في المركز #{position}.',
      heroTitleLine1: 'لقد صعدت للتو',
      heroTitleLine2: 'في القائمة. 🎉',
      greeting: 'أخبار رائعة 🎉',
      friendJoined:
        'انضم صديق للتو إلى قائمة انتظار {brand} عبر **رابط دعوتك** — شكرًا لنشر الخبر! لقد صعدت في القائمة.',
      positionLabel: 'مركزك الجديد على قائمة الانتظار',
      friendsCountOne: 'انضم صديق واحد عبر رابطك',
      friendsCountMany: 'انضم {count} أصدقاء عبر رابطك',
      keepClimbing:
        '**واصل الصعود.** **أول 100** يحصلون على **رمز خصم إطلاق حصري** — كل صديق ينضم عبر رابطك يرفعك أعلى.',
      inviteLabel: 'رابط دعوتك الشخصي:',
      signoff: 'إلى اللقاء قريبًا،',
      teamLine: 'فريق {brand} ·',
    },
    common: {
      logoAlt: 'شعار {brand}',
      company: 'VERALIFY LTD · رقم الشركة 17332341 · مسجّلة في إنجلترا وويلز.',
      receiving: 'تتلقى هذه الرسالة لأنك انضممت إلى قائمة انتظارنا.',
      unsubscribe: 'إلغاء الاشتراك',
    },
  },
};

export function getEmailStrings(locale?: string | null): EmailStrings {
  return emailStrings[isLocale(locale) ? locale : defaultLocale];
}

export function getEmailDir(locale?: string | null): 'ltr' | 'rtl' {
  return localeMeta[isLocale(locale) ? locale : defaultLocale].dir;
}

export function fmt(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => (key in vars ? String(vars[key]) : `{${key}}`));
}
