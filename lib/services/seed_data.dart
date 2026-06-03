import '../models/snippet.dart';

/// A friendly starter pack so the app is useful the moment it opens.
/// Everything is unlocked — there is no premium tier and no ads.
List<Snippet> seedSnippets() => [
      Snippet(
        id: Snippet.newId(),
        shortcut: ';email',
        expansion: 'avishekadhikari99@gmail.com',
        label: 'My email',
        group: 'Personal',
      ),
      Snippet(
        id: Snippet.newId(),
        shortcut: ';br',
        expansion: 'Best regards,\nAvishek',
        label: 'Sign-off',
        group: 'Email',
      ),
      Snippet(
        id: Snippet.newId(),
        shortcut: ';ty',
        expansion: 'Thank you so much — I really appreciate it!',
        label: 'Thanks',
        group: 'Email',
      ),
      Snippet(
        id: Snippet.newId(),
        shortcut: ';date',
        expansion: '{date}',
        label: "Today's date",
        group: 'Utility',
      ),
      Snippet(
        id: Snippet.newId(),
        shortcut: ';now',
        expansion: '{datetime}',
        label: 'Current date & time',
        group: 'Utility',
      ),
      Snippet(
        id: Snippet.newId(),
        shortcut: ';addr',
        expansion: 'Type your address here, then place the caret with {cursor}',
        label: 'Address',
        group: 'Personal',
      ),
      Snippet(
        id: Snippet.newId(),
        shortcut: ';shrug',
        expansion: r'¯\_(ツ)_/¯',
        label: 'Shrug',
        group: 'Fun',
      ),
    ];
