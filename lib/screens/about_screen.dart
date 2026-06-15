import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive.dart';

/// App-Version (zentral pflegen; spiegelt pubspec wider).
const String kAppVersion = '1.0.0';

/// „Über"-Screen mit App-Info, Datenschutz, Impressum, Kontakt, Nutzung
/// und Lizenzen.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Über')),
      body: ResponsiveCenter(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFD6E4F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(CupertinoIcons.square_grid_2x2,
                  size: 44, color: Color(0xFF2C4A66)),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('Sitzplan',
                style:
                    TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('Version $kAppVersion',
                style: TextStyle(color: Colors.black54)),
          ),
          const SizedBox(height: 24),
          const _Section(
            icon: CupertinoIcons.lock_shield,
            title: 'Datenschutz auf einen Blick',
            body:
                'Alle Klassen, Schülernamen und Sitzpläne werden ausschließlich lokal auf deinem Gerät gespeichert. Keine Cloud, kein Konto, keine Übertragung, kein Tracking.',
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _LinkTile(
                  icon: CupertinoIcons.lock_shield,
                  label: 'Datenschutzerklärung',
                  page: _PrivacyPolicyPage(),
                ),
                _divider(),
                _LinkTile(
                  icon: CupertinoIcons.building_2_fill,
                  label: 'Impressum',
                  page: _ImpressumPage(),
                ),
                _divider(),
                _LinkTile(
                  icon: CupertinoIcons.mail,
                  label: 'Kontakt & Support',
                  page: _ContactPage(),
                ),
                _divider(),
                _LinkTile(
                  icon: CupertinoIcons.doc_plaintext,
                  label: 'Nutzungsbedingungen',
                  page: _TermsPage(),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(CupertinoIcons.doc_text),
                  title: const Text('Open-Source-Lizenzen'),
                  trailing: const Icon(CupertinoIcons.chevron_right,
                      size: 18, color: Colors.black26),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Sitzplan',
                    applicationVersion: kAppVersion,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('Mit ♥ für Lehrerinnen und Lehrer',
                style: TextStyle(color: Colors.black38, fontSize: 13)),
          ),
        ],
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 56, color: Color(0xFFEDEFF3));
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Section(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  fontSize: 14, height: 1.4, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget page;
  const _LinkTile(
      {required this.icon, required this.label, required this.page});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(CupertinoIcons.chevron_right,
          size: 18, color: Colors.black26),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
    );
  }
}

// ---- Rechts-/Info-Unterseiten --------------------------------------------

/// Wiederverwendbare Textseite mit Überschriften und Absätzen.
class _LegalPage extends StatelessWidget {
  final String title;
  final List<({String? heading, String body})> blocks;
  final bool showPlaceholderHint;

  const _LegalPage({
    required this.title,
    required this.blocks,
    this.showPlaceholderHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ResponsiveCenter(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (showPlaceholderHint)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E6D6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.exclamationmark_triangle,
                      color: Color(0xFF5E4B30), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Platzhalter in [eckigen Klammern] vor der Veröffentlichung ausfüllen.',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF5E4B30)),
                    ),
                  ),
                ],
              ),
            ),
          for (final b in blocks) ...[
            if (b.heading != null) ...[
              Text(b.heading!,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
            ],
            Text(b.body,
                style: const TextStyle(
                    fontSize: 14, height: 1.45, color: Colors.black87)),
            const SizedBox(height: 16),
          ],
        ],
        ),
      ),
    );
  }
}

