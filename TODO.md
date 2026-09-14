# À finir sur l'onglet Factures

Liste **temporaire**, à replier dans [`AVANCEMENT.md`](AVANCEMENT.md) et à
effacer quand tout est porté. La liste, le filtre des payées, le marquage, la
suppression et les deux PDF sont faits ; le reste attend des captures.

- [ ] **Création d'une facture** — le bouton flottant. `InvoiceForm`
      (`lib/forms/invoice_form/invoice_form.dart`). À la fermeture, Flutter
      recharge la liste des factures **et** celle des prestations, la
      facturation marquant les prestations comme facturées.

- [ ] **Relance par SMS** — l'entrée « Notifier » du menu. Le gabarit est déjà
      porté dans les paramètres de la facture : `{{date}}` et `{{total}}` y sont
      remplacés à l'envoi. Le numéro est assaini par `[^\d\.\-\+]`, puis
      l'adresse est `sms:<numéro>&body=<message>` sur iOS — l'esperluette, et
      non le point d'interrogation d'Android.
