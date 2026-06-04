import '../models/snippet.dart';

/// A named bundle of ready-made snippets the user can add in one tap.
class TemplatePack {
  const TemplatePack({
    required this.name,
    required this.description,
    required this.snippets,
  });

  final String name;
  final String description;
  final List<Snippet> snippets;
}

Snippet _t(String shortcut, String expansion, String label, String group) =>
    Snippet(
      id: Snippet.newId(),
      shortcut: shortcut,
      expansion: expansion,
      label: label,
      group: group,
    );

/// Curated starter packs. Everything is editable after adding.
List<TemplatePack> templatePacks() => [
      TemplatePack(
        name: 'Email & replies',
        description: 'Greetings, sign-offs and common replies',
        snippets: [
          _t(';hi', 'Hi {input:Name},\n\n', 'Greeting', 'Email'),
          _t(';br', 'Best regards,\nAvishek', 'Sign-off', 'Email'),
          _t(';thx', 'Thank you so much — I really appreciate it!', 'Thanks',
              'Email'),
          _t(';gotit', 'Got it, thanks! I\'ll take a look and get back to you.',
              'Acknowledge', 'Email'),
          _t(';meet',
              'Are you free to meet on {input:Day} at {input:Time}? Happy to send an invite.',
              'Propose meeting', 'Email'),
        ],
      ),
      TemplatePack(
        name: 'Customer support',
        description: 'Polite, reusable support responses',
        snippets: [
          _t(';ack',
              'Thanks for reaching out, {input:Name}. I\'m sorry for the trouble — let me help.',
              'Acknowledge issue', 'Support'),
          _t(';ticket', 'Your reference number is #{counter}.', 'Ticket number',
              'Support'),
          _t(';follow',
              'Just following up on this — let me know if there\'s anything else I can do!',
              'Follow up', 'Support'),
          _t(';resolved',
              'Glad that\'s sorted! I\'ll close this out, but feel free to reply if it comes back.',
              'Resolved', 'Support'),
        ],
      ),
      TemplatePack(
        name: 'Coding',
        description: 'Snippets for everyday dev work',
        snippets: [
          _t(';todo', '// TODO({input:who}): ', 'TODO comment', 'Coding'),
          _t(';log', 'console.log({cursor});', 'Console log', 'Coding'),
          _t(';fn', 'function {input:name}() {\n  {cursor}\n}', 'Function',
              'Coding'),
          _t(';ymd', '{date}', 'ISO date', 'Coding'),
        ],
      ),
      TemplatePack(
        name: 'Dates & time',
        description: 'Quick date/time inserts',
        snippets: [
          _t(';today', '{date}', "Today's date", 'Utility'),
          _t(';now', '{datetime}', 'Date & time', 'Utility'),
          _t(';tom', '{date+1d}', 'Tomorrow', 'Utility'),
          _t(';time', '{time}', 'Current time', 'Utility'),
        ],
      ),
      TemplatePack(
        name: 'Symbols & emoji',
        description: 'Characters that are awkward to type',
        snippets: [
          _t(';shrug', r'¯\_(ツ)_/¯', 'Shrug', 'Fun'),
          _t(';check', '✓', 'Check mark', 'Fun'),
          _t(';arrow', '→', 'Arrow', 'Fun'),
          _t(';deg', '°', 'Degree', 'Fun'),
          _t(';tm', '™', 'Trademark', 'Fun'),
        ],
      ),
    ];
