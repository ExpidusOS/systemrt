project('systemrt', 'vala', 'c', license: 'GPL-3.0-only', version: '0.1.0-prealpha')

pkgconfig = find_program('pkg-config')

pkg = import('pkgconfig')
dbus = dependency('dbus-1')
gdk = dependency('gdk-3.0')
glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
gio = [dependency('gio-2.0'), dependency('gio-unix-2.0')]

lua_possible_names = [
  'lua5.3',
  'lua5.2',
  'lua5.1'
]
lua_found = false
lua_name = ''

foreach name : lua_possible_names
	if not lua_found
		lua_dep = meson.get_compiler('c').find_library(name, required: false)
		lua_name = name
		lua_found = lua_dep.found()
	endif
endforeach

if not lua_found
	error('Failed to find a compatible Lua version')
endif

lua_cflags_run = run_command(pkgconfig, ['--cflags', lua_name])
lua_cflags = lua_cflags_run.stdout().strip()

lua = [meson.get_compiler('vala').find_library('lua'), lua_dep]

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

libsystemrt = shared_library('systemrt', 'src/lib/daemon.vala', build_conf,
	vala_header: 'systemrt.h',
	vala_vapi: 'SystemRT-1.0.vapi',
	install_dir: [true, true, true],
	install: true,
	dependencies: [glib, gobject, gio])
pkg.generate(libsystemrt, description: 'General API and runtime for ExpidusOS applications.',
	name: 'systemrt')
libsystemrt_dep = declare_dependency(link_with: libsystemrt)

libsystemrt_daemon = static_library('systemrt-daemon', 'src/daemon/application.vala', 'src/daemon/client.vala', 'src/daemon/daemon.vala',
	'src/daemon/process.vala', 'src/daemon/permission.vala', 'src/daemon/session.vala', 'src/daemon/user.vala', 'src/daemon/utils.vala',
	c_args: lua_cflags,
	vala_header: 'systemrt-daemon.h',
	dependencies: [dependency('libdaemon'), dependency('devident-1.0'), dependency('libapparmor'), meson.get_compiler('vala').find_library('posix'),
		dependency('libseccomp'), dependency('sqlite3'), lua, glib, gobject, gio, gdk, libsystemrt_dep])
libsystemrt_daemon_dep = declare_dependency(link_with: libsystemrt_daemon)

executable('systemrtd', 'src/daemon/process.c',
	c_args: lua_cflags,
	install: true,
	dependencies: [meson.get_compiler('c').find_library('cap'), glib, gobject, lua, gdk, libsystemrt_daemon_dep])

install_data('data/com.expidus.SystemRT.conf', install_dir: join_paths(dbus.get_pkgconfig_variable('sysconfdir'), 'dbus-1', 'system.d'))
configure_file(input: 'data/com.expidus.SystemRT.service.in', output: 'com.expidus.SystemRT.service',
	configuration: conf_data,
	install: true,
	install_dir: dbus.get_pkgconfig_variable('system_bus_services_dir'))
