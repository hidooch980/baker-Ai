import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

/// صفحه مدیریت کاربران و نقش‌ها (RBAC).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('کاربران و نقش‌ها'),
          bottom: const TabBar(tabs: [Tab(text: 'کاربران'), Tab(text: 'نقش‌ها')]),
        ),
        body: const TabBarView(children: [_UsersTab(), _RolesTab()]),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.instance.dio;
      final results = await Future.wait([dio.get('/users'), dio.get('/roles')]);
      if (!mounted) return;
      setState(() {
        _users = (results[0].data as List).cast<Map<String, dynamic>>();
        _roles = (results[1].data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? user}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _UserFormScreen(roles: _roles, user: user)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف کاربر'),
        content: Text('کاربر «${user['fullName']}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.dio.delete('/users/${user['id']}');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  String _roleNames(Map<String, dynamic> user) {
    final roles = (user['userRoles'] as List? ?? [])
        .map((r) => (r as Map<String, dynamic>)['role'])
        .whereType<Map<String, dynamic>>()
        .map((role) => role['name'])
        .whereType<String>()
        .toList();
    return roles.isEmpty ? 'بدون نقش' : roles.join('، ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.person_add_alt)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _users.isEmpty
                    ? const Center(child: Text('کاربری ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isActive = user['isActive'] != false;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text((user['fullName'] as String? ?? '?').characters.first)),
                              title: Text(user['fullName'] as String? ?? ''),
                              subtitle: Text('${user['phone'] ?? ''}\n${_roleNames(user)}'),
                              isThreeLine: true,
                              trailing: Icon(
                                isActive ? Icons.check_circle_outline : Icons.block,
                                color: isActive ? Colors.green : Colors.red,
                              ),
                              onTap: () => _openForm(user: user),
                              onLongPress: () => _delete(user),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _UserFormScreen extends StatefulWidget {
  const _UserFormScreen({required this.roles, this.user});

  final List<Map<String, dynamic>> roles;
  final Map<String, dynamic>? user;

  @override
  State<_UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<_UserFormScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final Set<String> _selectedRoleIds = {};
  bool _isSubmitting = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user?['fullName'] as String? ?? '');
    _phoneController = TextEditingController(text: widget.user?['phone'] as String? ?? '');
    _emailController = TextEditingController(text: widget.user?['email'] as String? ?? '');
    for (final userRole in (widget.user?['userRoles'] as List? ?? [])) {
      final map = userRole as Map<String, dynamic>;
      final roleId = map['roleId'] ?? (map['role'] as Map<String, dynamic>?)?['id'];
      if (roleId is String) _selectedRoleIds.add(roleId);
    }
  }

  Future<void> _submit() async {
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (fullName.isEmpty) {
      setState(() => _error = 'نام کامل را وارد کنید.');
      return;
    }
    if (!_isEdit && phone.isEmpty) {
      setState(() => _error = 'شماره تلفن را وارد کنید.');
      return;
    }
    if (!_isEdit && password.length < 8) {
      setState(() => _error = 'رمز عبور باید حداقل ۸ کاراکتر باشد.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final dio = ApiClient.instance.dio;
      if (_isEdit) {
        await dio.patch('/users/${widget.user!['id']}', data: {
          'fullName': fullName,
          if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
          if (password.isNotEmpty) 'password': password,
          'roleIds': _selectedRoleIds.toList(),
        });
      } else {
        await dio.post('/users', data: {
          'fullName': fullName,
          'phone': phone,
          if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
          'password': password,
          if (_selectedRoleIds.isNotEmpty) 'roleIds': _selectedRoleIds.toList(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'ویرایش کاربر' : 'کاربر جدید')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TextField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'نام کامل'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_isEdit,
            decoration: InputDecoration(
              labelText: 'شماره تلفن',
              helperText: _isEdit ? 'شماره تلفن قابل تغییر نیست.' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'ایمیل (اختیاری)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _isEdit ? 'رمز عبور جدید (اختیاری)' : 'رمز عبور',
              helperText: 'حداقل ۸ کاراکتر',
            ),
          ),
          const SizedBox(height: 16),
          Text('نقش‌ها', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.roles.map((role) {
              final id = role['id'] as String;
              final selected = _selectedRoleIds.contains(id);
              return FilterChip(
                label: Text(role['name'] as String? ?? ''),
                selected: selected,
                onSelected: (value) => setState(() {
                  if (value) {
                    _selectedRoleIds.add(id);
                  } else {
                    _selectedRoleIds.remove(id);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEdit ? 'ذخیره تغییرات' : 'ایجاد کاربر'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolesTab extends StatefulWidget {
  const _RolesTab();

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.dio.get('/roles');
      if (!mounted) return;
      setState(() {
        _roles = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _createRole() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نقش جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام نقش')),
            const SizedBox(height: 8),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ایجاد')),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    try {
      await ApiClient.instance.dio.post('/roles', data: {
        'name': name,
        if (descriptionController.text.trim().isNotEmpty) 'description': descriptionController.text.trim(),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _openPermissions(Map<String, dynamic> role) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _RolePermissionsScreen(role: role)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _createRole, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _roles.isEmpty
                    ? const Center(child: Text('نقشی ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _roles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final role = _roles[index];
                          final permissionCount = (role['rolePermissions'] as List? ?? []).length;
                          final description = role['description'] as String? ?? '';
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.verified_user_outlined),
                              title: Text(role['name'] as String? ?? ''),
                              subtitle: Text(description.isEmpty ? '$permissionCount دسترسی' : '$description • $permissionCount دسترسی'),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => _openPermissions(role),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _RolePermissionsScreen extends StatefulWidget {
  const _RolePermissionsScreen({required this.role});

  final Map<String, dynamic> role;

  @override
  State<_RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends State<_RolePermissionsScreen> {
  List<Map<String, dynamic>> _permissions = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final rolePermission in (widget.role['rolePermissions'] as List? ?? [])) {
      final map = rolePermission as Map<String, dynamic>;
      final id = map['permissionId'] ?? (map['permission'] as Map<String, dynamic>?)?['id'];
      if (id is String) _selectedIds.add(id);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.instance.dio.get('/permissions');
      if (!mounted) return;
      setState(() {
        _permissions = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.put(
        '/roles/${widget.role['id']}/permissions',
        data: {'permissionIds': _selectedIds.toList()},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _isSaving = false;
      });
    }
  }

  String _permissionLabel(Map<String, dynamic> permission) {
    final description = permission['description'] as String? ?? '';
    if (description.isNotEmpty) return description;
    return (permission['key'] ?? permission['name'] ?? '') as String;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final permission in _permissions) {
      final module = permission['module'] as String? ?? 'سایر';
      grouped.putIfAbsent(module, () => []).add(permission);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('دسترسی‌های «${widget.role['name']}»'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving ? const CircularProgressIndicator() : const Text('ذخیره'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: grouped.entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      ...entry.value.map((permission) {
                        final id = permission['id'] as String;
                        return CheckboxListTile(
                          value: _selectedIds.contains(id),
                          title: Text(_permissionLabel(permission)),
                          subtitle: Text((permission['key'] ?? '') as String),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          }),
                        );
                      }),
                    ];
                  }).toList(),
                ),
    );
  }
}
