import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
  runApp(const StoneChatApp());
}

bool get connected => AppConfig.isConfigured;
SupabaseClient get db => Supabase.instance.client;
const ink = Color(0xFF111827);
const violet = Color(0xFF7257E8);
const canvas = Color(0xFFF6F7FB);

class StoneChatApp extends StatelessWidget {
  const StoneChatApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'StoneChat',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.light),
      appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: ink, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    home: !connected ? const SetupScreen() : const AuthGate(),
  );
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(padding: const EdgeInsets.all(28), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 64), const SizedBox(height: 22),
          const Text('Welcome to StoneChat', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 10),
          const Text('Your chats, snaps and updates — all in one place.', style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('One setup step before live chat works', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              SizedBox(height: 8),
              Text('Create a free Supabase project, run supabase/schema.sql in its SQL Editor, then add your project URL and anon/publishable key to lib/config.dart. The README walks you through it.'),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('This starter includes accounts, live conversations, image snaps, an updates feed, profiles, blocking/reporting foundations and a polished responsive layout.', style: TextStyle(color: Colors.black54, height: 1.45)),
        ],
      )),
    )),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: db.auth.onAuthStateChange,
    builder: (context, snapshot) => db.auth.currentSession == null ? const AuthScreen() : const HomeShell(),
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [violet, Color(0xFF9D7BFF)]), borderRadius: BorderRadius.circular(size * .32)),
    child: Icon(Icons.forum_rounded, color: Colors.white, size: size * .53),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(), password = TextEditingController(), username = TextEditingController();
  bool create = false, busy = false, hide = true;
  String? error;
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (create) {
        final res = await db.auth.signUp(email: email.text.trim(), password: password.text, data: {'username': username.text.trim()});
        if (res.user != null) {
          await db.from('profiles').upsert({'id': res.user!.id, 'username': username.text.trim(), 'display_name': username.text.trim()});
        }
      } else {
        await db.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } catch (e) { setState(() => error = e.toString()); }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Center(child: BrandMark(size: 70)), const SizedBox(height: 20),
        const Text('StoneChat', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 6), const Text('Good conversations start here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 28),
        if (create) ...[
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email))),
          const SizedBox(height: 12),
        ],
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide)))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 18),
        FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: violet), child: Text(busy ? 'Please wait…' : create ? 'Create account' : 'Sign in')),
        TextButton(onPressed: () => setState(() { create = !create; error = null; }), child: Text(create ? 'Already have an account? Sign in' : 'New to StoneChat? Create an account')),
        const SizedBox(height: 10),
        const Text('Be kind. Keep personal information private. You can block and report users.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 12)),
      ],
    )))));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final pages = const [ChatsPage(), SnapsPage(), UpdatesPage(), DiscoverPage(), ProfilePage()];
  final labels = const ['Chats', 'Snaps', 'Updates', 'Discover', 'Profile'];
  final icons = const [Icons.chat_bubble_outline, Icons.camera_alt_outlined, Icons.dynamic_feed_outlined, Icons.explore_outlined, Icons.person_outline];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: Padding(padding: const EdgeInsets.only(left: 16), child: Center(child: BrandMark(size: 36))), title: const Text('StoneChat', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), actions: [
      IconButton(tooltip: 'Settings & safety', icon: const Icon(Icons.shield_outlined), onPressed: () => showSafety(context)),
    ]),
    body: Row(children: [
      if (MediaQuery.sizeOf(context).width > 720) NavigationRail(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), labelType: NavigationRailLabelType.all, destinations: List.generate(labels.length, (i) => NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i])))),
      Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: pages[tab]))),
    ]),
    bottomNavigationBar: MediaQuery.sizeOf(context).width <= 720 ? NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: List.generate(labels.length, (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]))) : null,
  );
}

