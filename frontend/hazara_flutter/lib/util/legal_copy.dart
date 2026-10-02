/// In-app Terms of Use and Privacy Policy copy.
library;

import 'legal_consent.dart';

String termsOfUseBody() => '''
Last updated: $kLegalAgreementVersion
Agreement version: $kLegalAgreementVersion

1. Service
HAZARA is a free guest multiplayer card game (Pagat Hazari) for play with friends. You use a name and a temporary session. No account is required.

2. Eligibility
By using HAZARA you confirm that you are at least 16 years old, or the age of digital consent in your country if that age is higher.

3. Acceptable use
You agree not to harass other players, share illegal or harmful content, impersonate others, scrape or attack the service, or attempt to cheat or disrupt games.

4. Microphone
If “Allow microphone” is checked, your browser may ask for microphone access when you create or join a table. You can uncheck it or deny the browser prompt. HAZARA does not keep a recording of that audio.

5. No warranty
The service is provided “as is” for social play. To the fullest extent permitted by law, $kLegalOperatorName is not liable for indirect or consequential losses arising from use of the game, including lost progress or temporary outages.

6. Changes
We may update these Terms. When the agreement version changes, the checkbox starts checked again for the new text. Uncheck it if you do not agree.

7. Contact
Questions about these Terms: $kLegalOperatorEmail
''';

String privacyPolicyBody() => '''
Last updated: $kLegalAgreementVersion
Agreement version: $kLegalAgreementVersion

1. Who we are
$kLegalOperatorName operates this HAZARA web app. Contact: $kLegalOperatorEmail

2. Data we process
• Name and guest session token needed to play and reconnect
• Room and match state, including the cards in a live deal
• Technical logs for reliability and security
• Microphone access only if you leave “Allow microphone” checked and grant the browser prompt. That audio is not stored.

3. Why we process it
To run a friends table, restore a match after a refresh, and keep the service reliable.

4. Sharing
Other people at your table can see your name and the cards the rules reveal. We do not sell your personal data. Private cards stay on the server until the rules show them.

5. Retention
Live tables are removed after they finish and go idle. Clearing this site’s data in your browser removes the saved name and these checkbox choices.

6. Your choices
You may uncheck the Terms checkbox, uncheck “Allow microphone”, deny microphone permission in the browser, leave a table, and clear this site’s data.

7. Children
HAZARA is not directed at children under 16.

8. Contact
Privacy questions: $kLegalOperatorEmail
''';