class _PrivacyPolicyPage extends StatelessWidget {
  const _PrivacyPolicyPage();

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Datenschutzerklärung',
      showPlaceholderHint: true,
      blocks: [
        (
          heading: 'Verantwortlicher',
          body:
              '[Vor- und Nachname]\n[Straße und Hausnummer]\n[PLZ Ort]\nE-Mail: [deine-email@beispiel.de]',
        ),
        (
          heading: '1. Grundsatz',
          body:
              'Diese App („Sitzplan") verarbeitet personenbezogene Daten ausschließlich lokal auf deinem Gerät. Es findet keine Übertragung an den Anbieter oder an Dritte statt. Es gibt kein Benutzerkonto, keine Cloud-Synchronisierung und keine Analyse- oder Tracking-Dienste.',
        ),
        (
          heading: '2. Welche Daten verarbeitet werden',
          body:
              'Du kannst Klassennamen, Schülernamen (oder anonyme Bezeichnungen), Eigenschaften/Regeln sowie Sitzpläne eingeben. Diese Angaben werden allein im lokalen Speicher deines Geräts abgelegt und verlassen dieses nicht.',
        ),
        (
          heading: '3. Schülerdaten',
          body:
              'Gibst du echte Schülernamen ein, verarbeitest du personenbezogene Daten Dritter in eigener Verantwortung (z. B. als Lehrkraft im Rahmen deiner Schule). Wir empfehlen, nach Möglichkeit anonyme Bezeichnungen oder Initialen zu verwenden. Beachte die für dich geltenden schulischen und behördlichen Datenschutzvorgaben.',
        ),
        (
          heading: '4. Speicherdauer & Löschung',
          body:
              'Die Daten bleiben gespeichert, bis du die jeweilige Klasse löschst oder die App vom Gerät entfernst. Beim Deinstallieren werden alle lokal gespeicherten Daten entfernt.',
        ),
        (
          heading: '5. Keine Weitergabe',
          body:
              'Da keine Daten an uns übertragen werden, erfolgt keine Weitergabe, kein Verkauf und keine Auswertung durch den Anbieter.',
        ),
        (
          heading: '6. App-Store-Plattform',
          body:
              'Der Bezug der App über den jeweiligen App-Store (z. B. Apple App Store oder Google Play) unterliegt den Datenschutzbestimmungen des jeweiligen Anbieters. Auf dort verarbeitete Daten (z. B. Downloadstatistiken) haben wir keinen Einfluss.',
        ),
        (
          heading: '7. Deine Rechte',
          body:
              'Dir stehen nach DSGVO Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung und Widerspruch zu. Da wir keine Daten über dich verarbeiten oder speichern, kannst du diese Rechte unmittelbar selbst ausüben, indem du Daten in der App bearbeitest oder löschst. Bei Fragen erreichst du uns unter den oben genannten Kontaktdaten.',
        ),
        (
          heading: 'Stand',
          body: '[Monat Jahr]',
        ),
      ],
    );
  }
}

class _ImpressumPage extends StatelessWidget {
  const _ImpressumPage();

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Impressum',
      showPlaceholderHint: true,
      blocks: [
        (
          heading: 'Angaben gemäß § 5 DDG',
          body:
              '[Vor- und Nachname]\n[ggf. Firmenname]\n[Straße und Hausnummer]\n[PLZ Ort]\n[Land]',
        ),
        (
          heading: 'Kontakt',
          body:
              'E-Mail: [deine-email@beispiel.de]\n[ggf. Telefon]',
        ),
        (
          heading: 'Verantwortlich für den Inhalt',
          body: '[Vor- und Nachname, Anschrift wie oben]',
        ),
        (
          heading: 'Haftungsausschluss',
          body:
              'Die App wird mit größter Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der bereitgestellten Funktionen wird keine Gewähr übernommen.',
        ),
      ],
    );
  }
}

class _ContactPage extends StatelessWidget {
  const _ContactPage();

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Kontakt & Support',
      showPlaceholderHint: true,
      blocks: [
        (
          heading: 'Du hast Fragen oder Feedback?',
          body:
              'Schreib uns gerne – wir freuen uns über Rückmeldungen, Fehlerberichte und Ideen.',
        ),
        (
          heading: 'E-Mail',
          body: '[support@beispiel.de]',
        ),
        (
          heading: 'Website',
          body: '[https://www.beispiel.de]',
        ),
      ],
    );
  }
}

class _TermsPage extends StatelessWidget {
  const _TermsPage();

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Nutzungsbedingungen',
      blocks: [
        (
          heading: '1. Geltungsbereich',
          body:
              'Diese Bedingungen regeln die Nutzung der App „Sitzplan". Mit der Nutzung erklärst du dich mit ihnen einverstanden.',
        ),
        (
          heading: '2. Nutzung',
          body:
              'Die App dient der Erstellung und Verwaltung von Sitzplänen. Du nutzt sie eigenverantwortlich. Für die rechtmäßige Verarbeitung eingegebener personenbezogener Daten (insbesondere Schülernamen) bist du selbst verantwortlich.',
        ),
        (
          heading: '3. Gewährleistung & Haftung',
          body:
              'Die App wird „wie besehen" bereitgestellt. Es wird keine Gewähr für eine ununterbrochene oder fehlerfreie Verfügbarkeit übernommen. Eine Haftung für Schäden, die aus der Nutzung entstehen, ist im gesetzlich zulässigen Rahmen ausgeschlossen, soweit kein vorsätzliches oder grob fahrlässiges Verhalten vorliegt.',
        ),
        (
          heading: '4. Datensicherung',
          body:
              'Da alle Daten ausschließlich lokal gespeichert werden, bist du selbst für die Sicherung deiner Daten verantwortlich. Bei Verlust oder Deinstallation des Geräts können Daten unwiederbringlich verloren gehen.',
        ),
        (
          heading: '5. Änderungen',
          body:
              'Diese Bedingungen können bei künftigen App-Versionen angepasst werden.',
        ),
      ],
    );
  }
}