Future<Map<String, dynamic>?> myProfile() async {
  final user = db.auth.currentUser;
  if (user == null) return null;
  final rows = await db.from('profiles').select().eq('id', user.id).limit(1);
  if ((rows as List).isEmpty) return {'id': user.id, 'username': user.email?.split('@').first ?? 'member', 'display_name': 'StoneChat member'};
  return Map<String, dynamic>.from(rows.first);
}

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});
  @override
  State<ChatsPage> createState() => _ChatsPageState();
}
class _ChatsPageState extends State<ChatsPage> {
  final search = TextEditingController();
  Future<List<Map<String, dynamic>>> loadChats() async {
    final uid = db.auth.currentUser!.id;
    final memberships = await db.from('conversation_members').select('conversation_id').eq('user_id', uid);
    final ids = (memberships as List).map((e) => e['conversation_id'].toString()).toList();
    if (ids.isEmpty) return [];
    final rows = await db.from('conversations').select('id,title,is_group,updated_at').inFilter('id', ids).order('updated_at', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
  Future<void> startChat() async {
    final users = await db.from('profiles').select('id,username,display_name').neq('id', db.auth.currentUser!.id).order('username').limit(100);
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Start a conversation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...((users as List).map((u) => ListTile(leading: CircleAvatar(child: Text((u['username'] ?? '?').toString().substring(0, 1).toUpperCase())), title: Text((u['display_name'] ?? u['username'] ?? 'Member').toString()), subtitle: Text('@${u['username'] ?? 'member'}'), onTap: () => Navigator.pop(context, Map<String, dynamic>.from(u))))),
      if (users.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No other members yet. Invite a friend to create an account first.')),
    ])));
    if (chosen == null) return;
    try {
      final uid = db.auth.currentUser!.id;
      final other = chosen['id'].toString();
      final mine = await db.from('conversation_members').select('conversation_id').eq('user_id', uid);
      final theirs = await db.from('conversation_members').select('conversation_id').eq('user_id', other);
      final theirsIds = (theirs as List).map((x) => x['conversation_id'].toString()).toSet();
      String? existing;
      for (final m in mine as List) {
        if (theirsIds.contains(m['conversation_id'].toString())) {
          final count = await db.from('conversation_members').select('user_id').eq('conversation_id', m['conversation_id']);
          if ((count as List).length == 2) { existing = m['conversation_id'].toString(); break; }
        }
      }
      String cid;
      if (existing != null) { cid = existing; }
      else {
        final conv = await db.from('conversations').insert({'title': chosen['display_name'] ?? chosen['username'], 'is_group': false, 'created_by': uid}).select('id').single();
        cid = conv['id'].toString();
        await db.from('conversation_members').insert([{'conversation_id': cid, 'user_id': uid}, {'conversation_id': cid, 'user_id': other}]);
      }
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomPage(conversationId: cid, title: (chosen['display_name'] ?? chosen['username']).toString())));
    } catch (e) { if (mounted) snack(context, 'Could not start chat: $e'); }
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Your chats', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink))), FilledButton.icon(onPressed: startChat, icon: const Icon(Icons.add_comment_outlined), label: const Text('New chat'))]),
    const SizedBox(height: 16),
    TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search conversations'), onChanged: (_) => setState(() {})),
    const SizedBox(height: 12),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: loadChats(), builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Could not load chats. Check your setup and permissions.\n${snap.error}', textAlign: TextAlign.center));
      final rows = (snap.data ?? []).where((c) => (c['title'] ?? '').toString().toLowerCase().contains(search.text.toLowerCase())).toList();
      if (rows.isEmpty) return const EmptyState(icon: Icons.forum_outlined, title: 'Your next conversation starts here', body: 'Tap “New chat” to find people on StoneChat.');
      return ListView.separated(itemCount: rows.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) {
        final c = rows[i];
        return ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4), leading: const CircleAvatar(backgroundColor: Color(0xFFE9E4FF), child: Icon(Icons.chat_bubble, color: violet)), title: Text((c['title'] ?? 'Conversation').toString(), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(c['is_group'] == true ? 'Group conversation' : 'Private conversation'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomPage(conversationId: c['id'].toString(), title: (c['title'] ?? 'Chat').toString())));
      });
    })),
  ]));
}

