import { en } from './en';

export const fr = {
  ...en,
  marketing: {
    home: {
      hero: {
        eyebrow: 'Veralify fitness',
        title: 'Suivez. Connectez. Transformez.',
        body: "Pointez votre téléphone vers une assiette et Veralify vous dit ce qu'il y a dedans : calories, protéines, glucides, lipides. Enregistrez-le, suivez la tendance et restez honnête avec des gens qui remarqueront si vous arrêtez.",
        primaryCta: 'Démarrez votre essai Pro de 3 jours',
        secondaryCta: 'Découvrir le suivi par IA',
        stats: ['Essai de 3 jours', 'Pas de formule gratuite', 'Annulable à tout moment'],
      },
      howItWorks: {
        eyebrow: 'Comment ça marche',
        title: "Du téléchargement à votre premier repas enregistré en moins d'une minute.",
        steps: [
          {
            title: 'Définissez votre objectif',
            body: 'Perdre, maintenir ou prendre du poids : indiquez-nous la direction et votre point de départ.',
          },
          {
            title: 'Obtenez votre plan',
            body: "Des objectifs quotidiens de calories et macros calculés à partir de vos propres données, pas d'un modèle générique.",
          },
          {
            title: 'Scannez votre premier repas',
            body: "Pointez votre téléphone vers l'assiette. Confirmez ce que l'IA détecte avant l'enregistrement.",
          },
          {
            title: 'Démarrez votre essai',
            body: '3 jours d’accès Pro complet : suivi, communautés, salons en direct et coachs.',
          },
        ],
      },
      whyItSticks: {
        eyebrow: 'Pourquoi ça marche',
        body: "La plupart des applis de suivi s'arrêtent au journal. Veralify transforme ce journal en une analyse qui vaut la peine d'être lue, une raison de rejoindre un salon avec d'autres personnes et, si vous le souhaitez, un coach qui fait vraiment attention à vous.",
      },
      foodScan: {
        eyebrow: 'Scan de repas par IA',
        title: 'Enregistrez vos repas en photo, puis vérifiez les détails.',
        body: "Le processus privilégie la traçabilité : l'IA propose ce qui se trouve dans l'assiette, le moteur nutritionnel fait les calculs, et votre historique n'est jamais réécrit en silence par la suite.",
        points: [
          "Prenez une photo — l'IA propose l'aliment et les portions",
          "Confirmez ou corrigez avant l'enregistrement",
          'Calories, protéines, glucides et lipides calculés de façon déterministe',
        ],
        previewLabel: 'Aperçu de l’analyse du repas',
        previewHeading: 'Photo → macros',
        calories: 'Calories',
        protein: 'Protéines',
        carbs: 'Glucides',
        fat: 'Lipides',
      },
      liveRooms: {
        eyebrow: 'Salons en direct',
        title: 'Retrouvez-vous ensemble, en temps réel.',
        body: "Un fil d'actualité s'ignore facilement. Un salon où vous êtes déjà, non : les salons audio et vidéo transforment la responsabilisation en un rendez-vous précis, avec des personnes précises.",
        points: [
          'Salons axés sur la voix, avec demande de parole',
          'Sessions communautaires programmées et salons animés par des coachs',
          "Modération de l'hôte et statuts de parole clairs",
        ],
        liveNow: 'En direct',
        roomName: 'Club de course du matin',
        peopleLive: '12 personnes en direct · rejoindre',
      },
      coach: {
        eyebrow: 'Trouver un coach',
        title: 'Un soutien humain quand le suivi seul ne suffit pas.',
        body: "Certaines semaines, les chiffres sont bons mais la motivation n'y est pas. Parcourez des coachs vérifiés, réservez une session et payez sur place — pas d'autre appli, pas d'attente par e-mail.",
        points: [
          'Profils de coachs vérifiés, spécialités et tarifs',
          'Réservez et payez une session en un seul geste',
          'Partage de données facultatif, permission par permission',
        ],
        badge: 'Coach vérifié',
        coachTitle: 'Coaching force & nutrition',
        tags: ['Force', 'Nutrition', 'Habitudes'],
      },
      pricing: {
        eyebrow: 'Tarifs',
        title: "Un seul abonnement. Rien n'est retenu.",
        body: "Pas de formule gratuite — l'essai de 3 jours vous donne tout : journal alimentaire par IA, analyses, groupes, salons en direct, suivi de progression et coachs.",
        bestValue: 'Meilleure offre',
        compareCta: 'Comparer les formules',
      },
      faq: {
        title: 'Questions avant de commencer',
        items: [
          {
            question: 'Comment fonctionne vraiment le suivi alimentaire par IA ?',
            answer:
              "Prenez une photo de votre repas — l'IA propose ce qu'elle voit et estime les portions. Vous confirmez ou corrigez avant tout enregistrement, votre journal reste donc fiable dans le temps.",
          },
          {
            question: 'Y a-t-il une formule gratuite ?',
            answer:
              "Non. Veralify Pro est un abonnement unique avec un essai de 3 jours, et cet essai n'est pas une version limitée : c'est tout.",
          },
          {
            question: 'Et si je préfère travailler avec un coach plutôt que seul ?',
            answer:
              'La recherche de coachs est incluse dans Pro. Parcourez des coachs vérifiés, réservez une session et payez en toute sécurité — le coaching s’ajoute au suivi, il ne le remplace pas.',
          },
          {
            question: 'Sur quelles plateformes Veralify est-il disponible ?',
            answer:
              'Sur le web et iOS dès aujourd’hui, avec le même compte, les mêmes droits et les mêmes données des deux côtés.',
          },
        ],
      },
      finalCta: {
        title: 'Commencez par le suivi. Restez pour la responsabilisation.',
        body: 'Journaux alimentaires, analyses, communautés, salons en direct et coachs — tous tournés vers la même chose : que vous alliez au bout de ce que vous avez commencé.',
      },
    },
  },
};
