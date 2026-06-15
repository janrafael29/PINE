/// User-facing labels for extension staff (JWT/API `da` identifiers unchanged).
library;

const String staffRoleSingular = 'Agriculturist';
const String staffRoleWithOmag = 'Agriculturist / OMAG';
const String staffRoleWithOmagLgu = 'Agriculturist / OMAG / LGU';
const String staffAccessCardTitle = 'Agriculturist / OMAG staff access';
const String staffAccessRequestsTitle = 'Agriculturist access requests';
const String staffToolsLabel = 'agriculturist tools';
const String expertAdviceTitle = 'Expert advice from agriculturist / OMAG';
const String staffReplyTitle = 'Agriculturist / OMAG reply';

const String staffAccessEmptyAdminHint =
    'Agriculturists and OMAG staff must register with the staff account '
    'type first. Their access request is submitted during sign-up and '
    'appears here for your review.';

const String staffAccessEmptyAdminFollowUp =
    'After approval, they sign out and sign in again.';

const String staffAccessEmptyEmbedded =
    'No pending requests. Staff must register as $staffRoleWithOmagLgu '
    'during sign-up; requests are submitted automatically.';