class ChatRoomPage extends StatefulWidget {
  final String conversationId, title;
  const ChatRoomPage({super.key, required this.conversationId, required this.title});
  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}
class _ChatRoomPageState extends State<ChatRoomPage> {
  final controller = TextEditingController();
  bool sending = false;
  Future<List<Map<String, dynamic>>> load() async {
    final rows = await db.from('messages').select('id,sender_id,body,created_at,message_type,media_url').eq('conversation_id', widget.conversationId).order('created_at');
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
  Future<void> send({String? mediaUrl, String type = 'text'}) async {
    final body = controller.text.trim();
    if (body.isEmpty && mediaUrl == null) return;
    setState(() => sending = true);
    try {
      await db.from('messages').insert({'conversation_id': widget.conversationId, 'sender_id': db.auth.currentUser!.id, 'body': body, 'message_type': type, 'media_url': mediaUrl});
      await db.from('conversations').update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', widget.conversationId);
      controller.clear();
      if (mounted) setState(() {});
    } catch (e) { if (mounted) snack(context, 'Message not sent: $e'); }
    if (mounted) setState(() => sending = false);
  }
  Future<void> sendSnap() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75) ??
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final path = '${db.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      await db.storage.from('snaps').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
      final url = db.storage.from('snaps').getPublicUrl(path);
      await send(mediaUrl: url, type: 'image');
    } catch (e) { if (mounted) snack(context, 'Snap upload failed: $e'); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(tooltip: 'Safety options', icon: const Icon(Icons.more_horiz), onPressed: () => showSafety(context))]),
    body: Column(children: [
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: db.from('messages').stream(primaryKey: ['id']).eq('conversation_id', widget.conversationId).order('created_at'), builder: (context, snap) {
        final rows = snap.data ?? [];
        if (snap.hasError) return Center(child: Text('Could not load messages: ${snap.error}'));
        if (rows.isEmpty) return const EmptyState(icon: Icons.waving_hand_outlined, title: 'Say hello!', body: 'Send a message or share a snap to start the conversation.');
        return ListView.builder(reverse: false, padding: const EdgeInsets.all(16), itemCount: rows.length, itemBuilder: (context, i) {
          final m = rows[i]; final mine = m['sender_id'] == db.auth.currentUser!.id;
          return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
            constraints: const BoxConstraints(maxWidth: 320), margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: mine ? violet : Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m['message_type'] == 'image' && m['media_url'] != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(m['media_url'], width: 240, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text('Snap unavailable'))),
              if ((m['body'] ?? '').toString().isNotEmpty) Text(m['body'].toString(), style: TextStyle(color: mine ? Colors.white : ink)),
              const SizedBox(height: 3),
              Text(m['created_at'] == null ? '' : DateFormat('HH:mm').format(DateTime.parse(m['created_at'].toString()).toLocal()), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.black45)),
            ]),
          ));
        });
      })),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
        IconButton.filledTonal(onPressed: sendSnap, tooltip: 'Send a snap', icon: const Icon(Icons.camera_alt_outlined)),
        Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Write a message…'))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: sending ? null : () => send(), icon: const Icon(Icons.send_rounded)),
      ]))),
    ]),
  );
}

