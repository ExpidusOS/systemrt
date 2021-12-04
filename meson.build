project('systemrt', 'vala', 'c', license: 'GPL-3.0-only', version: '0.1.0-prealpha')

pkgconfig = find_program('pkg-config')

pkg = import('pkgconfig')
dbus = dependency('dbus-1')
glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
gio = [dependency('gio-2.0'), dependency('gio-unix-2.0')]

build_tests = get_option('build_tests')

sysconfdir = get_option('sysconfdir')
prefix = get_option('prefix')

if not sysconfdir.startswith('/')
	sysconfdir = prefix + '/' + sysconfdir
endif

conf_data = configuration_data()
conf_data.set('BINDIR', join_paths(prefix, get_option('bindir')))
conf_data.set('SYSCONFDIR', sysconfdir)
conf_data.set('LOCALSTATEDIR', get_option('localstatedir'))
conf_data.set('VERSION', meson.project_version())

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir, '--girdir', vapi_dir], language: 'vala')

install_subdir('data/conf.d',
	install_dir: join_paths(sysconfdir, 'expidus', 'sys'))
install_subdir('src/perms.d',
	install_dir: join_paths(sysconfdir, 'expidus', 'sys'))
install_subdir('src/profiles.d',
	install_dir: join_paths(sysconfdir, 'expidus', 'sys'))
install_subdir('src/runtime.d',
	install_dir: join_paths(sysconfdir, 'expidus', 'sys'))

build_conf = configure_file(input: 'src/build.vala.in', output: 'build.vala',
	configuration: conf_data)

libsystemrt_common = shared_library('systemrt-common', ['src/lib/common/serializable.vala', build_conf],
	vala_header: 'systemrt-common.h',
	vala_vapi: 'SystemRTCommon-1.0.vapi',
	vala_gir: 'SystemRTCommon-1.0.gir',
	install: true,
	install_dir: [true, true, true, true],
	dependencies: [gobject])
libsystemrt_common_dep = declare_dependency(link_with: libsystemrt_common, dependencies: [gobject])

libsystemrt_policy = shared_library('systemrt-policy', ['src/lib/policy/context.vala', 'src/lib/policy/definition.vala',
		'src/lib/policy/loader.vala', 'src/lib/policy/policy.vala', 'src/lib/policy/process.vala', 'src/lib/policy/rule.vala', 'src/lib/policy/table.vala'],
	vala_header: 'systemrt-policy.h',
	vala_vapi: 'SystemRTPolicy-1.0.vapi',
	vala_gir: 'SystemRTPolicy-1.0.gir',
	install: true,
	install_dir: [true, true, true, true],
	dependencies: [gobject, libsystemrt_common_dep, gio])
libsystemrt_policy_dep = declare_dependency(link_with: libsystemrt_policy, dependencies: [gobject, libsystemrt_common_dep, gio])

libsystemrt_server = shared_library('systemrt-server', ['src/lib/server/context.vala'],
	vala_header: 'systemrt-server.h',
	vala_vapi: 'SystemRTServer-1.0.vapi',
	vala_gir: 'SystemRTServer-1.0.gir',
	install: true,
	install_dir: [true, true, true, true],
	dependencies: [gobject])
libsystemrt_server_dep = declare_dependency(link_with: libsystemrt_server, dependencies: [gobject])

install_data('data/com.expidus.SystemRT.conf', install_dir: join_paths(dbus.get_pkgconfig_variable('sysconfdir'), 'dbus-1', 'system.d'))
configure_file(input: 'data/com.expidus.SystemRT.service.in', output: 'com.expidus.SystemRT.service',
	configuration: conf_data,
	install: true,
	install_dir: dbus.get_pkgconfig_variable('system_bus_services_dir'))

if build_tests
	libsystemrt_policy_test = executable('libsystemrt-policy-test', ['tests/lib/policy/loader.vala', 'tests/lib/policy.vala'],
		dependencies: [libsystemrt_policy_dep])
	test('libsystemrt-policy', libsystemrt_policy_test)
endif