# À finir sur l'onglet Factures

Liste **temporaire**, à replier dans [`AVANCEMENT.md`](AVANCEMENT.md) et à
effacer quand tout est porté. La liste des factures, le filtre des payées, le
marquage et la suppression sont faits ; le reste attend des captures.

- [ ] **Création d'une facture** — le bouton flottant. `InvoiceForm`
      (`lib/forms/invoice_form/invoice_form.dart`). À la fermeture, Flutter
      recharge la liste des factures **et** celle des prestations, la
      facturation marquant les prestations comme facturées.

- [ ] **PDF d'une facture** — un appui sur la date ou sur le montant d'une
      ligne. `InvoiceView` (`lib/src/invoice_view/invoice_view.dart`).

- [ ] **Relevé annuel de l'enfant** — le bouton PDF dans l'en-tête d'une année.
      `ChildStatementView` (`lib/src/invoice_view/child_statement_view.dart`).
      À ne pas confondre avec le décompte annuel des relevés, déjà porté.

- [ ] **Relance par SMS** — l'entrée « Notifier » du menu. Le gabarit est déjà
      porté dans les paramètres de la facture : `{{date}}` et `{{total}}` y sont
      remplacés à l'envoi.