class SnapsPage extends StatefulWidget {
  const SnapsPage({super.key});
  @override
  State<SnapsPage> createState() => _SnapsPageState();
}
class _SnapsPageState extends State<SnapsPage> {
  Future<void> postSnap() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75) ??
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    try {
      final path = '${db.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      await db.storage.from('snaps').uploadBinary(path, await picked.readAsBytes(), fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = db.storage.from('snaps').getPublicUrl(path);
      await db.from('snaps').insert({'user_id': db.auth.currentUser!.id, 'media_url': url, 'caption': ''});
      if (mounted) snack(context, 'Snap posted!');
      setState(() {});
    } catch (e) { if (mounted) snack(context, 'Snap could not be posted: $e'); }
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Snaps', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 6), const Text('Little moments, shared with your people.', style: TextStyle(color: Colors.black54)),
    const SizedBox(height: 18),
    Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7257E8), Color(0xFFB49CFF)]), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.auto_awesome, color: Colors.white, size: 30), const SizedBox(height: 8),
      const Text('Capture the moment', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5), const Text('Share a photo from your camera or gallery.', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 14), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: violet), onPressed: postSnap, icon: const Icon(Icons.camera_alt), label: const Text('Create a snap')),
    ])),
    const SizedBox(height: 18),
    const Expanded(child: EmptyState(icon: Icons.photo_library_outlined, title: 'Your snap space', body: 'Snaps you share appear here. Chat snaps can be sent directly in a conversation.')),
  ]));
}

class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});
  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}
