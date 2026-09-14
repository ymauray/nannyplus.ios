import Foundation

/// La relance d'une facture impayée par SMS, telle que la compose
/// `invoice_list_tab_view.dart`.
///
/// L'app ne dessine rien : elle ouvre Messages avec le destinataire et le texte
/// déjà remplis, et signale seulement si elle y est parvenue.
enum InvoiceNotification {
    /// Le gabarit des paramètres de la facture, `{{date}}` et `{{total}}`
    /// remplacés.
    static func message(template: String, invoice: Invoice) -> String {
        template
            .replacingOccurrences(of: "{{date}}", with: InvoicePDF.longDate(invoice.date))
            .replacingOccurrences(of: "{{total}}", with: invoice.total.twoDecimals)
    }

    /// Le numéro débarrassé de tout ce qui n'est ni chiffre, ni point, ni tiret,
    /// ni plus — les libellés et les espaces que l'utilisatrice y met.
    static func sanitized(_ phoneNumber: String) -> String {
        phoneNumber.filter { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" }
    }

    /// `sms:<numéro>&body=<message>` — l'esperluette est ce qu'attend iOS, là
    /// où Android prend un point d'interrogation.
    ///
    /// **Le message est encodé**, ce que Flutter ne fait pas : il assemble
    /// l'adresse par interpolation et la confie telle quelle à `Uri.parse`.
    /// Sans encodage, `URL(string:)` refuse la moindre espace, et le gabarit
    /// par défaut en compte trente.
    static func url(phoneNumber: String, message: String) -> URL? {
        let number = sanitized(phoneNumber)

        guard !number.isEmpty else { return nil }

        // Tout sauf les caractères sans risque : `&` et `=` compris, pour qu'un
        // gabarit qui en contiendrait ne coupe pas l'adresse en deux.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        let body = message.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""

        return URL(string: "sms:\(number)&body=\(body)")
    }
}
