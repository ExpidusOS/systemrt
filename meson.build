project('systemrt', 'vala', 'c', license: 'GPL-3.0-only', version: '0.1.0-prealpha')

pkg = import('pkgconfig')
dbus = dependency('dbus-1')
gdk = dependency('gdk-3.0')
glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
gio = dependency('gio-2.0')

conf_data = configuration_data()
conf_data.set('BINDIR', join_paths(get_option('prefix'), get_option('bindir')))
conf_data.set('SYSCONFDIR', get_option('sysconfdir'))
conf_data.set('LOCALSTATEDIR', get_option('localstatedir'))
conf_data.set('VERSION', meson.project_version())

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

executable('systemrtd', 'src/daemon/daemon.vala', 'src/daemon/session.vala',
  'src/daemon/utils.vala',
  install: true,
  dependencies: [dependency('libdaemon'), dependency('devident-1.0'), glib, gobject, gio, gdk, libsystemrt_dep])

install_data('data/com.expidus.SystemRT.conf', install_dir: join_paths(dbus.get_pkgconfig_variable('sysconfdir'), 'dbus-1', 'system.d'))
configure_file(input: 'data/com.expidus.SystemRT.service.in', output: 'com.expidus.SystemRT.service',
	configuration: conf_data,
	install: true,
	install_dir: dbus.get_pkgconfig_variable('system_bus_services_dir'))