class _UpdatesPageState extends State<UpdatesPage> {
  final text = TextEditingController();
  Future<void> post() async {
    if (text.text.trim().isEmpty) return;
    try {
      await db.from('updates').insert({'user_id': db.auth.currentUser!.id, 'body': text.text.trim()});
      text.clear(); if (mounted) { FocusScope.of(context).unfocus(); setState(() {}); snack(context, 'Update posted!'); }
    } catch (e) { if (mounted) snack(context, 'Could not post update: $e'); }
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Updates', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
    const Text('Share news, thoughts and little wins.', style: TextStyle(color: Colors.black54)),
    const SizedBox(height: 16),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [
      TextField(controller: text, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'What’s happening?')),
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: post, icon: const Icon(Icons.send), label: const Text('Post update'))),
    ])),
    const SizedBox(height: 14),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: db.from('updates').select('id,body,created_at,user_id,profiles(username,display_name)').order('created_at', ascending: false).limit(50).then((r) => (r as List).map((e) => Map<String, dynamic>.from(e)).toList()), builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Could not load updates: ${snap.error}'));
      final rows = snap.data ?? [];
      if (rows.isEmpty) return const EmptyState(icon: Icons.dynamic_feed_outlined, title: 'A fresh start', body: 'Be the first to post an update.');
      return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
        final u = rows[i], profile = u['profiles'] as Map? ?? {};
        return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const CircleAvatar(backgroundColor: Color(0xFFE9E4FF), child: Icon(Icons.person, color: violet)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((profile['display_name'] ?? profile['username'] ?? 'StoneChat member').toString(), style: const TextStyle(fontWeight: FontWeight.bold)), Text(u['created_at'] == null ? '' : DateFormat('d MMM • HH:mm').format(DateTime.parse(u['created_at'].toString()).toLocal()), style: const TextStyle(color: Colors.black45, fontSize: 12))]))]),
          const SizedBox(height: 12), Text((u['body'] ?? '').toString(), style: const TextStyle(fontSize: 15, height: 1.4)),
        ])));
      });
    })),
  ]));
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}
class _DiscoverPageState extends State<DiscoverPage> {
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Discover', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
    const Text('Meet the StoneChat community.', style: TextStyle(color: Colors.black54)),
    const SizedBox(height: 16),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: db.from('profiles').select('id,username,display_name,bio').neq('id', db.auth.currentUser!.id).order('username').limit(100).then((r) => (r as List).map((e) => Map<String, dynamic>.from(e)).toList()), builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Could not load members: ${snap.error}'));
      final users = snap.data ?? [];
      if (users.isEmpty) return const EmptyState(icon: Icons.people_outline, title: 'You’re early!', body: 'When other people join StoneChat, you’ll find them here.');
      return ListView.separated(itemCount: users.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (context, i) {
        final u = users[i], name = (u['display_name'] ?? u['username'] ?? 'Member').toString();
        return ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE9E4FF), child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: violet, fontWeight: FontWeight.bold))), title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('@${u['username'] ?? 'member'}${(u['bio'] ?? '').toString().isEmpty ? '' : ' • ${u['bio']}'}'), trailing: IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () async {
          try {
            final uid = db.auth.currentUser!.id;
            final conv = await db.from('conversations').insert({'title': name, 'is_group': false, 'created_by': uid}).select('id').single();
            final cid = conv['id'].toString();
            await db.from('conversation_members').insert([{'conversation_id': cid, 'user_id': uid}, {'conversation_id': u['id'], 'user_id': u['id']}]);
            if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomPage(conversationId: cid, title: name)));
          } catch (e) { if (context.mounted) snack(context, 'Could not start chat: $e'); }
        }));
      });
    })),
  ]));
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  final display = TextEditingController(), username = TextEditingController(), bio = TextEditingController();
  bool loaded = false, saving = false;
  Future<void> load() async {
    if (loaded) return;
    try {
      final p = await myProfile();
      display.text = (p?['display_name'] ?? '').toString();
      username.text = (p?['username'] ?? '').toString();
      bio.text = (p?['bio'] ?? '').toString();
    } catch (_) {}
    loaded = true;
  }
  Future<void> save() async {
    setState(() => saving = true);
    try {
      await db.from('profiles').upsert({'id': db.auth.currentUser!.id, 'display_name': display.text.trim(), 'username': username.text.trim().replaceAll('@', ''), 'bio': bio.text.trim()});
      if (mounted) snack(context, 'Profile saved.');
    } catch (e) { if (mounted) snack(context, 'Profile could not be saved: $e'); }
    if (mounted) setState(() => saving = false);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(future: load(), builder: (context, _) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Your profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 16),
    Center(child: Column(children: [const CircleAvatar(radius: 42, backgroundColor: Color(0xFFE9E4FF), child: Icon(Icons.person, color: violet, size: 42)), const SizedBox(height: 8), Text('@${username.text}', style: const TextStyle(color: Colors.black54))])),
    const SizedBox(height: 20),
    TextField(controller: display, decoration: const InputDecoration(labelText: 'Display name')),
    const SizedBox(height: 12), TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
    const SizedBox(height: 12), TextField(controller: bio, maxLength: 160, decoration: const InputDecoration(labelText: 'Bio', hintText: 'A little about you')),
    const SizedBox(height: 8), FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving…' : 'Save profile')),
    const SizedBox(height: 10), OutlinedButton.icon(onPressed: () async => db.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
    const SizedBox(height: 18), const Text('StoneChat safety', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    const SizedBox(height: 8), const Text('Never share passwords, verification codes, home addresses or financial details. If someone makes you uncomfortable, block or report them.'),
    OutlinedButton.icon(onPressed: () => showSafety(context), icon: const Icon(Icons.shield_outlined), label: const Text('Safety & community rules')),
  ]));
}

class EmptyState extends StatelessWidget {
  final IconData icon; final String title, body;
  const EmptyState({super.key, required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 68, height: 68, decoration: BoxDecoration(color: const Color(0xFFECE8FF), borderRadius: BorderRadius.circular(22)), child: Icon(icon, color: violet, size: 32)),
    const SizedBox(height: 16), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: ink)),
    const SizedBox(height: 6), Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
  ])));
}
void snack(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

void showSafety(BuildContext context) {
  showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Safety & community', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    const Text('• Be respectful and do not harass other members.\n• Never share passwords, login codes, or private financial information.\n• Only send snaps you have permission to share.\n• Block and report abusive users; contact local emergency services if you are in immediate danger.\n• StoneChat is a starter app. Before public launch, add moderation tooling, age-appropriate safeguards, privacy policy, terms, account deletion and abuse-report review.'),
    const SizedBox(height: 16), Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))),
  ]))));
}
